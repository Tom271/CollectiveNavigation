module CollectiveNavigation

using DrWatson
using Reexport
@reexport using Makie, DataFrames
@reexport using CollectiveMigration
export run_experiment, run_experiment_one_param
include("running_experiments.jl")

end
