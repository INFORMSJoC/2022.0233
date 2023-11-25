import JSON

for network_name in ["Simple_FSD", "ATM", "Poormond"]
    println(network_name * " Rows")
    for date in ["1", "2", "3", "4", "5"]
        line = ""

        for time_steps in ["12", "24", "48"]
            path = "results/primal_bound_quality/$(network_name)-$(time_steps)_Steps-Day_$(date)-MILP-OA-1m.json"

            if !isfile(path)
                line *= "- & " * "- & " * "- & "
            else
                result = JSON.parsefile(path)

                ub = result["true_upper_bound"]
                lb = result["objective_lb"]

                if ub !== nothing
                    gap = round((ub - lb) / ub * 100.0; digits = 1)
                    ub_round = round(ub, digits = 1)
                else
                    gap = "-"
                    ub_round = "-"
                end

                solve_time_str = string(round(result["solve_time"], digits = 1)) * " s"

                if result["termination_status"] == "TIME_LIMIT"
                    solve_time_str = "Lim."
                    lb_round = round(result["objective_lb"], digits = 1)
                elseif result["termination_status"] != "INFEASIBLE"
                    lb_round = round(result["objective_lb"], digits = 1)
                else
                    solve_time_str = "-"
                    lb_round = "-"
                end

                gap_str = gap == "-" ? "-" : string(gap) * "\\%"

                line *= string(ub_round) * " & " * string(lb_round) * " & " *
                    gap_str * " & " * solve_time_str * " & "
            end
        end

        println("& \\multicolumn{1}{|c|}{$(parse(Int, date))} & " * line[1:end-2] * "\\\\")
    end
end
