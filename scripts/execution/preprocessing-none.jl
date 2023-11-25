import ArgParse
import JSON
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
        "--modification_path"
        help = "path to network modifications file"
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

    network = WM.parse_file(args["input_path"]; skip_correct = true)
    modifications = WM.parse_file(args["modification_path"]; skip_correct = true)

    WM._IM.update_data!(network, modifications)
    WM.correct_network_data!(network)
    WM.set_flow_partitions_si!(network, 1.0, 1.0e-4)

    open(args["output_path"], "w") do f
        JSON.print(f, network, 4)
    end
end


main()
