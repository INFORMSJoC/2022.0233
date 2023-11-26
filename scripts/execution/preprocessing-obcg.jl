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

    network_mn = WM.parse_file(args["input_path"], skip_correct = true)
    network = WM.make_single_network(network_mn)

    cuts = WMA.compute_pairwise_cuts_nws(network, 1.0, gurobi)

    open(args["output_path"], "w") do f
        JSON.print(f, cuts, 4)
    end
end


main()
