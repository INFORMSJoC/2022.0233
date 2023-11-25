function _get_indicator_variables_to_nw(wm::WM.AbstractWaterModel, nw_last::Int)
    vars = Array{WM.JuMP.VariableRef, 1}()
    network_ids = sort(collect(WM.nw_ids(wm)))[1:nw_last]

    for var_sym in [:z_pump, :z_regulator, :z_valve]
        for nw_id in network_ids
            append!(vars, vcat(WM.var(wm, nw_id, var_sym)...))
        end
    end

    return vars
end


function add_feasibility_cut!(wm::WM.AbstractWaterModel, cb_data, nw_last::Int)    
    # Collect the current integer solution into "zero" and "one" buckets.
    vars = _get_indicator_variables_to_nw(wm, nw_last)
    zero_vars = filter(x -> round(WM.JuMP.callback_value(cb_data, x)) < 0.5, vars)
    one_vars = filter(x -> round(WM.JuMP.callback_value(cb_data, x)) >= 0.5, vars)
    @assert length(zero_vars) + length(one_vars) == length(vars)

    # If the solution is not feasible (according to a simulation), add a no-good cut.
    con = WM.JuMP.@build_constraint(sum(zero_vars) - sum(one_vars) >= 1.0 - length(one_vars))
    WM.JuMP.MOI.submit(wm.model, WM.JuMP.MOI.LazyConstraint(cb_data), con)
end


function get_control_settings_at_nw_cb(wm::WM.AbstractWaterModel, cb_data, nw::Int)
    pump_vids = WM._VariableIndex.(nw, :pump, :z_pump, WM.ids(wm, nw, :pump))
    valve_vids = WM._VariableIndex.(nw, :valve, :z_valve, WM.ids(wm, nw, :valve))
    regulator_vids = WM._VariableIndex.(nw, :regulator, :z_regulator, WM.ids(wm, nw, :regulator))

    vids = vcat(pump_vids, valve_vids, regulator_vids)
    vars = WM._get_variable_from_index.(Ref(wm), vids)
    vals = abs.(round.(WM.JuMP.callback_value.(Ref(cb_data), vars)))
    return ControlSetting(nw, vids, vals)
end


mutable struct CallbackStats
    time_elapsed::Float64
    num_calls::Int64
    best_cost::Float64
    best_control_settings::Vector{ControlSetting}
end


function get_owf_lazy_cut_callback(wm::WM.AbstractWaterModel, stats::CallbackStats)
    network_ids = sort(collect(WM.nw_ids(wm)))[1:end-1]

    return function callback_function(cb_data)
        cb_status = MOI.get(wm.model, MOI.CallbackNodeStatus(cb_data))::MOI.CallbackNodeStatusCode

        if cb_status == MOI.CALLBACK_NODE_STATUS_INTEGER
            control_settings = get_control_settings_at_nw_cb.(
                Ref(wm), cb_data, network_ids)

            stats.time_elapsed += @elapsed simulation_results =
                simulate_todini_pilati(wm, control_settings)

            if any(x -> !x.feasible, simulation_results)
                id_infeasible = findfirst(x -> !x.feasible, simulation_results)
                nw_infeasible = network_ids[id_infeasible]
                add_feasibility_cut!(wm, cb_data, nw_infeasible)
            else
                cost = sum(x.cost for x in simulation_results)
                WM.Memento.info(LOGGER, "Found feasible solution with cost $(cost).")

                if cost < stats.best_cost
                    stats.best_cost = cost
                    stats.best_control_settings = deepcopy(control_settings)
                end
            end

            stats.num_calls += 1
        end
    end
end


function add_owf_lazy_cut_callback!(wm::WM.AbstractWaterModel)
    callback_stats = CallbackStats(0.0, 0, Inf, Vector{ControlSetting}([]))
    callback_function = get_owf_lazy_cut_callback(wm, callback_stats)
    WM.JuMP.MOI.set(wm.model, WM.JuMP.MOI.LazyConstraintCallback(), callback_function)
    return callback_stats
end
