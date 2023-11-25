[![INFORMS Journal on Computing Logo](https://INFORMSJoC.github.io/logos/INFORMS_Journal_on_Computing_Header.jpg)](https://pubsonline.informs.org/journal/ijoc)

# Polyhedral Relaxations for Optimal Pump Scheduling of Potable Water Distribution Networks
This archive is distributed in association with the [INFORMS Journal on Computing](https://pubsonline.informs.org/journal/ijoc) under a BSD license as part of the Multi-Infrastructure Control and Optimization Toolkit (MICOT) project at Los Alamos National Laboratory, LA-CC-13-108.

The software and data in this repository comprise a snapshot of similar artifacts used in the production of the article [_Polyhedral Relaxations for Optimal Pump Scheduling of Potable Water Distribution Networks_](https://example.com) by B. Tasseff, R. Bent, C. Coffrin, C. Barrows, D. Sigler, J. Stickel, A. S. Zamzam, Y. Liu, and P. Van Hentenryck.
This snapshot is based on the specific inputs and software found in the `data` and `src` directories, respectively.
Snapshots of unprocessed experimental outputs are provided in the subdirectories of `results`.
Finally, various precompilation, execution, batch cluster submission, and analytical postprocessing utilities are provided in the `scripts` directory.

## Notes on Software Versioning
Julia 1.6.3 and Gurobi 9.1.2 were used in the production of all results.
The `Manifest.toml` and `Project.toml` files in the `src` directory define dependent Julia packages and the versions used in the production of results.
The `requirements.txt` file in the `scripts` directory defines package requirements for running Python-based analytical postprocessing utilities.

The software projects in the `src` directory diverged from the official releases of [WaterModels](https://github.com/lanl-ansi/WaterModels.jl) and [WaterModelsAnnex](https://github.com/lanl-ansi/WaterModelsAnnex.jl) during the production of this work. 
Please visit the associated links if you would like to evaluate stable and regularly-maintained versions of these packages.
However, be mindful that some of the novel features evaluated in this article (e.g., specialized bound tightening techniques and duality-based formulations) may not be available in current official releases.
Please post an [issue](https://github.com/lanl-ansi/WaterModels.jl/issues) to the WaterModels project if there is interest in having these features supported in a future release.

## Citing
To cite the contents of this repository, please cite both the article and this repository using their respective digital object identifiers (DOIs), i.e., [example](https://doi.org/example) and [example.cd](https://doi.org/example.cd).
Below is a BibTeX entry that may be used for citing this respoitory:
```
@article{tasseff+:ijoc2023:repository,
  author =        {Byron Tasseff and Russell Bent and Carleton Coffrin and Clayton Barrows and Devon Sigler and Jonathan Stickel and Ahmed S. Zamzam and Yang Liu and Pascal Van Hentenryck},
  publisher =     {INFORMS Journal on Computing},
  title =         {Polyhedral Relaxations for Optimal Pump Scheduling of Potable Water Distribution Networks},
  year =          {2023},
  doi =           {example.cd},
  url =           {https://github.com/INFORMSJoC/example}
}
```

## Setup
### Installing Dependencies
First, download and install [Julia 1.6.3](https://julialang.org/downloads/oldreleases/) and [Gurobi 9.1.2](https://www.gurobi.com/downloads/gurobi-software/#GO912).
After installation, ensure your Gurobi environment variables are properly set.
For example, in your `~/.bash_profile`, set
```bash
export GUROBI_HOME="/path/to/gurobi912/linux64"
export GRB_LICENSE_FILE="/path/to/gurobi.lic"
export LD_LIBRARY_PATH="${GUROBI_HOME}/lib:${LD_LIBRARY_PATH}"
export PATH="${GUROBI_HOME}/bin:${PATH}"
```
Execution of a command like `gurobi_cl --tokens` should succeed.

To use the `src` directory as the Julia project environment, execute
```bash
julia --project=src
```
Then, instantiate the project using
```julia
] instantiate
```
Install the provided development versions of WaterModels and WaterModelsAnnex via
```julia
using Pkg
Pkg.develop(PackageSpec(path="src/WaterModels.jl"))
Pkg.develop(PackageSpec(path="src/WaterModelsAnnex.jl"))
```

### Precompilation (Optional)
When running experimental scripts from the command line, it may take a substantial amount of time for Julia to complete compilation steps prior to execution.
Precompilation can help expedite execution.
To generate a precompiled system image to use during script execution, the following may be run:
```bash
julia --project=src scripts/precompilation/precompile.jl
```
The resultant system image will be written to `scripts/precompilation/WaterModels.so`.
After the system image has been built, for convenience, you can set the following environment variable:
```bash
export SYSIMAGE_PATH="scripts/precompilation/WaterModels.so"
```

## Executing Experiments
To execute experiments outlined in the "Computational Experiments" section of the article and beyond, a number of convenience scripts are provided, which are stored the `scripts/execution` directory.
Below, we provide an example of executing these scripts in the order of experiments performed throughout the article.
For simplicity and brevity, we focus on only one smaller instance, `Simple_FSD-24_Steps-Day_1`.
Note that the examples below will overwrite output for this instance in the `results` directory.
If you would like to avoid this, store results in a different `--output_path` for each experiment.

### Preprocessing
The following exemplify experiments related to what we choose to call "preprocessing" an OWF instance.
These experiments execute optimization-based bound tightening and cut generation techniques intended to strengthen a model formulation.
First, execute the script used to translate the base EPANET input file, along with instance-specific modifications, to a new JSON file describing the network, i.e.,
```bash
julia -J${SYSIMAGE_PATH} --project=src scripts/execution/preprocessing-none.jl \
      --input_path data/instances/Simple_FSD/Simple_FSD-24_Steps-Day_1.inp \
      --modification_path data/instances/Simple_FSD/modifications.json \
      --output_path results/preprocessing/Simple_FSD-24_Steps-Day_1-NONE.json
```

Next, execute the first variant of optimization-based bound tightening:
```bash
julia -J${SYSIMAGE_PATH} --threads=4 --project=src scripts/execution/preprocessing-bt-oa-ss.jl \
      --input_path results/preprocessing/Simple_FSD-24_Steps-Day_1-NONE.json \
      --output_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-OA-SS.json \
      --time_limit 3600.0
```
Note the use of the `--threads` option, which allows us to solve subproblems in parallel.
In this example, we have assumed an option of `--threads=4`, although in the article, we used `--threads=128`.

Execute the remaining variants of optimization-based bound tightening in sequence:
```bash
julia -J${SYSIMAGE_PATH} --threads=4 --project=src scripts/execution/preprocessing-bt-pw-ss.jl \
      --input_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-OA-SS.json \
      --output_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-PW-SS.json \
      --time_limit 3600.0

julia -J${SYSIMAGE_PATH} --threads=4 --project=src scripts/execution/preprocessing-bt-pw-sq.jl \
      --input_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-PW-SS.json \
      --output_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-PW-SQ.json \
      --time_limit 3600.0

julia -J${SYSIMAGE_PATH} --threads=4 --project=src scripts/execution/preprocessing-bt-oa-owf.jl \
      --input_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-PW-SQ.json \
      --output_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-OA-OWF.json \
      --time_limit 3600.0

julia -J${SYSIMAGE_PATH} --threads=4 --project=src scripts/execution/preprocessing-bt-pw-owf.jl \
      --input_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-OA-OWF.json \
      --output_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-PW-OWF.json \
      --time_limit 3600.0
```

Next, execute the script to compute optimization-based cuts:
```bash
julia -J${SYSIMAGE_PATH} --threads=4 --project=src scripts/execution/preprocessing-obcg.jl \
      --input_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-PW-OWF.json \
      --output_path results/preprocessing/Simple_FSD-24_Steps-Day_1-OBCG.json
```

The JSON files suffixed with `-BT-*.json` comprise network data with tightened bounds, while the file suffixed with `-OBCG.json` is a JSON representation of optimization-based cutting planes applicable to the instance.

### Dual Bound Improvement
Next, we execute relaxation-based dual bounding experiments using the strengthening procedures described in [the preprocessing section above](#Preprocessing), as well as the duality-based cutting planes introduced in the article.
To solve continuous relaxations associated with each bound-tightened input, execute
```bash
julia -J${SYSIMAGE_PATH} --project=src scripts/execution/dual_bound_improvement-bt.jl \
      --input_path results/preprocessing/Simple_FSD-24_Steps-Day_1-NONE.json \
      --output_path results/dual_bound_improvement/Simple_FSD-24_Steps-Day_1-NONE.json \
      --time_limit 3600.0

julia -J${SYSIMAGE_PATH} --project=src scripts/execution/dual_bound_improvement-bt.jl \
      --input_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-OA-SS.json \
      --output_path results/dual_bound_improvement/Simple_FSD-24_Steps-Day_1-BT-OA-SS.json \
      --time_limit 3600.0

julia -J${SYSIMAGE_PATH} --project=src scripts/execution/dual_bound_improvement-bt.jl \
      --input_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-PW-SS.json \
      --output_path results/dual_bound_improvement/Simple_FSD-24_Steps-Day_1-BT-PW-SS.json \
      --time_limit 3600.0

julia -J${SYSIMAGE_PATH} --project=src scripts/execution/dual_bound_improvement-bt.jl \
      --input_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-PW-SQ.json \
      --output_path results/dual_bound_improvement/Simple_FSD-24_Steps-Day_1-BT-PW-SQ.json \
      --time_limit 3600.0

julia -J${SYSIMAGE_PATH} --project=src scripts/execution/dual_bound_improvement-bt.jl \
      --input_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-OA-OWF.json \
      --output_path results/dual_bound_improvement/Simple_FSD-24_Steps-Day_1-BT-OA-OWF.json \
      --time_limit 3600.0

julia -J${SYSIMAGE_PATH} --project=src scripts/execution/dual_bound_improvement-bt.jl \
      --input_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-PW-OWF.json \
      --output_path results/dual_bound_improvement/Simple_FSD-24_Steps-Day_1-BT-PW-OWF.json \
      --time_limit 3600.0
```
Then, to evaluate the effects of duality-based cuts, execute
```bash
julia -J${SYSIMAGE_PATH} --project=src scripts/execution/dual_bound_improvement-dual_cuts.jl \
      --input_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-PW-OWF.json \
      --output_path results/dual_bound_improvement/Simple_FSD-24_Steps-Day_1-DUAL_CUTS.json \
      --time_limit 3600.0
```
Finally, to evaluate the effects of optimization-based cuts, execute:
```bash
julia -J${SYSIMAGE_PATH} --project=src scripts/execution/dual_bound_improvement-obcg.jl \
      --input_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-PW-OWF.json \
      --cuts_path results/preprocessing/Simple_FSD-24_Steps-Day_1-OBCG.json \
      --output_path results/dual_bound_improvement/Simple_FSD-24_Steps-Day_1-OBCG.json \
      --time_limit 3600.0
```

### Primal Bound Quality
Next, we execute a number of primal-bounding experiments over different formulation types and polyhedral partitioning schemes, as in the "Primal-bounding Experiments" subsection of the article.
For example, to solve the (MILP-OA) formulation using continuously relaxed flow direction variables and a flow partitioning scheme corresponding to a one meter error tolerance, the following may be executed:
```bash
julia -J${SYSIMAGE_PATH} --project=src scripts/execution/primal_bound_quality.jl \
      --input_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-PW-OWF.json \
      --cuts_path results/preprocessing/Simple_FSD-24_Steps-Day_1-OBCG.json \
      --output_path results/primal_bound_quality/Simple_FSD-24_Steps-Day_1-MILP-OA-1m.json \
      --time_limit 3600.0 \
      --error_tolerance 1.0 \
      --formulation LRDXWaterModel \
      --relax_direction true
```
Here, `LRDXWaterModel` models the (MILP-OA) formulation with duality-based cuts.
Similarly, `PWLRDXWaterModel` models the (MILP-PW) formulation with duality-based cuts.
To run all of the primal-bounding experiments considered in the article, execute
```bash
# Solve linear relaxation-based models.
julia -J${SYSIMAGE_PATH} --project=src scripts/execution/primal_bound_quality.jl \
      --input_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-PW-OWF.json \
      --cuts_path results/preprocessing/Simple_FSD-24_Steps-Day_1-OBCG.json \
      --output_path results/primal_bound_quality/Simple_FSD-24_Steps-Day_1-MILP-OA-1m.json \
      --time_limit 3600.0 \
      --error_tolerance 1.0 \
      --formulation LRDXWaterModel \
      --relax_direction true

julia -J${SYSIMAGE_PATH} --project=src scripts/execution/primal_bound_quality.jl \
      --input_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-PW-OWF.json \
      --cuts_path results/preprocessing/Simple_FSD-24_Steps-Day_1-OBCG.json \
      --output_path results/primal_bound_quality/Simple_FSD-24_Steps-Day_1-MILP-OA-5m.json \
      --time_limit 3600.0 \
      --error_tolerance 5.0 \
      --formulation LRDXWaterModel \
      --relax_direction true

julia -J${SYSIMAGE_PATH} --project=src scripts/execution/primal_bound_quality.jl \
      --input_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-PW-OWF.json \
      --cuts_path results/preprocessing/Simple_FSD-24_Steps-Day_1-OBCG.json \
      --output_path results/primal_bound_quality/Simple_FSD-24_Steps-Day_1-MILP-OA-25m.json \
      --time_limit 3600.0 \
      --error_tolerance 25.0 \
      --formulation LRDXWaterModel \
      --relax_direction true

# Solve piecewise-linear relaxation-based models.
julia -J${SYSIMAGE_PATH} --project=src scripts/execution/primal_bound_quality.jl \
      --input_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-PW-OWF.json \
      --cuts_path results/preprocessing/Simple_FSD-24_Steps-Day_1-OBCG.json \
      --output_path results/primal_bound_quality/Simple_FSD-24_Steps-Day_1-MILP-PW-1m.json \
      --time_limit 3600.0 \
      --error_tolerance 1.0 \
      --formulation PWLRDXWaterModel \
      --relax_direction false

julia -J${SYSIMAGE_PATH} --project=src scripts/execution/primal_bound_quality.jl \
      --input_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-PW-OWF.json \
      --cuts_path results/preprocessing/Simple_FSD-24_Steps-Day_1-OBCG.json \
      --output_path results/primal_bound_quality/Simple_FSD-24_Steps-Day_1-MILP-PW-5m.json \
      --time_limit 3600.0 \
      --error_tolerance 5.0 \
      --formulation PWLRDXWaterModel \
      --relax_direction false

julia -J${SYSIMAGE_PATH} --project=src scripts/execution/primal_bound_quality.jl \
      --input_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-PW-OWF.json \
      --cuts_path results/preprocessing/Simple_FSD-24_Steps-Day_1-OBCG.json \
      --output_path results/primal_bound_quality/Simple_FSD-24_Steps-Day_1-MILP-PW-25m.json \
      --time_limit 3600.0 \
      --error_tolerance 25.0 \
      --formulation PWLRDXWaterModel \
      --relax_direction false
```

### Improvement Evaluation
In the "Relative Effects of Formulation Improvements" section, we evaluate improvements from using each model strengthening technique in sequence using the five `Poormond-48_Steps` instances.
Continuing with the less computationally expensive example of `Simple_FSD-24_Steps-Day_1`, execution of similar experiments involve running the following:
```bash
julia -J${SYSIMAGE_PATH} --project=src scripts/execution/improvement_evaluation.jl \
      --input_path results/preprocessing/Simple_FSD-24_Steps-Day_1-NONE.json \
      --cuts_path data/instances/Simple_FSD/initial_cuts.json \
      --output_path results/improvement_evaluation/Simple_FSD-24_Steps-Day_1-NONE.json \
      --time_limit 3600.0 \
      --error_tolerance 1.0 \
      --formulation WM.LRDWaterModel \
      --relax_direction true

julia -J${SYSIMAGE_PATH} --project=src scripts/execution/improvement_evaluation.jl \
      --input_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-OA-SS.json \
      --cuts_path data/instances/Simple_FSD/initial_cuts.json \
      --output_path results/improvement_evaluation/Simple_FSD-24_Steps-Day_1-BT-OA-SS.json \
      --time_limit 3600.0 \
      --error_tolerance 1.0 \
      --formulation WM.LRDWaterModel \
      --relax_direction true

julia -J${SYSIMAGE_PATH} --project=src scripts/execution/improvement_evaluation.jl \
      --input_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-PW-SS.json \
      --cuts_path data/instances/Simple_FSD/initial_cuts.json \
      --output_path results/improvement_evaluation/Simple_FSD-24_Steps-Day_1-BT-PW-SS.json \
      --time_limit 3600.0 \
      --error_tolerance 1.0 \
      --formulation WM.LRDWaterModel \
      --relax_direction true

julia -J${SYSIMAGE_PATH} --project=src scripts/execution/improvement_evaluation.jl \
      --input_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-PW-SQ.json \
      --cuts_path data/instances/Simple_FSD/initial_cuts.json \
      --output_path results/improvement_evaluation/Simple_FSD-24_Steps-Day_1-BT-PW-SQ.json \
      --time_limit 3600.0 \
      --error_tolerance 1.0 \
      --formulation WM.LRDWaterModel \
      --relax_direction true

julia -J${SYSIMAGE_PATH} --project=src scripts/execution/improvement_evaluation.jl \
      --input_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-OA-OWF.json \
      --cuts_path data/instances/Simple_FSD/initial_cuts.json \
      --output_path results/improvement_evaluation/Simple_FSD-24_Steps-Day_1-BT-OA-OWF.json \
      --time_limit 3600.0 \
      --error_tolerance 1.0 \
      --formulation WM.LRDWaterModel \
      --relax_direction true

julia -J${SYSIMAGE_PATH} --project=src scripts/execution/improvement_evaluation.jl \
      --input_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-PW-OWF.json \
      --cuts_path data/instances/Simple_FSD/initial_cuts.json \
      --output_path results/improvement_evaluation/Simple_FSD-24_Steps-Day_1-BT-PW-OWF.json \
      --time_limit 3600.0 \
      --error_tolerance 1.0 \
      --formulation WM.LRDWaterModel \
      --relax_direction true

julia -J${SYSIMAGE_PATH} --project=src scripts/execution/improvement_evaluation.jl \
      --input_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-PW-OWF.json \
      --cuts_path data/instances/Simple_FSD/initial_cuts.json \
      --output_path results/improvement_evaluation/Simple_FSD-24_Steps-Day_1-DUAL_CUTS.json \
      --time_limit 3600.0 \
      --error_tolerance 1.0 \
      --formulation LRDXWaterModel \
      --relax_direction true

julia -J${SYSIMAGE_PATH} --project=src scripts/execution/improvement_evaluation.jl \
      --input_path results/preprocessing/Simple_FSD-24_Steps-Day_1-BT-PW-OWF.json \
      --cuts_path results/preprocessing/Simple_FSD-24_Steps-Day_1-OBCG.json \
      --output_path results/improvement_evaluation/Simple_FSD-24_Steps-Day_1-OBCG.json \
      --time_limit 3600.0 \
      --error_tolerance 1.0 \
      --formulation LRDXWaterModel \
      --relax_direction true
```

### Long Time Limit Improvement Evaluation
Figure 7 within the article illustrates solution convergence when solving the `Poormond-48_Steps-Day_4` instance using the various strengthening techniques and a time limit of eight hours instead of one hour.
To forgo repetition, we remark that such experiments would be executed as above, but instead replacing the output directory `improvement_evaluation` with `improvement_evaluation_long` and `--time_limit 3600.0` with `--time_limit 28800.0`.

### Batch Execution on Slurm-based Clusters
In practice, the experiments within the manuscript were executed on a cluster at Los Alamos National Laboratory using the Slurm workload manager.
A number of Slurm scripts to automate execution of experiments similar to the above are provided in the `scripts/slurm` directory.
The `submit_*` Bash scripts within this directory can be used to submit each subset of experiments to the cluster.
For example, `submit_poormond_48_steps` executes all preprocessing, dual bound improvement, and primal bound quality experiments in the required order for all 48-step Poormond instances.
After completion of the jobs has been verified, `submit_improvement_evaluation` may be used to submit the first set of improvement evaluation experiments, and `submit_improvement_evaluation_long` may be used to submit the variants that use a larger time limit.
Note that the command `source .profile` in each Slurm batch script (i.e., those scripts that are not prefixed by `submit_`) assumes the presence of a `.profile` file in the project directory.
This might include, for example, the commands to export environment variables, as described in the [section regarding the installation of dependencies](#Installing-Dependencies).

## Postprocessing Experimental Output
Most of the `results` subdirectories include unprocessed experimental output and logs.
A number of utility scripts are provided in the `scripts/analysis` directory to translate these results to more convenient formats for plotting and insertion into tables.
For the most part, these scripts are named according to which figures utilize the postprocessed output.

To generate CSV files used in the production of figures, execute
```bash
julia --project=src scripts/analysis/build_figure_2_csvs.jl
python3 scripts/analysis/build_figure_3_csvs.py
julia --project=src scripts/analysis/build_figure_4_csvs.jl
julia --project=src scripts/analysis/build_figures_5_and_6_csvs.jl
./scripts/analysis/build_figure_7_csvs
```
The outputs of these commands will be stored in the `results/postprocessed` directory.

To generate text included in tables throughout the article, execute
```bash
python3 scripts/analysis/build_table_4_values.py
julia --project=src scripts/analysis/build_table_5_values.jl
julia --project=src scripts/analysis/build_table_6_values.jl
```
The outputs of these commands will be printed to standard out.

To produce the example values presented in Table 3, bound tightening routines were executed using the Gurobi settings `OutputFlag=1` and `TimeLimit=1.0`.
The number of continuous and binary variables, as well as the number of constraints, were then extracted from the initial Gurobi output appearing in the bound tightening log.
This initial output is provided in the `.log` files in the `results/bound_tightening_complexity` directory.

The CSVs used to construct the plots in Appendix I in the supplement can be generated via
```bash
python3 scripts/analysis/build_supplemental_material_csvs.py
```

## Support
Support can be obtained by posting issues to the [WaterModels](https://github.com/lanl-ansi/WaterModels.jl) and [WaterModelsAnnex](https://github.com/lanl-ansi/WaterModelsAnnex.jl) GitHub projects.
It can also be obtained by messaging the first author directly at [byron@tasseff.com](mailto:byron@tasseff.com).

## License
This code archive is provided under a BSD license as part of the Multi-Infrastructure Control and Optimization Toolkit (MICOT) project, LA-CC-13-108.
