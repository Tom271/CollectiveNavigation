module CollectiveMigration

using CodecZlib, DelimitedFiles, DataFrames, Dates, Distances, Distributions, Downloads, DrWatson
using Interpolations, LinearAlgebra, JLD2, JSON, Manifolds, Parameters, NetCDF, Random
# using GeoJSON, Makie, GLMakie, CairoMakie, GeoMakie,  MAT, 
# using Colors, PerceptualColourMaps
using Pipe: @pipe
using ProgressBars

export load_kappa_CDF, get_kappa
export SimulationConfig, parse_config!, run_realisation, run_many_realisations
export logmessage, filter_trajectories, decompress_data
export HYCOM_Parameters, get_flow_data, HYCOM_Flow_Data, sanitise_flow_data!, build_interpolants!
export get_flow_function
export get_sensing_kernel, find_neighbours, circ_resultant
export get_stopping_times
export get_mean_individuals_remaining, get_arrival_times, get_centile_arrival
export make_failures_explicit
# export Zissou
# export theme!
# export plot_individual!, plot_group!, 
# export plot_arrival_heatmap, plot_one_density, plot_averages
# export plot_stopping_time_heatmap, plot_animation_v2

include("circle_stats.jl")
include("dynamics.jl")
include("flows.jl")
include("sensing_types.jl")
include("initial_conditions.jl")
include("statistics.jl")
include("utils.jl")
include("hycom.jl")
# include("plotting.jl")

end # module
