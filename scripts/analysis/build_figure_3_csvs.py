import pandas as pd

def get_wall_time(log_path):
    wall_time = 0.0

    with open(log_path, "r") as log_file:
        data = log_file.readlines()
        for line in data:
            if 'Completed in ' in line:
                text = line.split('Completed in ')[1].split(' seconds')[0]
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
    for time_steps in ["12", "24", "48"]:
        df_wall = pd.DataFrame(columns = ['position', 'name', 'max_time'])
        df_parallel = pd.DataFrame(columns = ['position', 'name', 'max_time'])

        bt_oa_ss_max_wall_time = 0.0
        bt_pw_ss_max_wall_time = 0.0
        bt_pw_sq_max_wall_time = 0.0
        bt_oa_owf_max_wall_time = 0.0
        bt_pw_owf_max_wall_time = 0.0

        bt_oa_ss_max_parallel_time = 0.0
        bt_pw_ss_max_parallel_time = 0.0
        bt_pw_sq_max_parallel_time = 0.0
        bt_oa_owf_max_parallel_time = 0.0
        bt_pw_owf_max_parallel_time = 0.0

        for day in ["1", "2", "3", "4", "5"]:
            bt_oa_ss_log = "results/preprocessing/" + network + "-" + time_steps + "_Steps-Day_" + day + "-BT-OA-SS.log"
            bt_oa_ss_wall_time = get_wall_time(bt_oa_ss_log)
            bt_oa_ss_max_wall_time = max(bt_oa_ss_wall_time, bt_oa_ss_max_wall_time)
            bt_oa_ss_parallel_time = get_parallel_time(bt_oa_ss_log)
            bt_oa_ss_max_parallel_time = max(bt_oa_ss_parallel_time, bt_oa_ss_max_parallel_time)

            bt_pw_ss_log = "results/preprocessing/" + network + "-" + time_steps + "_Steps-Day_" + day + "-BT-PW-SS.log"
            bt_pw_ss_wall_time = get_wall_time(bt_pw_ss_log)
            bt_pw_ss_max_wall_time = max(bt_pw_ss_wall_time, bt_pw_ss_max_wall_time)
            bt_pw_ss_parallel_time = get_parallel_time(bt_pw_ss_log)
            bt_pw_ss_max_parallel_time = max(bt_pw_ss_parallel_time, bt_pw_ss_max_parallel_time)

            bt_pw_sq_log = "results/preprocessing/" + network + "-" + time_steps + "_Steps-Day_" + day + "-BT-PW-SQ.log"
            bt_pw_sq_wall_time = get_wall_time(bt_pw_sq_log)
            bt_pw_sq_max_wall_time = max(bt_pw_sq_wall_time, bt_pw_sq_max_wall_time)
            bt_pw_sq_parallel_time = get_parallel_time(bt_pw_sq_log)
            bt_pw_sq_max_parallel_time = max(bt_pw_sq_parallel_time, bt_pw_sq_max_parallel_time)

            bt_oa_owf_log = "results/preprocessing/" + network + "-" + time_steps + "_Steps-Day_" + day + "-BT-OA-OWF.log"
            bt_oa_owf_wall_time = get_wall_time(bt_oa_owf_log)
            bt_oa_owf_max_wall_time = max(bt_oa_owf_wall_time, bt_oa_owf_max_wall_time)
            bt_oa_owf_parallel_time = get_parallel_time(bt_oa_owf_log)
            bt_oa_owf_max_parallel_time = max(bt_oa_owf_parallel_time, bt_oa_owf_max_parallel_time)

            bt_pw_owf_log = "results/preprocessing/" + network + "-" + time_steps + "_Steps-Day_" + day + "-BT-PW-OWF.log"
            bt_pw_owf_wall_time = get_wall_time(bt_pw_owf_log)
            bt_pw_owf_max_wall_time = max(bt_pw_owf_wall_time, bt_pw_owf_max_wall_time)
            bt_pw_owf_parallel_time = get_parallel_time(bt_pw_owf_log)
            bt_pw_owf_max_parallel_time = max(bt_pw_owf_parallel_time, bt_pw_owf_max_parallel_time)

        df_wall = df_wall.append({'position': 1, 'name': 'bt_oa_ss', 'max_time': bt_oa_ss_max_wall_time}, ignore_index = True)
        df_wall = df_wall.append({'position': 2, 'name': 'bt_pw_ss', 'max_time': bt_pw_ss_max_wall_time}, ignore_index = True)
        df_wall = df_wall.append({'position': 3, 'name': 'bt_pw_sq', 'max_time': bt_pw_sq_max_wall_time}, ignore_index = True)
        df_wall = df_wall.append({'position': 4, 'name': 'bt_oa_owf', 'max_time': bt_oa_owf_max_wall_time}, ignore_index = True)
        df_wall = df_wall.append({'position': 5, 'name': 'bt_pw_owf', 'max_time': bt_pw_owf_max_wall_time}, ignore_index = True)
        df_wall.to_csv("results/postprocessed/" + network + "-" + time_steps + "_Steps-Bound_Tightening-Timing-Wall.csv", index = False)

        df_parallel = df_parallel.append({'position': 1, 'name': 'bt_oa_ss', 'max_time': bt_oa_ss_max_parallel_time}, ignore_index = True)
        df_parallel = df_parallel.append({'position': 2, 'name': 'bt_pw_ss', 'max_time': bt_pw_ss_max_parallel_time}, ignore_index = True)
        df_parallel = df_parallel.append({'position': 3, 'name': 'bt_pw_sq', 'max_time': bt_pw_sq_max_parallel_time}, ignore_index = True)
        df_parallel = df_parallel.append({'position': 4, 'name': 'bt_oa_owf', 'max_time': bt_oa_owf_max_parallel_time}, ignore_index = True)
        df_parallel = df_parallel.append({'position': 5, 'name': 'bt_pw_owf', 'max_time': bt_pw_owf_max_parallel_time}, ignore_index = True)
        df_parallel.to_csv("results/postprocessed/" + network + "-" + time_steps + "_Steps-Bound_Tightening-Timing-Parallel.csv", index = False)
