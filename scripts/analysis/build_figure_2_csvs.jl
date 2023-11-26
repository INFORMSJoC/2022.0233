import CSV
import DataFrames
import JSON
import Statistics

function get_improvement(formulation_1_result, formulation_2_result)
    if formulation_1_result["objective"] !== nothing && formulation_2_result["objective"] !== nothing
        formulation_1_lb = formulation_1_result["objective"]
        formulation_2_lb = formulation_2_result["objective"]
        return 100.0 * (formulation_2_lb - formulation_1_lb) / formulation_1_lb
    else
        return 0.0
    end
end

for network_name in ["Simple_FSD", "ATM", "Poormond"]
    for time_steps in ["12", "24", "48"]
        df = DataFrames.DataFrame(day = Int64[], bt_oa_ss = Float64[], bt_pw_ss = Float64[],
            bt_pw_sq = Float64[], bt_oa_owf = Float64[], bt_pw_owf = Float64[])

        for day in ["1", "2", "3", "4", "5"]
            formulation_1_path = "results/dual_bound_improvement/$(network_name)-$(time_steps)_Steps-Day_$(day)-NONE.json"
            formulation_2_path = "results/dual_bound_improvement/$(network_name)-$(time_steps)_Steps-Day_$(day)-BT-OA-SS.json"
            formulation_3_path = "results/dual_bound_improvement/$(network_name)-$(time_steps)_Steps-Day_$(day)-BT-PW-SS.json"
            formulation_4_path = "results/dual_bound_improvement/$(network_name)-$(time_steps)_Steps-Day_$(day)-BT-PW-SQ.json"
            formulation_5_path = "results/dual_bound_improvement/$(network_name)-$(time_steps)_Steps-Day_$(day)-BT-OA-OWF.json"
            formulation_6_path = "results/dual_bound_improvement/$(network_name)-$(time_steps)_Steps-Day_$(day)-BT-PW-OWF.json"

            paths = [formulation_1_path, formulation_2_path, formulation_3_path,
                     formulation_4_path, formulation_5_path, formulation_6_path]

            if all(isfile.(paths))
                formulation_1_result = JSON.parsefile(formulation_1_path)
                improvement_2 = get_improvement(formulation_1_result, JSON.parsefile(formulation_2_path))
                improvement_3 = get_improvement(formulation_1_result, JSON.parsefile(formulation_3_path))
                improvement_4 = get_improvement(formulation_1_result, JSON.parsefile(formulation_4_path))
                improvement_5 = get_improvement(formulation_1_result, JSON.parsefile(formulation_5_path))
                improvement_6 = get_improvement(formulation_1_result, JSON.parsefile(formulation_6_path))
                push!(df, (parse(Int, day), improvement_2, improvement_3, 
                    improvement_4, improvement_5, improvement_6))
            end
        end

        CSV.write("results/postprocessed/$(network_name)-$(time_steps)_Steps-Dual_Bound-Bound_Tightening-Improvements.csv", df)
    end
end
