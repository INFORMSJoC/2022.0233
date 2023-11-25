import JSON


function get_entries(path)
    if !isfile(path)
        return "-", "-"
    else
        result = JSON.parsefile(path)
        ub = result["true_upper_bound"]

        if ub !== nothing
            ub_str = string(round(ub; digits = 1))
        else
            ub_str = "-"
        end

        lb = result["objective_lb"]
        lb_str = string(round(lb; digits = 1))

        return "\$" * lb_str * "\$", "\$" * ub_str * "\$"
    end
end


for network_name in ["Poormond"]
    for date in ["1", "2", "3", "4", "5"]
        line = ""

        for time_steps in ["48"]
            path_none = "results/improvement_evaluation/$(network_name)-$(time_steps)_Steps-Day_$(date)-NONE.json"
            lb_none, ub_none = get_entries(path_none)

            path_bt_oa_ss = "results/improvement_evaluation/$(network_name)-$(time_steps)_Steps-Day_$(date)-BT-OA-SS.json"
            lb_oa_ss, ub_oa_ss = get_entries(path_bt_oa_ss)

            path_bt_pw_ss = "results/improvement_evaluation/$(network_name)-$(time_steps)_Steps-Day_$(date)-BT-PW-SS.json"
            lb_pw_ss, ub_pw_ss = get_entries(path_bt_pw_ss)

            path_bt_pw_sq = "results/improvement_evaluation/$(network_name)-$(time_steps)_Steps-Day_$(date)-BT-PW-SQ.json"
            lb_pw_sq, ub_pw_sq = get_entries(path_bt_pw_sq)

            path_bt_oa_owf = "results/improvement_evaluation/$(network_name)-$(time_steps)_Steps-Day_$(date)-BT-OA-OWF.json"
            lb_oa_owf, ub_oa_owf = get_entries(path_bt_oa_owf)

            path_bt_pw_owf = "results/improvement_evaluation/$(network_name)-$(time_steps)_Steps-Day_$(date)-BT-PW-OWF.json"
            lb_pw_owf, ub_pw_owf = get_entries(path_bt_pw_owf)

            path_dual_cuts = "results/improvement_evaluation/$(network_name)-$(time_steps)_Steps-Day_$(date)-DUAL_CUTS.json"
            lb_dual_cuts, ub_dual_cuts = get_entries(path_dual_cuts)

            path_obcg = "results/improvement_evaluation/$(network_name)-$(time_steps)_Steps-Day_$(date)-OBCG.json"
            lb_obcg, ub_obcg = get_entries(path_obcg)

            line *= lb_none * " & " * ub_none * " & "
            line *= lb_oa_ss * " & " * ub_oa_ss * " & "
            line *= lb_pw_ss * " & " * ub_pw_ss * " & "
            line *= lb_pw_sq * " & " * ub_pw_sq * " & "
            line *= lb_oa_owf * " & " * ub_oa_owf * " & "
            line *= lb_pw_owf * " & " * ub_pw_owf * " & "
            line *= lb_dual_cuts * " & " * ub_dual_cuts * " & "
            line *= lb_obcg * " & " * ub_obcg

        end

        println("\\multicolumn{1}{|c|}{$(parse(Int, date))} & " * line * " \\\\")
    end
end
