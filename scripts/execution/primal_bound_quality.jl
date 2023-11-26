import ArgParse
import Gurobi
import JSON
import JuMP

using WaterModelsAnnex
const WM = WaterModelsAnnex.WM


function parse_commandline()
    s = ArgParse.ArgParseSettings()

    ArgParse.@add_arg_table s begin
        "--input_path"
        help = "path to input file"
        arg_type = String
        required = true
        "--cuts_path"
        help = "path to file containing cuts"
        arg_type = String
        required = true
        "--output_path"
        help = "path to output file"
        arg_type = String
        required = true
        "--time_limit"
        help = "time limit in seconds"
        arg_type = Float64
        required = true
        "--error_tolerance"
        help = "error tolerance in meters"
        arg_type = Float64
        required = true
        "--formulation"
        help = "problem formulation"
        arg_type = String
        required = true
        "--relax_direction"
        help = "whether or not to relax direction variables"
        arg_type = Bool
        required = true
    end

    return ArgParse.parse_args(s)
end


function main()
    args = parse_commandline()

    env = Gurobi.Env()
    gurobi = JuMP.optimizer_with_attributes(
        () -> Gurobi.Optimizer(env),
        "TimeLimit" => args["time_limit"],
        "MIPGap" => 0.0,
        "LazyConstraints" => 1,
        "PreCrush" => 1,
        "Presolve" => 2,
        "Threads" => 64,
    )

    network_mn = WM.parse_file(args["input_path"]; skip_correct = true)
    WM.set_flow_partitions_si!(network_mn, args["error_tolerance"], 1.0e-4)

    if args["formulation"] == "LRDXWaterModel"
        formulation = LRDXWaterModel
    elseif args["formulation"] == "PWLRDXWaterModel"
        formulation = PWLRDXWaterModel
    end

    result = solve_owf(
        network_mn,
        args["cuts_path"],
        WM.build_mn_owf_switching,
        formulation,
        gurobi,
        args["relax_direction"],
    )

    open(args["output_path"], "w") do f
        JSON.print(f, result, 4)
    end
end


main()
