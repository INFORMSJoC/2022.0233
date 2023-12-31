function WM.build_wf(wm::Union{AbstractLRDXModel, AbstractPWLRDXModel})
    # Create head loss functions, if necessary.
    WM._function_head_loss(wm)

    # Physical variables.
    WM.variable_head(wm)
    WM.variable_flow(wm)
    WM.variable_pump_head_gain(wm)
    WM.variable_pump_power(wm)

    # Additional variables for nonlinearities.
    variable_pipe_flow_nonlinear(wm)
    variable_pump_flow_nonlinear(wm)
    variable_tank_nonlinear(wm)

    # Indicator (status) variables.
    WM.variable_des_pipe_indicator(wm)
    WM.variable_pump_indicator(wm)
    WM.variable_regulator_indicator(wm)
    WM.variable_valve_indicator(wm)

    # Create flow-related variables for node attachments.
    WM.variable_demand_flow(wm)
    WM.variable_reservoir_flow(wm)
    WM.variable_tank_flow(wm)

    # Flow conservation at all nodes.
    for (i, node) in WM.ref(wm, :node)
        WM.constraint_flow_conservation(wm, i)
        WM.constraint_node_directionality(wm, i)
    end

    # Constraints on pipe flows, heads, and physics.
    for (a, pipe) in WM.ref(wm, :pipe)
        WM.constraint_pipe_head(wm, a)
        WM.constraint_pipe_head_loss(wm, a)
        WM.constraint_pipe_flow(wm, a)
        constraint_pipe_flow_nonlinear(wm, a)
    end

    # Selection of design pipes along unique arcs.
    for (k, arc) in WM.ref(wm, :des_pipe_arc)
        WM.constraint_des_pipe_flow(wm, k, arc[1], arc[2])
        WM.constraint_des_pipe_head(wm, k, arc[1], arc[2])
        WM.constraint_des_pipe_selection(wm, k, arc[1], arc[2])
    end

    # Constraints on design pipe flows, heads, and physics.
    for (a, des_pipe) in WM.ref(wm, :des_pipe)
        WM.constraint_on_off_des_pipe_head(wm, a)
        WM.constraint_on_off_des_pipe_head_loss(wm, a)
        WM.constraint_on_off_des_pipe_flow(wm, a)
    end

    # Constraints on pump flows, heads, and physics.
    for (a, pump) in WM.ref(wm, :pump)
        WM.constraint_on_off_pump_head(wm, a)
        WM.constraint_on_off_pump_head_gain(wm, a)
        WM.constraint_on_off_pump_flow(wm, a)
        WM.constraint_on_off_pump_power(wm, a)
        constraint_on_off_pump_flow_nonlinear(wm, a)
    end

    for (k, pump_group) in WM.ref(wm, :pump_group)
        WM.constraint_on_off_pump_group(wm, k)
    end

    # Constraints on short pipe flows and heads.
    for (a, regulator) in WM.ref(wm, :regulator)
        WM.constraint_on_off_regulator_head(wm, a)
        WM.constraint_on_off_regulator_flow(wm, a)
    end

    # Constraints on short pipe flows and heads.
    for (a, short_pipe) in WM.ref(wm, :short_pipe)
        WM.constraint_short_pipe_head(wm, a)
        WM.constraint_short_pipe_flow(wm, a)
    end

    # Constraints on tank volumes.
    for (i, tank) in WM.ref(wm, :tank)
        # Set the initial tank volume.
        WM.constraint_tank_volume(wm, i)
        constraint_tank_nonlinear(wm, i)
    end

    # Constraints on valve flows and heads.
    for (a, valve) in WM.ref(wm, :valve)
        WM.constraint_on_off_valve_head(wm, a)
        WM.constraint_on_off_valve_flow(wm, a)
    end

    # Add the strong duality constraint.
    constraint_strong_duality(wm)

    # Add the objective.
    WM.objective_wf(wm)
end


function WM.build_mn_wf(wm::Union{AbstractLRDXModel, AbstractPWLRDXModel})
    # Create head loss functions, if necessary.
    WM._function_head_loss(wm)

    # Get all network IDs in the multinetwork.
    network_ids = sort(collect(WM.nw_ids(wm)))

    if length(network_ids) > 1
        network_ids_inner = network_ids[1:end-1]
    else
        network_ids_inner = network_ids
    end

    for n in network_ids_inner
        # Physical variables.
        WM.variable_head(wm; nw=n)
        WM.variable_flow(wm; nw=n)
        WM.variable_pump_head_gain(wm; nw=n)
        WM.variable_pump_power(wm; nw=n)

        # Additional variables for nonlinearities.
        variable_pipe_flow_nonlinear(wm; nw=n)
        variable_pump_flow_nonlinear(wm; nw=n)
        variable_tank_nonlinear(wm; nw=n)

        # Indicator (status) variables.
        WM.variable_des_pipe_indicator(wm; nw=n)
        WM.variable_pump_indicator(wm; nw=n)
        WM.variable_regulator_indicator(wm; nw=n)
        WM.variable_valve_indicator(wm; nw=n)

        # Create flow-related variables for node attachments.
        WM.variable_demand_flow(wm; nw=n)
        WM.variable_reservoir_flow(wm; nw=n)
        WM.variable_tank_flow(wm; nw=n)

        # Flow conservation at all nodes.
        for (i, node) in WM.ref(wm, :node; nw=n)
            WM.constraint_flow_conservation(wm, i; nw=n)
            WM.constraint_node_directionality(wm, i; nw=n)
        end

        # Constraints on pipe flows, heads, and physics.
        for (a, pipe) in WM.ref(wm, :pipe; nw=n)
            WM.constraint_pipe_flow(wm, a; nw=n)
            WM.constraint_pipe_head(wm, a; nw=n)
            WM.constraint_pipe_head_loss(wm, a; nw=n)
            constraint_pipe_flow_nonlinear(wm, a; nw=n)
        end

        # Constraints on design pipe flows, heads, and physics.
        for (a, des_pipe) in WM.ref(wm, :des_pipe; nw=n)
            WM.constraint_on_off_des_pipe_flow(wm, a; nw=n)
            WM.constraint_on_off_des_pipe_head(wm, a; nw=n)
            WM.constraint_on_off_des_pipe_head_loss(wm, a; nw=n)
        end

        # Selection of design pipes along unique arcs.
        for (k, arc) in WM.ref(wm, :des_pipe_arc; nw=n)
            WM.constraint_des_pipe_flow(wm, k, arc[1], arc[2]; nw=n)
            WM.constraint_des_pipe_head(wm, k, arc[1], arc[2]; nw=n)
            WM.constraint_des_pipe_selection(wm, k, arc[1], arc[2]; nw=n)
        end

        # Constraints on pump flows, heads, and physics.
        for (a, pump) in WM.ref(wm, :pump; nw=n)
            WM.constraint_on_off_pump_head(wm, a; nw=n)
            WM.constraint_on_off_pump_head_gain(wm, a; nw=n)
            WM.constraint_on_off_pump_flow(wm, a; nw=n)
            WM.constraint_on_off_pump_power(wm, a; nw=n)
            constraint_on_off_pump_flow_nonlinear(wm, a; nw=n)
        end

        for (k, pump_group) in WM.ref(wm, :pump_group; nw=n)
            WM.constraint_on_off_pump_group(wm, k; nw=n)
        end

        # Constraints on short pipe flows and heads.
        for (a, regulator) in WM.ref(wm, :regulator; nw=n)
            WM.constraint_on_off_regulator_head(wm, a; nw=n)
            WM.constraint_on_off_regulator_flow(wm, a; nw=n)
        end

        # Constraints on short pipe flows and heads.
        for (a, short_pipe) in WM.ref(wm, :short_pipe; nw=n)
            WM.constraint_short_pipe_head(wm, a; nw=n)
            WM.constraint_short_pipe_flow(wm, a; nw=n)
        end

        # Constraints on valve flows and heads.
        for (a, valve) in WM.ref(wm, :valve; nw=n)
            WM.constraint_on_off_valve_head(wm, a; nw=n)
            WM.constraint_on_off_valve_flow(wm, a; nw=n)
        end

        # Constraints on tank nonlinearities.
        for i in WM.ids(wm, :tank; nw=n)
            constraint_tank_nonlinear(wm, i; nw=n)
        end

        # Add the strong duality constraint.
        constraint_strong_duality(wm; nw=n)
    end

    # Start with the first network, representing the initial time step.
    n_1 = network_ids[1]

    # Constraints on tank volumes.
    for i in WM.ids(wm, :tank; nw = n_1)
        # Set initial conditions of tanks.
        WM.constraint_tank_volume(wm, i; nw = n_1)
    end

    if length(network_ids) > 1
        # Initialize head variables for the final time index.
        WM.variable_head(wm; nw = network_ids[end])

        # Constraints on tank volumes.
        for n_2 in network_ids[2:end]
            # Constrain tank volumes after the initial time index.
            for i in WM.ids(wm, :tank; nw = n_2)
                WM.constraint_tank_volume(wm, i, n_1, n_2)
            end

            # Update the first network used for integration.
            n_1 = n_2
        end
    end

    # Add the objective.
    WM.objective_wf(wm)
end


function WM.build_mn_owf(wm::Union{AbstractLRDXModel, AbstractPWLRDXModel})
    # Build the water flow problem.
    WM.build_mn_wf(wm)

    # Get all network IDs in the multinetwork.
    network_ids = sort(collect(WM.nw_ids(wm)))

    # Ensure tanks recover their initial volume.
    n_1, n_f = network_ids[1], network_ids[end]

    for i in WM.ids(wm, n_f, :tank)
        WM.constraint_tank_volume_recovery(wm, i, n_1, n_f)
    end

    # Add the optimal water flow objective.
    WM.objective_owf(wm)
end