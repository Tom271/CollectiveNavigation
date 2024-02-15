module CollectiveNavigation

using DrWatson
using Reexport
@reexport using DataFrames
@reexport using CollectiveMigration
export run_experiment, run_experiment_one_param, run_experiment_flow_angle,
    run_experiment_flow_comp
include("running_experiments.jl")

end
