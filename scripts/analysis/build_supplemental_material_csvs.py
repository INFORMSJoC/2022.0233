import glob
import json
import math
import pandas as pd
import os


for filename in glob.glob('results/primal_bound_quality/*-48_Steps-*-MILP-OA-1m.json'):
    # Open the JSON file and store to a dictionary.
    with open(filename) as f:
        result = json.load(f)

    if result["primal_status"] != "FEASIBLE_POINT":
        continue

    # Convert network keys to a list of integers.
    nw_ids = result["solution"]["nw"].keys()
    nw_ids = [int(nw_id) for nw_id in nw_ids]
    nw_ids.sort()

    # Set up a dataframe to store pump flows. The columns should be the pump IDs.
    pump_flows = pd.DataFrame(columns=result["solution"]["nw"][str(nw_ids[0])]["pump"].keys())

    # Set up a dataframe to store sums of pipe flow directions.
    pipe_directions = pd.DataFrame(columns=["sum_of_directions"])

    # If the result has a "valve" key...
    if "valve" in result["solution"]["nw"][str(nw_ids[0])]:
        # Set up dataframes to store valve flows and statuses. The columns should be the valve IDs.
        valve_flows = pd.DataFrame(columns=result["solution"]["nw"][str(nw_ids[0])]["valve"].keys())
        valve_statuses = pd.DataFrame(columns=result["solution"]["nw"][str(nw_ids[0])]["valve"].keys())

    # Set up a dataframe to store the tank volumes. The columns should be the tank IDs.
    tank_volumes = pd.DataFrame(columns=result["solution"]["nw"][str(nw_ids[0])]["tank"].keys())

    for nw_id in nw_ids[:-1]:
        # Iterate over pump solutions.
        for pump_id, pump in result["solution"]["nw"][str(nw_id)]["pump"].items():
            # Append the flow to the dataframe.
            pump_flows.loc[nw_id, pump_id] = pump["q"]

        if "valve" in result["solution"]["nw"][str(nw_ids[0])]:
            # Iterate over valve solutions.
            for valve_id, valve in result["solution"]["nw"][str(nw_id)]["valve"].items():
                # Append flows and statuses to the dataframes.
                valve_flows.loc[nw_id, valve_id] = valve["q"]
                valve_statuses.loc[nw_id, valve_id] = valve["status"]

        sum_of_pipe_directions = 0

        for pipe_id, pipe in result["solution"]["nw"][str(nw_id)]["pipe"].items():
            if pipe["q"] >= 0.0:
                sum_of_pipe_directions += 1.0
        
        pipe_directions.loc[nw_id, "sum_of_directions"] = sum_of_pipe_directions

    for nw_id in nw_ids:
        # Iterate over tank solutions.
        for tank_id, tank in result["solution"]["nw"][str(nw_id)]["tank"].items():
            # Append the volume to the dataframe.
            tank_volumes.loc[nw_id, tank_id] = tank["V"]

    # Translate from the per-unit system to SI units.
    pump_flows *= result["solution"]["base_flow"]

    if "valve" in result["solution"]["nw"][str(nw_ids[0])]:
        valve_flows *= result["solution"]["base_flow"]

    tank_volumes *= math.pow(result["solution"]["base_length"], 3)

    # The total duration is 24 hours, so the time step is 24 hours divided by the number of time steps.
    time_step = 86400.0 / len(nw_ids[:-1])

    # Set the index to the time, which starts at zero and increases by the time step.
    pump_flows.index = [time_step * i for i in range(len(nw_ids[:-1]))]

    if "valve" in result["solution"]["nw"][str(nw_ids[0])]:
        valve_flows.index = [time_step * i for i in range(len(nw_ids[:-1]))]
        valve_statuses.index = [time_step * i for i in range(len(nw_ids[:-1]))]

    tank_volumes.index = [time_step * i for i in range(len(nw_ids))]

    # Get the basename of the file.
    pump_filename = os.path.basename(filename)

    # Remove the extension.
    pump_filename = os.path.splitext(pump_filename)[0]

    # Add the extension.
    pump_filename += '-Pump_Schedule.csv'

    # Create the path to the results directory.
    pump_filename = os.path.join('results/postprocessed/', pump_filename)

    # Write the dataframe to a CSV file.
    pump_flows.to_csv(pump_filename, index_label='time')

    # Do the same for the valve flow data.
    if "valve" in result["solution"]["nw"][str(nw_ids[0])]:
        valve_filename = os.path.basename(filename)
        valve_filename = os.path.splitext(valve_filename)[0]
        valve_filename += '-Valve_Schedule.csv'
        valve_filename = os.path.join('results/postprocessed/', valve_filename)
        valve_flows.to_csv(valve_filename, index_label='time')

        valve_filename = os.path.basename(filename)
        valve_filename = os.path.splitext(valve_filename)[0]
        valve_filename += '-Valve_Status_Schedule.csv'
        valve_filename = os.path.join('results/postprocessed/', valve_filename)
        valve_statuses.to_csv(valve_filename, index_label='time')

    # Do the same for the tank volume data.
    tank_filename = os.path.basename(filename)
    tank_filename = os.path.splitext(tank_filename)[0]
    tank_filename += '-Tank_Schedule.csv'
    tank_filename = os.path.join('results/postprocessed', tank_filename)
    tank_volumes.to_csv(tank_filename, index_label='time')

    # Do the same for pipe direction data.
    pipe_directions.index = [time_step * i for i in range(len(nw_ids[:-1]))]
    pipe_direction_filename = os.path.basename(filename)
    pipe_direction_filename = os.path.splitext(pipe_direction_filename)[0]
    pipe_direction_filename += '-Pipe_Directionality_Schedule.csv'
    pipe_direction_filename = os.path.join('results/postprocessed/', pipe_direction_filename)
    pipe_directions.to_csv(pipe_direction_filename, index_label='time')
