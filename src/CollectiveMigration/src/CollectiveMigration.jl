module CollectiveMigration

using CodecZlib, DelimitedFiles, DataFrames, Dates, Distances, Distributions, DrWatson
using Interpolations, LinearAlgebra, JLD2, GLMakie, CairoMakie, Manifolds, MAT, Parameters, Random
using Colors, PerceptualColourMaps
export load_kappa_CDF, get_kappa
export SimulationConfig, parse_config!, run_realisation, run_many_realisations
export logmessage, filter_trajectories
export plot_stopping_time_heatmap, plot_animation_v2
export get_flow_function
export theme!
export plot_individual!, plot_group!, circ_resultant
export get_sensing_kernel, find_neighbours
export Zissou
export get_stopping_times
include("circle_stats.jl")
include("dynamics.jl")
include("flows.jl")
include("sensing_types.jl")
include("initial_conditions.jl")
include("statistics.jl")
include("utils.jl")
include("plotting.jl")

end # module
