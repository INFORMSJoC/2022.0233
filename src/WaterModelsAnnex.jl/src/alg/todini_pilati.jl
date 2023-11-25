mutable struct Link
    type::Symbol
    index::Int
    node_fr::Int
    node_to::Int
    loss_function::Function
    loss_derivative::Function
end


function get_links(wm::WM.AbstractWaterModel, control_setting::ControlSetting)
    # Get nondimensionalization data.
    wm_data = WM.get_wm_data(wm.data)
    base_length = get(wm_data, "base_length", 1.0)
    base_mass = get(wm_data, "base_mass", 1.0)
    base_time = get(wm_data, "base_time", 1.0)
    
    # Get data required for determining the head loss function.
    pipe_type = wm.ref[:it][WM.wm_it_sym][:head_loss]
    viscosity = wm.ref[:it][WM.wm_it_sym][:viscosity]
    head_loss_type = wm.ref[:it][WM.wm_it_sym][:head_loss]
    exponent = WM._get_exponent_from_head_loss_form(head_loss_type)

    # Initialize a vector to store active links in the network.
    links = Vector{Link}([])

    for (i, pipe) in WM.ref(wm, control_setting.network_id, :pipe)
        # Push pipe to the vector of active links.
        L_x_r = pipe["length"] * WM._calc_pipe_resistance(
            pipe, pipe_type, viscosity, base_length, base_mass, base_time)
        func = x -> L_x_r * sign(x) * abs(x)^exponent
        derivative = x -> exponent * L_x_r * abs(x)^(exponent - 1.0)
        push!(links, Link(:pipe, pipe["index"], pipe["node_fr"], pipe["node_to"], func, derivative))
    end

    for (i, vid) in enumerate(control_setting.variable_indices)
        if control_setting.vals[i] >= 0.5 && vid.component_type == :pump
            # Push active controllable component to the vector of active links.
            pump = WM.ref(wm, control_setting.network_id, :pump, vid.component_index)
            func = x -> -pump["head_curve_function"](abs(x))
            derivative = x -> -pump["head_curve_derivative"](abs(x))
            push!(links, Link(:pump, vid.component_index,
                pump["node_fr"], pump["node_to"], func, derivative))
        elseif control_setting.vals[i] >= 0.5 && vid.component_type == :valve
            # Get the pipe that shares the valve's dummy index.
            valve = WM.ref(wm, control_setting.network_id, :valve, vid.component_index)
            pipe_link_id = findfirst(x -> x.index == valve["index"], links)
            links[pipe_link_id].node_fr = valve["node_fr"]
        elseif control_setting.vals[i] < 0.5 && vid.component_type == :valve
            valve = WM.ref(wm, control_setting.network_id, :valve, vid.component_index)
            pipe_link_id = findfirst(x -> x.index == valve["index"], links)
            links[pipe_link_id].node_fr = valve["node_to"]
        end
    end

    # Return the vector of active links.
    return links
end


function get_incidence(wm::WM.AbstractWaterModel, links::Vector{Link}, nw_id::Int)
    # Initialize the nodal incidence dictionary.
    incidence = Dict{Int, Vector{Pair{Int,Int}}}(
        i => Vector([]) for i in collect(WM.ids(wm, nw_id, :node)))

    for link in links
        # Push each link's nodal pair to the corresponding incidence entries.
        push!(incidence[link.node_fr], Pair(link.node_fr, link.node_to))
        push!(incidence[link.node_to], Pair(link.node_fr, link.node_to))
    end

    # Filter out nodes from incidence that are unconnected.
    incidence = filter(x -> length(x.second) > 0, incidence)

    # Get nodal indices for non-junction (i.e., nonzero demand) nodes.
    reservoir_nodes = [x["node"] for (i, x) in WM.ref(wm, nw_id, :reservoir)]
    tank_nodes = [x["node"] for (i, x) in WM.ref(wm, nw_id, :tank)]
    demand_nodes = [x["node"] for (i, x) in WM.ref(wm, nw_id, :demand)]

    # Get the set of all junction (i.e., zero demand) nodes.
    nonzero_nodes = vcat(reservoir_nodes, tank_nodes, demand_nodes)
    zero_demand_nodes = setdiff(collect(keys(incidence)), nonzero_nodes)

    for i in zero_demand_nodes
        if length(incidence[i]) == 1
            # Remove zero-demand leaf node from the incidence dictionary.
            delete!(incidence, i)

            # Remove the link connected to the zero-demand leaf node.
            links = filter(x -> !(x.node_fr == i || x.node_to == i), links)
        end
    end

    # Return the new links vector and incidence dictionary.
    return links, incidence
end


function build_matrices(
    wm::WM.AbstractWaterModel, links::Vector{Link}, incidence::Dict, nw_id::Int)
    # Gather all reservoir nodes (which have fixed heads) in the network.
    reservoir_nodes = [x["node"] for x in values(WM.ref(wm, nw_id, :reservoir))]
    reservoir_nodes = filter(x -> x in keys(incidence), reservoir_nodes)
    reservoir_heads = [WM.ref(wm, nw_id, :node, i, "head_nominal") for i in reservoir_nodes]

    # Gather all tank nodes (which have fixed heads) in the network.
    tank_nodes = [x["node"] for x in values(WM.ref(wm, nw_id, :tank))]
    tank_nodes = filter(x -> x in keys(incidence), tank_nodes)
    tank_heads = [WM.ref(wm, nw_id, :node, i, "head_nominal") for i in tank_nodes]

    # Concatenate reservoir and tank nodal information.
    fixed_nodes = vcat(reservoir_nodes, tank_nodes)
    incidence_nodes = collect(keys(incidence))
    fixed_nodes = filter(x -> x in incidence_nodes, fixed_nodes)

    fixed_heads = vcat(reservoir_heads, tank_heads)
    fixed_map = Dict{Int,Tuple}(i => (false, k) for 
        (k, i) in enumerate(fixed_nodes))

    # Gather nodes with zero and nonzero demands without fixed heads.
    demand_ids = collect(WM.ids(wm, nw_id, :demand))
    demand_nodes = [WM.ref(wm, nw_id, :demand, i, "node") for i in demand_ids]
    demand_flows = [WM.ref(wm, nw_id, :demand, i, "flow_nominal") for i in demand_ids]

    remaining_nodes = setdiff(setdiff(WM.ids(wm, nw_id, :node), fixed_nodes), demand_nodes)
    remaining_nodes = filter(x -> x in keys(incidence), remaining_nodes)

    # Define all junction nodes and flows.
    junction_nodes = vcat(demand_nodes, remaining_nodes...)
    junction_nodes = filter(x -> x in incidence_nodes, junction_nodes)
    junction_flows = vcat(demand_flows, zeros(length(remaining_nodes)))
    junction_map = Dict{Int,Tuple}(i => (true, k) for
        (k, i) in enumerate(junction_nodes))

    # Create a map of fixed and junction nodes for later use.
    node_map = merge(fixed_map, junction_map)

    # Store junction flows and fixed heads.
    q, H0 = junction_flows, fixed_heads

    # Create the incidence matrices used by the Todini-Pilati algorithm.
    A21 = zeros(Float64, (length(junction_flows), length(links)))
    A12 = zeros(Float64, (length(links), length(junction_flows)))
    # A01 = zeros(Float64, (length(fixed_heads), length(links)))
    A10 = zeros(Float64, (length(links), length(fixed_heads)))

    for (j, link) in enumerate(links)
        # Set up incidence matrices for node `i`.
        if node_map[link.node_fr][1]
            A21[node_map[link.node_fr][2], j] = -1.0
            A12[j, node_map[link.node_fr][2]] = -1.0
        else
            A10[j, node_map[link.node_fr][2]] = -1.0
        end

        # Set up incidence matrices for node `j`.
        if node_map[link.node_to][1]
            A21[node_map[link.node_to][2], j] = 1.0
            A12[j, node_map[link.node_to][2]] = 1.0
        else
            A10[j, node_map[link.node_to][2]] = 1.0
        end
    end

    # Return the data required for the Todini-Pilati algorithm.
    return node_map, q, H0, A21, A12, A10
end


function todini_pilati(links, q, H0, A21, A12, A10)
    identity = LinearAlgebra.Diagonal(ones(length(links), length(links)))
    Q, H = 1.0 * ones(length(links), 1), zeros(1, length(q))
    A11 = zeros(length(links), length(links))
    D, gap = zeros(length(links), length(links)), Inf

    while gap > 1.0e-8
        Q_old = deepcopy(Q)

        for (i, link) in enumerate(links)
            A11[i, i] = link.loss_function(Q[i]) / Q[i]
            D[i, i] = inv(link.loss_derivative(Q[i]))
        end

        H = -inv(A21 * D * A12) * (A21 * D * (A11 * Q + A10 * H0) + q - A21 * Q)
        Q = (identity - D * A11) * Q - D * (A12 * H + A10 * H0)

        gap = sum(abs(Q[i, 1] - Q_old[i, 1]) for (i, link) in enumerate(links)) /
            sum(abs(Q[i, 1]) for (i, link) in enumerate(links))
    end

    return Q, H
end


function _simulate_todini_pilati(wm::WM.AbstractWaterModel, control_setting::ControlSetting)
    # Collect the list of all active arcs.
    links = get_links(wm, control_setting)
    
    # Collect incidence information for active arcs.
    incidence, can_stop = Dict{Int, Any}(), false

    while !can_stop
        incidence_length, links_length = length(incidence), length(links)
        links, incidence = get_incidence(wm, links, control_setting.network_id)

        if length(incidence) == incidence_length && length(links) == links_length
            can_stop = true
        end
    end

    # Build the matrices used by the Todini-Pilati algorithm.
    node_map, q, H0, A21, A12, A10 = build_matrices(
        wm, links, incidence, control_setting.network_id)

    Q, H = todini_pilati(links, q, H0, A21, A12, A10)

    flow = Dict{String, Dict}()

    flow["pipe"] = Dict{Int,Float64}(i => 0.0 for i in
        WM.ids(wm, control_setting.network_id, :pipe))

    flow["pump"] = Dict{Int,Float64}(i => 0.0 for i in
        WM.ids(wm, control_setting.network_id, :pump))

    for (j, link) in enumerate(links)
        flow[string(link.type)][link.index] = Q[j]
    end

    flow["valve"] = Dict{Int,Float64}(i => 0.0 for i in
        WM.ids(wm, control_setting.network_id, :valve))

    head = Dict{Int, Float64}(i => 0.0 for i in keys(node_map))

    for (node_index, (is_demand, i)) in node_map
        head[node_index] = is_demand ? H[i] : H0[i]
    end

    for (i, vid) in enumerate(control_setting.variable_indices)
        if control_setting.vals[i] >= 0.5 && vid.component_type == :valve
            # Get the pipe that shares the valve's dummy index.
            valve = WM.ref(wm, control_setting.network_id, :valve, vid.component_index)
            pipe_link_id = findfirst(x -> x.index == valve["index"], links)
            flow["valve"][valve["index"]] = flow["pipe"][links[pipe_link_id].index]
        end
    end


    return flow, head
end


function get_tank_flow(wm::WM.AbstractWaterModel, i::Int, nw::Int, flow::Dict)
    flow_out = 0.0

    for name in WM._LINK_COMPONENTS
        links_fr = wm.ref[:it][WM.wm_it_sym][:nw][nw][Symbol(name * "_fr")][i]
        flow_out += length(links_fr) > 0 ? sum(flow[name][a] for a in links_fr) : 0.0
        links_to = wm.ref[:it][WM.wm_it_sym][:nw][nw][Symbol(name * "_to")][i]
        flow_out -= length(links_to) > 0 ? sum(flow[name][a] for a in links_to) : 0.0
    end

    return flow_out
end


function update_tank_heads!(wm::WM.AbstractWaterModel, nw_id::Int, flow::Dict)
    for (k, tank) in WM.ref(wm, nw_id - 1, :tank)
        surface_area = 0.25 * pi * tank["diameter"]^2
        tank_outflow = get_tank_flow(wm, tank["node"], nw_id - 1, flow)
        head_decrease = tank_outflow * WM.ref(wm, nw_id - 1, :time_step) / surface_area
        node_last = WM.ref(wm, nw_id - 1, :node, tank["node"])
        node_current = WM.ref(wm, nw_id, :node, tank["node"])
        node_current["head_nominal"] = node_last["head_nominal"] - head_decrease
    end
end


function update_tank_volumes!(wm::WM.AbstractWaterModel, result::Dict, nw_id::Int, flow::Dict)
    for (k, tank) in WM.ref(wm, nw_id - 1, :tank)
        tank_outflow = get_tank_flow(wm, tank["node"], nw_id - 1, flow)
        result["solution"]["nw"][string(nw_id)]["tank"][string(k)]["V"] =
        result["solution"]["nw"][string(nw_id-1)]["tank"][string(k)]["V"] -
            tank_outflow * WM.ref(wm, nw_id - 1, :time_step)
    end
end


function calc_simulation_cost(wm::WM.AbstractWaterModel, nw_id::Int, flow::Dict)::Float64
    cost = 0.0

    for (i, pump) in WM.ref(wm, nw_id, :pump)
        if haskey(flow["pump"], i)
            z = flow["pump"][i] > 0.0 ? 1.0 : 0.0
            q = flow["pump"][i]
            power = pump["power_fixed"] * z + pump["power_per_unit_flow"] * q * z
            cost += power * pump["energy_price"] * WM.ref(wm, nw_id, :time_step)
        end
    end

    return cost
end


function calc_simulation_tank_flows(wm::WM.AbstractWaterModel, nw_id::Int, flow::Dict)
    tank_flows = Dict{Int, Float64}(i => 0.0 for i in WM.ids(wm, nw_id, :tank))

    for (i, tank) in WM.ref(wm, nw_id, :tank)
        tank_flows[i] = get_tank_flow(wm, tank["node"], nw_id, flow)
    end

    return tank_flows
end


function flows_and_heads_feasible(wm::WM.AbstractWaterModel, nw_id::Int, flow::Dict, head::Dict)
    for (i, value) in head
        if value < WM.ref(wm, nw_id, :node, i, "head_min") - 1.0e-6
            return false
        elseif value > WM.ref(wm, nw_id, :node, i, "head_max") + 1.0e-6
            return false
        end
    end

    for (comp_type, comps) in flow
        for (i, value) in comps
            if value < WM.ref(wm, nw_id, Symbol(comp_type), i, "flow_min") - 1.0e-6
                return false
            elseif value > WM.ref(wm, nw_id, Symbol(comp_type), i, "flow_max") + 1.0e-6
                return false
            end
        end
    end

    return true
end


function get_simulation_result(wm::WM.AbstractWaterModel, nw_id::Int, flow::Dict, head::Dict)
    q_tank = calc_simulation_tank_flows(wm, nw_id, flow)
    cost = calc_simulation_cost(wm, nw_id, flow)
    feasible = flows_and_heads_feasible(wm, nw_id, flow, head)
    return SimulationResult(feasible, q_tank, cost)
end


function tank_recovery_satisfied(wm::WM.AbstractWaterModel)::Bool
    nw_ids = sort(collect(WM.nw_ids(wm)))

    for tank in values(WM.ref(wm, nw_ids[end], :tank))
        node = WM.ref(wm, nw_ids[end], :node, tank["node"])

        if node["head_nominal"] < node["head_min"] - 1.0e-6
            return false
        elseif node["head_nominal"] > node["head_max"] + 1.0e-6
            return false
        end
    end

    return true
end


function simulate_todini_pilati(
    wm::WM.AbstractWaterModel, control_settings::Vector{ControlSetting})
    simulation_results = Vector{SimulationResult}([])

    for nw_id in sort(collect(WM.nw_ids(wm)))[1:end-1]
        flow, head = _simulate_todini_pilati(wm, control_settings[nw_id])
        simulation_result = get_simulation_result(wm, nw_id, flow, head)
        push!(simulation_results, simulation_result)
        !simulation_result.feasible && (return simulation_results)
        update_tank_heads!(wm, nw_id + 1, flow)
    end

    simulation_results[end].feasible = tank_recovery_satisfied(wm)

    return simulation_results
end


function simulate_todini_pilati_and_update!(
    wm::WM.AbstractWaterModel, control_settings::Vector{ControlSetting}, result::Dict
)
    simulation_results = Vector{SimulationResult}([])

    for nw_id in sort(collect(WM.nw_ids(wm)))[1:end-1]
        flow, head = _simulate_todini_pilati(wm, control_settings[nw_id])
        update_flows_and_heads!(control_settings[nw_id], result, flow, head)

        simulation_result = get_simulation_result(wm, nw_id, flow, head)
        push!(simulation_results, simulation_result)
        @assert simulation_result.feasible
        update_tank_heads!(wm, nw_id + 1, flow)
        update_tank_volumes!(wm, result, nw_id + 1, flow)
    end

    simulation_results[end].feasible = tank_recovery_satisfied(wm)

    # Remove unused keys from `result` to avoid confusion.
    for (nw_id, nw) in result["solution"]["nw"]
        for (comp_type, comps) in nw
            if comp_type == "pump" || comp_type == "valve"
                keep_keys = ["q", "status"]
            elseif comp_type == "node"
                keep_keys = ["h"]
            elseif comp_type == "pipe"
                keep_keys = ["q"]
            elseif comp_type == "tank"
                keep_keys = ["V"]
            elseif comp_type == "reservoir"
                keep_keys = []
            else
                error("Unknown component type: $comp_type")
            end

            for (comp_id, comp) in comps
                for key in keys(comp)
                    if !(key in keep_keys)
                        delete!(comps[comp_id], key)
                    end
                end
            end
        end
    end

    return simulation_results
end


function update_flows_and_heads!(control_setting::ControlSetting, result::Dict, flow::Dict, head::Dict)
    result_nw = result["solution"]["nw"][string(control_setting.network_id)]

    for (comp_type, comp_vals) in flow
        for (i, value) in comp_vals
            result_nw[comp_type][string(i)]["q"] = value
        end
    end

    for (i, value) in head
        result_nw["node"][string(i)]["h"] = value
    end

    for (i, vid) in enumerate(control_setting.variable_indices)
        result_nw[string(vid.component_type)][string(vid.component_index)]["status"] = control_setting.vals[i]
    end
end
