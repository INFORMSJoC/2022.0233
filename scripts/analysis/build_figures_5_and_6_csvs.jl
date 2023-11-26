import ArgParse
import CSV
import DataFrames
import JSON


function get_true_upper_bound(file_path::String)
    if file_path !== nothing && isfile(file_path)
        data = JSON.parsefile(file_path)

        if data["true_upper_bound"] !== nothing
            return data["true_upper_bound"]
        else
            return Inf
        end
    else
        return Inf
    end
end


function main(parsed_args)
    # Gather all arguments.
    directory = parsed_args["directory"]
    network = parsed_args["network"]
    time_steps = parsed_args["time_steps"]
    results_directory = parsed_args["results_directory"]

    # Filter the correct file paths.
    all_file_paths = readdir(directory; join = true)
    file_paths_steps = filter(x -> occursin("-$(time_steps)_Steps", x), all_file_paths)
    file_paths = sort(filter(x -> occursin(network, x), file_paths_steps))

    # Initialize a DataFrame to store data.
    df = DataFrames.DataFrame(
        day = Int[], milp_oa_1m = Float64[], milp_oa_5m = Float64[], milp_oa_25m = Float64[],
        milp_pw_1m = Float64[], milp_pw_5m = Float64[], milp_pw_25m = Float64[])

    for day in ["1", "2", "3", "4", "5"]
        # Filter file paths for a particular price profile (day).
        file_paths_day = filter(x -> occursin("-Day_$(day)-", x), file_paths)

        milp_oa_1m_path_id = findfirst(x -> endswith(x, "MILP-OA-1m.json"), file_paths_day)

        if milp_oa_1m_path_id !== nothing
            milp_oa_1m_path = file_paths_day[milp_oa_1m_path_id]
            ub_milp_oa_1m = get_true_upper_bound(milp_oa_1m_path)
        else
            ub_milp_oa_1m = Inf
        end

        milp_oa_5m_path_id = findfirst(x -> endswith(x, "MILP-OA-5m.json"), file_paths_day)

        if milp_oa_5m_path_id !== nothing
            milp_oa_5m_path = file_paths_day[milp_oa_5m_path_id]
            ub_milp_oa_5m = get_true_upper_bound(milp_oa_5m_path)
        else
            ub_milp_oa_5m = Inf
        end

        milp_oa_25m_path_id = findfirst(x -> endswith(x, "MILP-OA-25m.json"), file_paths_day)

        if milp_oa_25m_path_id !== nothing
            milp_oa_25m_path = file_paths_day[milp_oa_25m_path_id]
            ub_milp_oa_25m = get_true_upper_bound(milp_oa_25m_path)
        else
            ub_milp_oa_25m = Inf
        end

        milp_pw_1m_path_id = findfirst(x -> endswith(x, "MILP-PW-1m.json"), file_paths_day)

        if milp_pw_1m_path_id !== nothing
            milp_pw_1m_path = file_paths_day[milp_pw_1m_path_id]
            ub_milp_pw_1m = get_true_upper_bound(milp_pw_1m_path)
        else
            ub_milp_pw_1m = Inf
        end

        milp_pw_5m_path_id = findfirst(x -> endswith(x, "MILP-PW-5m.json"), file_paths_day)

        if milp_pw_5m_path_id !== nothing
            milp_pw_5m_path = file_paths_day[milp_pw_5m_path_id]
            ub_milp_pw_5m = get_true_upper_bound(milp_pw_5m_path)
        else
            ub_milp_pw_5m = Inf
        end

        milp_pw_25m_path_id = findfirst(x -> endswith(x, "MILP-PW-25m.json"), file_paths_day)

        if milp_pw_25m_path_id !== nothing
            milp_pw_25m_path = file_paths_day[milp_pw_25m_path_id]
            ub_milp_pw_25m = get_true_upper_bound(milp_pw_25m_path)
        else
            ub_milp_pw_25m = Inf
        end

        ub_min = minimum([ub_milp_oa_1m, ub_milp_oa_5m, ub_milp_oa_25m, ub_milp_pw_1m, ub_milp_pw_5m, ub_milp_pw_25m])

        push!(df, (day = parse(Int, day),
            milp_oa_1m = 100.0 * (ub_milp_oa_1m - ub_min) / ub_min,
            milp_oa_5m = 100.0 * (ub_milp_oa_5m - ub_min) / ub_min,
            milp_oa_25m = 100.0 * (ub_milp_oa_25m - ub_min) / ub_min,
            milp_pw_1m = 100.0 * (ub_milp_pw_1m - ub_min) / ub_min,
            milp_pw_5m = 100.0 * (ub_milp_pw_5m - ub_min) / ub_min,
            milp_pw_25m = 100.0 * (ub_milp_pw_25m - ub_min) / ub_min))
    end

    output_path = "$(results_directory)/$(network)-$(time_steps)_Steps-Primal_Bound_Quality.csv"
    #println("Writing: " * output_path)
    CSV.write(output_path, df)
end


function parse_commandline()
    s = ArgParse.ArgParseSettings()

    ArgParse.@add_arg_table! s begin
        "--directory", "-d"
            arg_type = String
            required = true
            help = "Path to the results directory."

        "--network", "-n"
            arg_type = String
            required = true
            help = "Name of the network"

        "--time_steps", "-t"
            arg_type = String
            required = true
            help = "Number of time steps used by the instances"

        "--results_directory", "-r"
            arg_type = String
            required = true
            help = "Path to the analysis results directory."
    end

    return ArgParse.parse_args(s)
end


if isinteractive() == false
    #main(parse_commandline())

    arguments = Dict(
        "directory" => "results/primal_bound_quality",
        "results_directory" => "results/postprocessed"
    )

    for network in ["Simple_FSD", "ATM", "Poormond"]
        for time_step in ["12", "24", "48"]
            arguments["network"] = network
            arguments["time_steps"] = time_step
            main(arguments)
        end
    end
end
