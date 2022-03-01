module CollectiveNavigation

using DrWatson
# These should be in CollectiveMigration
using Dates, Distributions, DelimitedFiles, Distances,Manifolds, Random
using Reexport
@reexport using GLMakie, DataFrames
@reexport using CollectiveMigration
export run_realisation, run_many_realisations, run_experiment, parse_config!, open_save_file
export SimulationConfig

# const kappa_CDF, kappa_input = load_kappa_CDF();
include("processing.jl")
include("running_experiments_v2.jl")

end