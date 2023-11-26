import ArgParse
import Gurobi
import JSON
import JuMP

import WaterModelsAnnex
const WMA = WaterModelsAnnex
import WaterModels
const WM = WaterModels

# Prepare the Gurobi optimization environment and solver.
env = Gurobi.Env()
gurobi = JuMP.optimizer_with_attributes(
    () -> Gurobi.Optimizer(env),
    "TimeLimit" => 10.0,
    "OutputFlag" => 0,
    "MIPGap" => 0.0,
    "Threads" => 1
)

for model_type in [WM.PWLRDWaterModel, WM.LRDWaterModel, WMA.LRDXWaterModel]
    # Read in the original network data.
    network_path = "data/instances/Simple_FSD/Simple_FSD-24_Steps-Day_1.inp"
    network = WM.parse_file(network_path; skip_correct = true)
    modification_path = "data/instances/Simple_FSD/modifications.json"
    modifications = WM.parse_file(modification_path; skip_correct = true)
    WM._IM.update_data!(network, modifications)
    WM.correct_network_data!(network)

    # Set the flow partitioning function.
    part_func = x -> WM.set_flow_partitions_si!(x, 100.0, 1.0e-6)
    WM.set_flow_partitions_si!(network, 100.0, 1.0e-4)

    WM.set_bounds_from_time_series!(network)

    # Execute the OBBT routine.
    WM.solve_obbt!(
        network, WM.build_owf, gurobi; time_limit = 10.0,
        flow_partition_func = part_func, model_type = model_type,
        max_iter = 10, relax_integrality = true
    )

    WM.make_all_nondispatchable!(network)

    # Write the new network data to a JSON file.
    open("scripts/precompilation/tmp.json", "w") do f
        JSON.print(f, network, 4)
    end

    # Solve the design problem and return the result.
    network_mn = WM.make_multinetwork(network)
    result = WM.solve_mn_owf_switching(network_mn, model_type, gurobi; relax_integrality = true)
end

network_path = "data/instances/Simple_FSD/Simple_FSD-24_Steps-Day_1.inp"
network = WM.parse_file(network_path; skip_correct = true)
modification_path = "data/instances/Simple_FSD/modifications.json"
modifications = WM.parse_file(modification_path; skip_correct = true)
WM._IM.update_data!(network, modifications)
WM.correct_network_data!(network)

network_mn = WM.make_multinetwork(network)
network_single = WM.make_single_network(network_mn)
cuts = WMA.compute_pairwise_cuts_nws(network_single, 1.0, gurobi)

# Write the new network data to a JSON file.
open("scripts/precompilation/cuts-tmp.json", "w") do f
    JSON.print(f, cuts, 4)
end

cuts = WMA.load_pairwise_cuts("scripts/precompilation/cuts-tmp.json")
WM.set_flow_partitions_si!(network_mn, 1.0, 1.0e-4)
wm = WM.instantiate_model(network_mn, WMA.LRDXWaterModel, WM.build_mn_owf_switching)
WM._add_pairwise_cuts!(wm, cuts)
result = WM.optimize_model!(wm; optimizer = gurobi, relax_integrality = true)

WM.set_flow_partitions_si!(network_mn, 1.0, 1.0e-4)
wm = WM.instantiate_model(network_mn, WMA.PWLRDXWaterModel, WM.build_mn_owf_switching)
WM._add_pairwise_cuts!(wm, cuts)
result = WM.optimize_model!(wm; optimizer = gurobi, relax_integrality = true)

result_ub = WMA.solve_owf(
    network_mn, "scripts/precompilation/cuts-tmp.json",
    WM.build_mn_owf_switching, WMA.LRDXWaterModel, gurobi, true
)