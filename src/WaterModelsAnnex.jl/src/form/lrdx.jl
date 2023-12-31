function _calc_pipe_flow_integrated_bound(q::JuMP.VariableRef, z::Union{JuMP.VariableRef, JuMP.GenericAffExpr}, q_lb::Float64, q_ub::Float64, exponent::Float64)
    f_lb, f_ub = q_lb^(1.0 + exponent), q_ub^(1.0 + exponent)
    return f_lb * z + (f_ub - f_lb) / (q_ub - q_lb) * (q - q_lb * z)
end


function _calc_pipe_flow_integrated_oa(q::JuMP.VariableRef, z::Union{JuMP.VariableRef, JuMP.GenericAffExpr}, q_hat::Float64, exponent::Float64)
    f = q_hat^(1.0 + exponent)
    df = (1.0 + exponent) * q_hat^exponent
    return f * z + df * (q - q_hat * z)
end


function _calc_pump_flow_integrated(q_hat::Float64, coeffs::Vector{Float64})
    return coeffs[1] * q_hat + coeffs[2] * q_hat^(1.0 + coeffs[3])
end


function _calc_pump_flow_integrated_oa(q::JuMP.VariableRef, z::Union{JuMP.VariableRef, JuMP.GenericAffExpr}, q_hat::Float64, coeffs::Vector{Float64})
    f = coeffs[1] * q_hat + coeffs[2] * q_hat^(1.0 + coeffs[3])
    df = coeffs[1] + (1.0 + coeffs[3]) * coeffs[2] * q_hat^(coeffs[3])
    return f * z + df * (q - q_hat * z)
end


function _calc_pump_flow_integrated_bound(q::JuMP.VariableRef, z::Union{JuMP.VariableRef, JuMP.GenericAffExpr}, q_lb::Float64, q_ub::Float64, coeffs::Vector{Float64})
    f_lb = coeffs[1] * q_lb + coeffs[2] * q_lb^(1.0 + coeffs[3])
    f_ub = coeffs[1] * q_ub + coeffs[2] * q_ub^(1.0 + coeffs[3])
    return f_lb * z + (f_ub - f_lb) / (q_ub - q_lb) * (q - q_lb * z)
end


function variable_pipe_flow_nonlinear(wm::Union{AbstractPWLRDXModel,AbstractLRDXModel}; nw::Int = WM.nw_id_default, bounded::Bool = true, report::Bool = true)
    # Initialize variables associated with positive flows.
    qp_nl = WM.var(wm, nw)[:qp_nl_pipe] = JuMP.@variable(
        wm.model, [a in WM.ids(wm, nw, :pipe)], lower_bound = 0.0, base_name="$(nw)_qp_nl",
        start = WM.comp_start_value(WM.ref(wm, nw, :pipe, a), "qp_nl_start", 1.0e-6))

    # Report positive directed flow values as part of the solution.
    report && WM.sol_component_value(wm, nw, :pipe, :qp_nl, WM.ids(wm, nw, :pipe), qp_nl)

    # Initialize variables associated with negative flows.
    qn_nl = WM.var(wm, nw)[:qn_nl_pipe] = JuMP.@variable(
        wm.model, [a in WM.ids(wm, nw, :pipe)], lower_bound = 0.0, base_name = "$(nw)_qn_nl",
        start = WM.comp_start_value(WM.ref(wm, nw, :pipe, a), "qn_nl_start", 1.0e-6))

    # Report negative directed flow values as part of the solution.
    report && WM.sol_component_value(wm, nw, :pipe, :qn_nl, WM.ids(wm, nw, :pipe), qn_nl)
end


function variable_pump_flow_nonlinear(wm::Union{AbstractPWLRDXModel,AbstractLRDXModel}; nw::Int = WM.nw_id_default, bounded::Bool = true, report::Bool = true)
    # Initialize variables associated with positive flows.
    qp_nl = WM.var(wm, nw)[:qp_nl_pump] = JuMP.@variable(
        wm.model, [a in WM.ids(wm, nw, :pump)], lower_bound = 0.0, base_name = "$(nw)_qp_nl",
        start = WM.comp_start_value(WM.ref(wm, nw, :pump, a), "qp_nl_start", 1.0e-6))

    # Report positive directed flow values as part of the solution.
    report && WM.sol_component_value(wm, nw, :pump, :qp_nl, WM.ids(wm, nw, :pump), qp_nl)
end


function variable_tank_nonlinear(wm::Union{AbstractPWLRDXModel,AbstractLRDXModel}; nw::Int=WM.nw_id_default, bounded::Bool = true, report::Bool = true)
    # Initialize variables associated with tank flow-head nonlinearities.
    qh_nl = WM.var(wm, nw)[:qh_nl_tank] = JuMP.@variable(
        wm.model, [i in WM.ids(wm, nw, :tank)], base_name = "$(nw)_qh_nl",
        start = WM.comp_start_value(WM.ref(wm, nw, :tank, i), "qh_nl_start", 0.0))

    # Report multiplied head and flow as part of the solution.
    report && WM.sol_component_value(wm, nw, :tank, :qh_nl, WM.ids(wm, nw, :tank), qh_nl)
end


function constraint_pipe_flow_nonlinear(
    wm::AbstractLRDXModel, n::Int, a::Int, node_fr::Int, node_to::Int, exponent::Float64,
    L::Float64, r::Float64, q_max_reverse::Float64, q_min_forward::Float64)
    # Get the variable for flow directionality.
    y = WM.var(wm, n, :y_pipe, a)

    # Get variables for positive flow and nonlinear term.
    qp = WM.var(wm, n, :qp_pipe, a)
    qp_nl = WM.var(wm, n, :qp_nl_pipe, a)

    # Get the corresponding positive flow partitioning.
    partition_p = WM.get_pipe_flow_partition_positive(WM.ref(wm, n, :pipe, a))

    # Loop over consequential points (i.e., those that have nonzero head loss).
    for flow_value in filter(x -> x > 0.0, partition_p)
        # Add a linear outer approximation of the convex constraint at `flow_value`.
        lhs = r * _calc_pipe_flow_integrated_oa(qp, y, flow_value, exponent)

        # Add outer-approximation of the nonlinear flow constraint.
        scalar = WM._get_scaling_factor(vcat(lhs.terms.vals, [1.0 / L]))
        c = JuMP.@constraint(wm.model, scalar * lhs <= scalar * qp_nl / L)

        # Append the :pipe_flow_nonlinear constraint array.
        append!(WM.con(wm, n, :pipe_flow_nonlinear)[a], [c])
    end

    # Get the corresponding min/max positive directed flows (when active).
    qp_min_forward = max(0.0, q_min_forward)
    qp_max = max(maximum(partition_p), JuMP.upper_bound(qp))

    if qp_min_forward != qp_max
        # Add upper-bounding lines of the head loss constraint.
        f_ub_line_p = r * _calc_pipe_flow_integrated_bound(qp, y, qp_min_forward, qp_max, exponent)
        scalar = WM._get_scaling_factor(vcat(f_ub_line_p.terms.vals, [1.0 / L]))
        c = JuMP.@constraint(wm.model, scalar * qp_nl / L <= scalar * f_ub_line_p)

        # Append the :on_off_des_pipe_head_loss constraint array.
        append!(WM.con(wm, n, :pipe_flow_nonlinear)[a], [c])
    elseif qp_max == 0.0
        c = JuMP.@constraint(wm.model, qp_nl == 0.0)
        append!(WM.con(wm, n, :pipe_flow_nonlinear)[a], [c])
    else
        f_q = r * qp_max^(1.0 + exponent)
        scalar = WM._get_scaling_factor([f_q == 0.0 ? 1.0 : f_q, 1.0 / L])
        c = JuMP.@constraint(wm.model, scalar * qp_nl / L == scalar * f_q * y)
        append!(WM.con(wm, n, :pipe_flow_nonlinear)[a], [c])
    end

    # Get variables for negative flow and nonlinear term.
    qn = WM.var(wm, n, :qn_pipe, a)
    qn_nl = WM.var(wm, n, :qn_nl_pipe, a)

    # Get the corresponding negative flow partitioning.
    partition_n = sort(-WM.get_pipe_flow_partition_negative(WM.ref(wm, n, :pipe, a)))

    # Loop over consequential points (i.e., those that have nonzero head loss).
    for flow_value in filter(x -> x > 0.0, partition_n)
        # Add a linear outer approximation of the convex relaxation at `flow_value`.
        lhs = r * _calc_pipe_flow_integrated_oa(qn, 1.0 - y, flow_value, exponent)

        # Add outer-approximation of the nonlinear flow constraint.
        scalar = WM._get_scaling_factor(vcat(lhs.terms.vals, [1.0 / L]))
        c = JuMP.@constraint(wm.model, scalar * lhs <= scalar * qn_nl / L)

        # Append the :pipe_flow_nonlinear constraint array.
        append!(WM.con(wm, n, :pipe_flow_nonlinear)[a], [c])
    end

    # Get the corresponding maximum negative directed flow (when active).
    qn_min_forward = max(0.0, -q_max_reverse)
    qn_max = max(maximum(partition_n), JuMP.upper_bound(qn))

    if qn_min_forward != qn_max
        # Add upper-bounding lines of the head loss constraint.
        f_ub_line_n = r * _calc_pipe_flow_integrated_bound(qn, 1.0 - y, qn_min_forward, qn_max, exponent)
        scalar = WM._get_scaling_factor(vcat(f_ub_line_n.terms.vals, [1.0 / L]))
        c = JuMP.@constraint(wm.model, scalar * qn_nl / L <= scalar * f_ub_line_n)

        # Append the :on_off_des_pipe_head_loss constraint array.
        append!(WM.con(wm, n, :pipe_flow_nonlinear)[a], [c])
    elseif qn_max == 0.0
        c = JuMP.@constraint(wm.model, qn_nl == 0.0)
        append!(WM.con(wm, n, :pipe_flow_nonlinear)[a], [c])
    else
        f_q = r * qn_max^(1.0 + exponent)
        scalar = WM._get_scaling_factor([f_q == 0.0 ? 1.0 : f_q, 1.0 / L])
        c = JuMP.@constraint(wm.model, scalar * qn_nl / L == scalar * f_q * (1.0 - y))
        append!(WM.con(wm, n, :pipe_flow_nonlinear)[a], [c])
    end
end


function constraint_on_off_pump_flow_nonlinear(
    wm::AbstractLRDXModel, n::Int, a::Int, node_fr::Int,
    node_to::Int, coeffs::Vector{Float64}, q_min_forward::Float64)
    # Get the variable for pump status.
    z = WM.var(wm, n, :z_pump, a)

    # Get variables for positive flow and head difference.
    qp = WM.var(wm, n, :qp_pump, a)
    qp_nl = WM.var(wm, n, :qp_nl_pump, a)
    partition = WM.ref(wm, n, :pump, a, "flow_partition")

    # Loop over breakpoints strictly between the lower and upper variable bounds.
    for pt in partition
        # Add a linear outer approximation of the convex relaxation at `pt`.
        rhs = _calc_pump_flow_integrated_oa(qp, z, pt, coeffs)

        # Add outer-approximation of the integrated head loss constraint.
        scalar = WM._get_scaling_factor(vcat(rhs.terms.vals, [1.0]))
        c = JuMP.@constraint(wm.model, scalar * qp_nl <= scalar * rhs)

        # Append the :pump_head_loss_integrated constraint array.
        append!(WM.con(wm, n, :on_off_pump_flow_nonlinear)[a], [c])
    end

    # Get the corresponding min/max positive directed flows (when active).
    qp_min_forward = max(0.0, q_min_forward)
    qp_max = max(maximum(partition), JuMP.upper_bound(qp))

    if qp_min_forward != qp_max
        # Add upper-bounding line for the nonlinear constraint.
        lhs = _calc_pump_flow_integrated_bound(qp, z, qp_min_forward, qp_max, coeffs)
        scalar = WM._get_scaling_factor(vcat(lhs.terms.vals, [1.0]))
        c = JuMP.@constraint(wm.model, scalar * lhs <= scalar * qp_nl)

        # Append the :on_off_des_pipe_head_loss constraint array.
        append!(WM.con(wm, n, :on_off_pump_flow_nonlinear)[a], [c])
    elseif qp_max == 0.0
        c = JuMP.@constraint(wm.model, qp_nl == 0.0)
        append!(WM.con(wm, n, :on_off_pump_flow_nonlinear)[a], [c])
    else
        f_q = _calc_pump_flow_integrated(qp_max, coeffs)
        scalar = WM._get_scaling_factor([f_q == 0.0 ? 1.0 : f_q, 1.0])
        c = JuMP.@constraint(wm.model, scalar * qp_nl == scalar * f_q * z)
        append!(WM.con(wm, n, :on_off_pump_flow_nonlinear)[a], [c])
    end
end


""
function constraint_tank_nonlinear(wm::Union{AbstractPWLRDXModel,AbstractLRDXModel}, n::Int, i::Int, node_index::Int)
    q, h = WM.var(wm, n, :q_tank, i), WM.var(wm, n, :h, node_index)
    qh_nl_tank = WM.var(wm, n, :qh_nl_tank, i)
    q_lb, q_ub = JuMP.lower_bound(q), JuMP.upper_bound(q)
    h_lb, h_ub = JuMP.lower_bound(h), JuMP.upper_bound(h)

    c_1 = JuMP.@constraint(wm.model, qh_nl_tank >= q_lb * h + h_lb * q - q_lb * h_lb)
    c_2 = JuMP.@constraint(wm.model, qh_nl_tank >= q_ub * h + h_ub * q - q_ub * h_ub)
    c_3 = JuMP.@constraint(wm.model, qh_nl_tank <= q_lb * h + h_ub * q - q_lb * h_ub)
    c_4 = JuMP.@constraint(wm.model, qh_nl_tank <= q_ub * h + h_lb * q - q_ub * h_lb)

    append!(WM.con(wm, n, :tank_nonlinear)[i], [c_1, c_2, c_3, c_4])
end


""
function constraint_strong_duality(wm::Union{AbstractPWLRDXModel,AbstractLRDXModel}, nw::Int)
    qp_pipe_nl = sum(WM.var(wm, nw, :qp_nl_pipe))
    qn_pipe_nl = sum(WM.var(wm, nw, :qn_nl_pipe))
    qp_pump_nl = sum(WM.var(wm, nw, :qp_nl_pump))
    qh_nl_tank = sum(WM.var(wm, nw, :qh_nl_tank))

    reservoir_sum = JuMP.AffExpr(0.0)

    for res in values(WM.ref(wm, nw, :reservoir))
        head = WM.ref(wm, nw, :node, res["node"], "head_nominal")
        q_reservoir = WM.var(wm, nw, :q_reservoir, res["index"])
        reservoir_sum += q_reservoir * head
    end

    demand_sum = JuMP.AffExpr(0.0)

    for demand in values(WM.ref(wm, nw, :demand))
        h = WM.var(wm, nw, :h, demand["node"])
        demand_sum += h * demand["flow_nominal"]
    end

    linear_terms = demand_sum - reservoir_sum
    nonlinear_terms = qp_pipe_nl + qn_pipe_nl - qp_pump_nl - qh_nl_tank
    c = JuMP.@constraint(wm.model, linear_terms + nonlinear_terms <= 0.0)
    append!(WM.con(wm, nw, :strong_duality, 1), [c])
end
