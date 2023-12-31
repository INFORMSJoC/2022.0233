function constraint_pipe_flow_nonlinear(wm::WM.AbstractWaterModel, a::Int; nw::Int=WM.nw_id_default, kwargs...)
    node_fr = WM.ref(wm, nw, :pipe, a, "node_fr")
    node_to = WM.ref(wm, nw, :pipe, a, "node_to")
    L = WM.ref(wm, nw, :pipe, a, "length")
    exponent = WM._get_exponent_from_head_loss_form(
        wm.ref[:it][WM.wm_it_sym][:head_loss])    

    base_length = get(wm.data, "base_length", 1.0)
    base_mass = get(wm.data, "base_mass", 1.0)
    base_time = get(wm.data, "base_time", 1.0)

    r = WM._calc_pipe_resistance(
        WM.ref(wm, nw, :pipe, a), wm.data["head_loss"],
        wm.data["viscosity"], base_length, base_mass, base_time)

    q_max_reverse = min(get(WM.ref(wm, nw, :pipe, a), "flow_max_reverse", 0.0), 0.0)
    q_min_forward = max(get(WM.ref(wm, nw, :pipe, a), "flow_min_forward", 0.0), 0.0)

    WM._initialize_con_dict(wm, :pipe_flow_nonlinear, nw=nw, is_array=true)
    WM.con(wm, nw, :pipe_flow_nonlinear)[a] = Array{JuMP.ConstraintRef}([])
    constraint_pipe_flow_nonlinear(wm, nw, a, node_fr, node_to, exponent, L, r, q_max_reverse, q_min_forward)
end


function constraint_on_off_pump_flow_nonlinear(wm::WM.AbstractWaterModel, a::Int; nw::Int=WM.nw_id_default, kwargs...)
    node_fr, node_to = WM.ref(wm, nw, :pump, a)["node_fr"], WM.ref(wm, nw, :pump, a)["node_to"]
    q_min_forward = max(get(WM.ref(wm, nw, :pump, a), "flow_min_forward", 0.0), 0.0)
    coeffs =  WM.ref(wm, nw, :pump, a, "head_curve_coefficients")

    WM._initialize_con_dict(wm, :on_off_pump_flow_nonlinear, nw=nw, is_array=true)
    WM.con(wm, nw, :on_off_pump_flow_nonlinear)[a] = Array{JuMP.ConstraintRef}([])
    constraint_on_off_pump_flow_nonlinear(wm, nw, a, node_fr, node_to, coeffs, q_min_forward)
end


function constraint_tank_nonlinear(wm::WM.AbstractWaterModel, i::Int; nw::Int=WM.nw_id_default, kwargs...)
    node_index = WM.ref(wm, nw, :tank, i, "node")
    WM._initialize_con_dict(wm, :tank_nonlinear, nw=nw, is_array=true)
    WM.con(wm, nw, :tank_nonlinear)[i] = Array{JuMP.ConstraintRef}([])
    constraint_tank_nonlinear(wm, nw, i, node_index)
end


function constraint_strong_duality(wm::WM.AbstractWaterModel; nw::Int=WM.nw_id_default, kwargs...)
    WM._initialize_con_dict(wm, :strong_duality, nw=nw, is_array=true)
    WM.con(wm, nw, :strong_duality)[1] = Array{JuMP.ConstraintRef}([])
    constraint_strong_duality(wm, nw)
end
