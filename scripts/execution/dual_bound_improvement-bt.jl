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
        "TimeLimit" => args["time_limit"],
        "NumericFocus" => 3,
        "FeasibilityTol" => 1.0e-9,
        "OptimalityTol" => 1.0e-9,
    )

    network = WM.parse_file(args["input_path"]; skip_correct = true)

    if WM.ismultinetwork(network)
        network_mn = deepcopy(network)
    else
        network_mn = WM.make_multinetwork(network)
    end

    WM.set_flow_partitions_si!(network_mn, 1.0, 1.0e-4)
    wm = WM.instantiate_model(network_mn, WM.LRDWaterModel, WM.build_mn_owf_switching)
    result = WM.optimize_model!(wm; optimizer = gurobi, relax_integrality = true)

    open(args["output_path"], "w") do f
        JSON.print(f, result, 4)
    end
end


main()
