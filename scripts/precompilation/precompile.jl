import PackageCompiler

PackageCompiler.create_sysimage(
    ["ArgParse", "WaterModels", "WaterModelsAnnex", "Gurobi", "JSON", "JuMP"];
    sysimage_path = "scripts/precompilation/WaterModels.so",
    precompile_execution_file = "scripts/precompilation/example.jl"
)