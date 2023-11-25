mutable struct ControlSetting
    network_id::Int
    variable_indices::Vector{WM._VariableIndex}
    vals::Vector{Float64}
end


function get_control_settings_at_nw(result::Dict{String, <:Any}, nw::Int)
    sol_nw = result["solution"]["nw"][string(nw)]

    if haskey(sol_nw, "pump")
        pump_ids = sort([parse(Int, x) for x in collect(keys(sol_nw["pump"]))])
        pump_vals = [sol_nw["pump"][string(i)]["status"] for i in pump_ids]
        pump_vars = WM._VariableIndex.(nw, :pump, :z_pump, pump_ids)
    else
        pump_vals, pump_vars = [], []
    end

    if haskey(sol_nw, "valve")
        valve_ids = sort([parse(Int, x) for x in collect(keys(sol_nw["valve"]))])
        valve_vals = [sol_nw["valve"][string(i)]["status"] for i in valve_ids]
        valve_vars = WM._VariableIndex.(nw, :valve, :z_valve, valve_ids)
    else
        valve_vals, valve_vars = [], []
    end

    if haskey(sol_nw, "regulator")
        regulator_ids = sort([parse(Int, x) for x in collect(keys(sol_nw["regulator"]))])
        regulator_vals = [sol_nw["regulator"][string(i)]["status"] for i in regulator_ids]
        regulator_vars = WM._VariableIndex.(nw, :regulator, :z_regulator, regulator_ids)
    else
        regulator_vals, regulator_vars = [], []
    end

    vars = vcat(pump_vars, regulator_vars, valve_vars)
    vals = vcat(pump_vals, regulator_vals, valve_vals)
    return ControlSetting(nw, vars, round.(vals))
end


function get_control_settings_from_result(result::Dict{String, <:Any})
    nw_ids = sort([parse(Int, x) for x in keys(result["solution"]["nw"])])
    return get_control_settings_at_nw.(Ref(result), nw_ids)
end


function get_control_settings(data::Dict{String,<:Any})::Vector{ControlSetting}
    @assert WM.ismultinetwork(data)
    control_settings = Vector{ControlSetting}([])
    nw_ids = sort([parse(Int, x) for x in keys(data["nw"])])[1:end-1]

    for nw_id in nw_ids
        nw_data = data["nw"][string(nw_id)]
        variable_indices = Vector{WM._VariableIndex}([])
        variable_values = Vector{Float64}([])

        for pump in values(get(nw_data, "pump", Dict{String,Any}()))
            vid = WM._VariableIndex(nw_id, :pump, :z_pump, pump["index"])
            push!(variable_indices, vid)
            push!(variable_values, Int(pump["status"]))
        end

        for valve in values(get(nw_data, "valve", Dict{String,Any}()))
            vid = WM._VariableIndex(nw_id, :valve, :z_valve, valve["index"])
            push!(variable_indices, vid)
            push!(variable_values, Int(valve["status"]))
        end

        control_setting = ControlSetting(nw_id, variable_indices, variable_values)
        push!(control_settings, control_setting)
    end

    return control_settings
end


function create_pump_settings_at_time(wm::WM.AbstractWaterModel, n::Int)
    control_settings = Array{Array{ControlSetting}}([])

    # Create variable indices for all controllable components at time `n`.
    for (pump_group_id, pump_group) in WM.ref(wm, n, :pump_group)
        pump_ids = sort(collect(pump_group["pump_indices"]))
        pump_combinations = vcat([zeros(length(pump_ids))], [[j >= i ? 1.0 :
            0.0 for i = 1:length(pump_ids)] for j = 1:length(pump_ids)])
        pump_vars = WM._VariableIndex.(n, :pump, :z_pump, pump_ids)
        append!(control_settings, [ControlSetting.(n, Ref(pump_vars), pump_combinations)])
    end

    pump_ids_group = vcat([sort(collect(x["pump_indices"]))
        for (i, x) in WM.ref(wm, n, :pump_group)]...)
    pump_ids = filter(x -> !(x in pump_ids_group), WM.ids(wm, n, :pump))

    if length(pump_ids) > 0
        z = WM._VariableIndex.(n, :pump, :z_pump, pump_ids)
        product = Iterators.product([[0.0, 1.0] for k in 1:length(z)]...)
        vals = [collect(x) for x in collect(product)]
        append!(control_settings, [ControlSetting.(n, Ref(z), vals)])
    end

    return control_settings
end


function create_regulator_settings_at_time(wm::WM.AbstractWaterModel, n::Int)
    regulator_ids = sort(collect(WM.ids(wm, n, :regulator)))
    control_settings = Array{Array{ControlSetting}}([])

    if length(regulator_ids) > 0
        z = WM._VariableIndex.(n, :regulator, :z_regulator, regulator_ids)
        product = Iterators.product([[0.0, 1.0] for k in 1:length(z)]...)
        vals = [collect(x) for x in collect(product)]
        append!(control_settings, [ControlSetting.(n, Ref(z), vals)])
    end

    return control_settings
end


function create_valve_settings_at_time(wm::WM.AbstractWaterModel, n::Int)
    valve_ids = sort(collect(WM.ids(wm, n, :valve)))
    control_settings = Array{Array{ControlSetting}}([])

    if length(valve_ids) > 0
        z = WM._VariableIndex.(n, :valve, :z_valve, valve_ids)
        product = Iterators.product([[0.0, 1.0] for k in 1:length(z)]...)
        vals = [collect(x) for x in collect(product)]
        append!(control_settings, [ControlSetting.(n, Ref(z), vals)])
    end

    return control_settings
end


function cartesian_product(settings::Array{Array{ControlSetting}})
    # Compute the Cartesian product of control settings.
    product = vcat(collect(Iterators.product(settings...))...)

    # Concatenate variable indices per unique control setting.
    vars = [vcat([product[i][j].variable_indices for j in
        1:length(product[i])]...) for i in 1:length(product)]

    # Concatenate values per unique control setting.
    vals = [vcat([product[i][j].vals for j in
        1:length(product[i])]...) for i in 1:length(product)]

    # Return an array of all unique control settings.
    return ControlSetting.(product[1][1].network_id, vars, vals)
end


function create_control_settings_at_time(wm::WM.AbstractWaterModel, n::Int)
    pump_control_settings = create_pump_settings_at_time(wm, n)
    regulator_control_settings = create_regulator_settings_at_time(wm, n)
    valve_control_settings = create_valve_settings_at_time(wm, n)
    control_settings_partitioned = vcat(pump_control_settings,
        regulator_control_settings, valve_control_settings)
    return cartesian_product(control_settings_partitioned)
end


function create_all_control_settings(wm::WM.AbstractWaterModel)
    network_ids = sort(collect(WM.nw_ids(wm)))[1:end-1]
    return vcat([create_control_settings_at_time(wm, n) for n in network_ids]...)
end