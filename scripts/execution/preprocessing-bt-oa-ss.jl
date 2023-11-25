import ArgParse
import Gurobi
import JSON
import JuMP
import WaterModelsAnnex

const WMA = WaterModelsAnnex
const WM = WaterModelsAnnex.WM


function parse_commandline()
    s = ArgParse.ArgParseSettings()

    ArgParse.@add_arg_table s begin
        "--input_path"
        help = "path to input file"
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
    end

    return ArgParse.parse_args(s)
end


function main()
    args = parse_commandline()

    env = Gurobi.Env()
    gurobi = JuMP.optimizer_with_attributes(
        () -> Gurobi.Optimizer(env),
        "TimeLimit" => 60.0,
        "OutputFlag" => 0,
        "MIPGap" => 0.0,
        "Threads" => 1,
    )

    network = WM.parse_file(args["input_path"], skip_correct = true)
    WM.set_bounds_from_time_series!(network)

    fp_func = x -> WM.set_flow_partitions_si!(x, 1.0, 1.0e-4)
    WM.solve_obbt!(
        network,
        WM.build_owf,
        gurobi;
        time_limit = args["time_limit"],
        model_type = WM.LRDWaterModel,
        relax_integrality = true,
        max_iter = 25,
        flow_partition_func = fp_func,
    )

    WM.make_all_nondispatchable!(network)

    open(args["output_path"], "w") do f
        JSON.print(f, network, 4)
    end
end


main()
