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
        df = DataFrames.DataFrame(day = Int64[], dual_cuts = Float64[], obcg = Float64[])

        for day in ["1", "2", "3", "4", "5"]
            formulation_1_path = "results/dual_bound_improvement/$(network_name)-$(time_steps)_Steps-Day_$(day)-BT-PW-OWF.json"
            formulation_2_path = "results/dual_bound_improvement/$(network_name)-$(time_steps)_Steps-Day_$(day)-DUAL_CUTS.json"
            formulation_3_path = "results/dual_bound_improvement/$(network_name)-$(time_steps)_Steps-Day_$(day)-OBCG.json"
            paths = [formulation_1_path, formulation_2_path, formulation_3_path]

            if all(isfile.(paths))
                formulation_1_result = JSON.parsefile(formulation_1_path)
                improvement_2 = get_improvement(formulation_1_result, JSON.parsefile(formulation_2_path))
                improvement_3 = get_improvement(formulation_1_result, JSON.parsefile(formulation_3_path))
                push!(df, (parse(Int, day), improvement_2, improvement_3))
            end
        end

        CSV.write("results/postprocessed/$(network_name)-$(time_steps)_Steps-Dual_Bound-Cut-Improvements.csv", df)
    end
end
