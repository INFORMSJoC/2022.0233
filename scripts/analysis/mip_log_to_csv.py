import argparse
import numpy as np
import os
import pandas as pd
import re
from io import StringIO


def main(log_path, output_path):
    columns = ['num_nodes', 'time_elapsed', 'lower_bound', 'upper_bound']
    result_df = pd.DataFrame(columns=columns)
    best_upper_bound = np.inf

    with open(log_path, 'r') as f:
        input_txt = f.read()
        header = ' Expl Unexpl |  Obj  Depth IntInf | Incumbent    BestBd   Gap | It/Node Time'

        if header in input_txt:
            input_txt = input_txt.split(header)[1]
            input_txt = input_txt.lstrip()

            if 'Explored' in input_txt:
                num_nodes = int(input_txt.split('Explored')[1].split('nodes')[0].strip())
                time_elapsed = float(input_txt.split('iterations) in')[1].split('seconds')[0].strip())
                lower_bound = float(input_txt.split('best bound')[1].split(',')[0].strip())
                entry = {'num_nodes': num_nodes, 'time_elapsed': time_elapsed,
                         'lower_bound': lower_bound, 'upper_bound': best_upper_bound}
                result_df = result_df.append(entry, ignore_index = True)

            if '\n\n' in input_txt:
                input_txt = input_txt.split('\n\n')[0]

            for line in input_txt.split('\n'):
                if '┌' in line or '│' in line or '└' in line:
                    continue

                # This is used to discern the "true" upper bound found via simulation of controls.
                if 'Found feasible solution with cost ' in line:
                    upper_bound = float(line.split('Found feasible solution with cost ')[1][:-1])
                    best_upper_bound = min(best_upper_bound, upper_bound)
                    continue

                if line == '':
                    continue

                line = re.sub("[^0-9 -] ", "", line)
                line = line.strip().replace('H', '')
                line = line.strip().replace('*', '')
                line = ' '.join(line.split())
                num_nodes = int(line.split(' ')[0])
                time_elapsed = float(line.split(' ')[-1].replace('s', ''))
                lower_bound = float(line.split(' ')[-4])

                entry = {'num_nodes': num_nodes, 'time_elapsed': time_elapsed,
                         'lower_bound': lower_bound, 'upper_bound': best_upper_bound}
                result_df = result_df.append(entry, ignore_index = True)

            result_df = result_df.sort_values(by=['time_elapsed', 'lower_bound'], ascending=True)
            result_df.loc[result_df.index[-1], "upper_bound"] = best_upper_bound
            result_df = result_df.drop_duplicates(subset='num_nodes', keep='last')
            result_df.to_csv(output_path, index=False)


if __name__ == "__main__":
    description = 'Analyze a Gurobi log.'
    parser = argparse.ArgumentParser(description = description)
    parser.add_argument('log_path', type = str, metavar = 'logPath', help = 'path to log')
    parser.add_argument('output_path', type = str, metavar = 'outputPath', help = 'path to output CSV')
    args = parser.parse_args()
    main(args.log_path, args.output_path)
