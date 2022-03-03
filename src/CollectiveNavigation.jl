module CollectiveNavigation

using DrWatson
using Reexport
@reexport using GLMakie, DataFrames
@reexport using CollectiveMigration
export run_experiment
include("running_experiments.jl")

end
