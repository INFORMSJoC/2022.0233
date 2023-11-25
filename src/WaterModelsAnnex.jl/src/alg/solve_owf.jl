function compute_pairwise_cuts_nws(data::Dict{String, <:Any}, error_tolerance::Float64, optimizer)
    cuts = Vector{WM._PairwiseCut}([])
    num_time_steps = data["time_series"]["num_steps"]

    # Write something to the logger to say the process has started.
    WM.Memento.info(LOGGER, "Beginning multistep preprocessing routine.")
    time_elapsed = 0.0

    for nw in 1:num_time_steps-1
        data_nw = deepcopy(data)
        WM._IM.load_timepoint!(data_nw, nw)
        WM.set_flow_partitions_si!(data_nw, error_tolerance, 1.0e-4)

        if nw != 1
            map(x -> x["dispatchable"] = true, values(data_nw["tank"]))
            time_elapsed += @elapsed cuts_tmp = compute_pairwise_cuts_nw(data_nw, optimizer)
            map(x -> x["dispatchable"] = false, values(data_nw["tank"]))
        else
            time_elapsed += @elapsed cuts_tmp = compute_pairwise_cuts_nw(data_nw, optimizer)
        end

        map(x -> x.variable_index_1.network_index = nw, cuts_tmp)
        map(x -> x.variable_index_2.network_index = nw, cuts_tmp)
        cuts = vcat(cuts, cuts_tmp)
    end

    time_elapsed_rounded = round(time_elapsed; digits = 2)
    WM.Memento.info(LOGGER, "Multistep cut preprocessing routine completed in $(time_elapsed_rounded) seconds.")

    return cuts
end


function compute_pairwise_cuts_nw(network::Dict{String, <:Any}, optimizer)
    # Construct independent thread-local WaterModels objects.
    wms = Vector{WM.AbstractWaterModel}(undef, Threads.nthreads())

    # Update WaterModels objects in parallel.
    Threads.@threads for i in 1:Threads.nthreads()
        # Instantiate models.
        wms[i] = WM.instantiate_model(deepcopy(network), WM.PWLRDWaterModel, WM.build_owf)

        # Set the optimizer for the bound tightening model.
        JuMP.set_optimizer(wms[i].model, optimizer)
    end

    # Get problem sets for generating pairwise cuts.
    problem_sets = WM._get_pairwise_problem_sets(wms[1])
 
    # Generate data structures to store thread-local cut results.
    cuts_array = Array{Array{WM._PairwiseCut, 1}, 1}([])

    for i in 1:Threads.nthreads()
        # Initialize the per-thread pairwise cut array.
        push!(cuts_array, Array{WM._PairwiseCut, 1}([]))
    end

    # Write something to the logger to say the process has started.
    WM.Memento.info(LOGGER, "Beginning cut preprocessing routine.")

    # Build vector for tracking parallel times elapsed.
    parallel_times_elapsed = zeros(length(problem_sets))

    time_elapsed = @elapsed Threads.@threads for i in 1:length(problem_sets)
        # Compute pairwise cuts across all problem sets.
        parallel_times_elapsed[i] = @elapsed cuts_local = WM._compute_pairwise_cuts!(wms[Threads.threadid()], [problem_sets[i]])
        append!(cuts_array[Threads.threadid()], cuts_local)
    end

    # Write something to the logger to say the process has ended.
    time_elapsed_rounded = round(time_elapsed; digits = 2)
    parallel_time_elapsed = maximum(parallel_times_elapsed)
    parallel_time_elapsed_rounded = round(parallel_time_elapsed; digits = 2)
    WM.Memento.info(LOGGER, "Pairwise cut preprocessing completed in $(time_elapsed_rounded) " *
        "seconds (ideal parallel time: $(parallel_time_elapsed_rounded) seconds).")

    # Return the data structure comprising cuts.
    return vcat(cuts_array...)
end


function set_branching_priorities!(wm::WM.AbstractWaterModel)
    priority = 1

    for comp_type in [:valve, :short_pipe, :regulator, :pump, :pipe]
        for nw in reverse(sort(collect(WM.nw_ids(wm)))[1:end-1])
            for i in WM.ids(wm, nw, comp_type)
                var_symbol = Symbol("y_" * string(comp_type))
                var = WM.var(wm, nw, var_symbol, i)

                if JuMP.is_binary(var)
                    WM.JuMP.MOI.set(JuMP.backend(wm.model).optimizer,
                        Gurobi.VariableAttribute("BranchPriority"),
                        JuMP.index(var), priority)
                end
            end

            priority += 1
        end
    end

    for comp_type in [:valve, :regulator, :pump]
        for nw in reverse(sort(collect(WM.nw_ids(wm)))[1:end-1])
            for i in WM.ids(wm, nw, comp_type)
                var_symbol = Symbol("z_" * string(comp_type))
                var = WM.var(wm, nw, var_symbol, i)

                if JuMP.is_binary(var)
                    WM.JuMP.MOI.set(JuMP.backend(wm.model).optimizer,
                        Gurobi.VariableAttribute("BranchPriority"),
                        JuMP.index(var), priority)
                end
            end

            priority += 1
        end
    end
end


function load_pairwise_cuts(path::String)
    cuts_array = Vector{WM._PairwiseCut}([])
    
    for entry in WM.JSON.parsefile(path)
        vid_1_network_index = Int(entry["variable_index_1"]["network_index"])
        vid_1_component_type = Symbol(entry["variable_index_1"]["component_type"])
        vid_1_variable_symbol = Symbol(entry["variable_index_1"]["variable_symbol"])
        vid_1_component_index = Int(entry["variable_index_1"]["component_index"])
        vid_1 = WM._VariableIndex(vid_1_network_index, vid_1_component_type,
            vid_1_variable_symbol, vid_1_component_index)

        vid_2_network_index = Int(entry["variable_index_2"]["network_index"])
        vid_2_component_type = Symbol(entry["variable_index_2"]["component_type"])
        vid_2_variable_symbol = Symbol(entry["variable_index_2"]["variable_symbol"])
        vid_2_component_index = Int(entry["variable_index_2"]["component_index"])
        vid_2 = WM._VariableIndex(vid_2_network_index, vid_2_component_type,
            vid_2_variable_symbol, vid_2_component_index)

        coefficient_1 = entry["coefficient_1"]
        coefficient_2 = entry["coefficient_2"]
        constant = entry["constant"]
        
        push!(cuts_array, WM._PairwiseCut(coefficient_1, vid_1,
            coefficient_2, vid_2, constant))
    end

    return cuts_array
end


function solve_owf(network_mn::Dict, cuts_path::String, build_method::Function, formulation::Type, mip_optimizer, relax_direction::Bool)
    # Instantiate the model and add cutting planes.
    wm = WM.instantiate_model(network_mn, formulation, build_method)
    cuts = load_pairwise_cuts(cuts_path)
    WM._add_pairwise_cuts!(wm, cuts)

    if relax_direction
        WM._relax_all_direction_variables!(wm)
    end
 
    # Set the optimizer and other important solver parameters.
    WM.JuMP.set_optimizer(wm.model, mip_optimizer)

    # Add the lazy cut callback.
    lazy_cut_stats = add_owf_lazy_cut_callback!(wm)

    # Add branching priorities (which requires instantiation, first).
    time_limit = WM.JuMP.get_optimizer_attribute(wm.model, "TimeLimit")
    WM.JuMP.set_optimizer_attribute(wm.model, "TimeLimit", 0.0)
    WM.optimize_model!(wm)
    set_branching_priorities!(wm)
    WM.JuMP.set_optimizer_attribute(wm.model, "TimeLimit", time_limit)

    # Solve the model and store the result.
    result = WM.optimize_model!(wm)

    # Add true upper bound data to the result dictionary.
    result["true_upper_bound"] = lazy_cut_stats.best_cost
    result["true_gap"] = (result["true_upper_bound"] -
        result["objective_lb"]) / result["true_upper_bound"]
    result["simulation_time"] = lazy_cut_stats.time_elapsed
    result["num_simulations"] = lazy_cut_stats.num_calls

    if length(lazy_cut_stats.best_control_settings) > 0
        # Simulate the best control settings and set result data appropriately.
        simulate_todini_pilati_and_update!(wm, lazy_cut_stats.best_control_settings, result)
    end

    # Return the result dictionary.
    return result
end
