import pandas as pd

def get_wall_time(log_path):
    wall_time = 0.0

    with open(log_path, "r") as log_file:
        data = log_file.readlines()
        for line in data:
            if 'Pairwise cut preprocessing completed in ' in line:
                text = line.split('Pairwise cut preprocessing completed in ')[1].split(' seconds')[0]
                wall_time += float(text)

    return wall_time

def get_parallel_time(log_path):
    parallel_time = 0.0

    with open(log_path, "r") as log_file:
        data = log_file.readlines()

        for line in data:
            if 'ideal parallel time: ' in line:
                text = line.split('ideal parallel time: ')[1].split(' seconds')[0]
                parallel_time += float(text)

    return parallel_time

for network in ["Simple_FSD", "ATM", "Poormond"]:
    line = ""

    for time_steps in ["12", "24", "48"]:
        obcg_max_wall_time = 0.0
        obcg_max_parallel_time = 0.0

        for day in ["1", "2", "3", "4", "5"]:
            obcg_log = "results/preprocessing/" + network + "-" + time_steps + "_Steps-Day_" + day + "-OBCG.log"
            obcg_wall_time = get_wall_time(obcg_log)
            obcg_max_wall_time = max(obcg_wall_time, obcg_max_wall_time)
            obcg_parallel_time = get_parallel_time(obcg_log)
            obcg_max_parallel_time = max(obcg_parallel_time, obcg_max_parallel_time)

        line += "$" + str(round(obcg_max_wall_time, 1)) + "$ s & $" + str(round(obcg_max_parallel_time, 1)) + "$ s & "

    print(line[:-2])
