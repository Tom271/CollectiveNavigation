using DrWatson
using DelimitedFiles
@quickactivate :CollectiveNavigation
const kappa_CDF, kappa_input = load_kappa_CDF();
# Create default config
# List of parameters to vary over as input to run_experiment
config = SimulationConfig(
    num_repeats = 2,
    flow = Dict("type" => "constant", "strength" => 0.0),
    sensing = Dict("type" => "nearest", "range" => 0),
    kappa_CDF = kappa_CDF,
    terminal_time = 5000,
    kappa_input = kappa_input,
);
parse_config!(config);
# df = run_realisation(config; save_output=true)
# all_data = run_many_realisations(config)
all_data = run_experiment(
    config,
    :flow,
    :sensing;
    flow_values = 0.0:0.1:0.6,
    sensing_values = Int64.([0.0, 1.0, 2.0, 3.0, 5.0, 10.0, 20.0, 50.0, 500.0]),
)

plot_stopping_time_heatmap_v2(all_data, :individuals_remaining_mean, :flow, :sensing);
# plot_stopping_time_heatmap_v2(all_data, :num_neighbours_mean, :flow, :sensing);
plot_stopping_time_heatmap_v2(all_data, :average_dist_to_goal_mean, :flow, :sensing);

# Use df to plot stats + results.

# Animate a file 
# Search through configs for desired params. 
avg_df = DataFrame()
for row in eachrow(all_data)
    if row.lw_config.flow["strength"] == 0.1 && row.lw_config.sensing["range"] == 10.0
        config = row.lw_config
        avg_df = row.avg_df
        break
    end
end

lines!(
    avg_df[!, :coarse_time],
    avg_df[!, :num_neighbours_mean] ./ avg_df[1, :num_neighbours_mean],
)
lines(
    avg_df[!, :coarse_time],
    avg_df[!, :average_dist_to_goal_mean] ,
)
lines!(
    avg_df[!, :coarse_time],
    avg_df[!, :individuals_remaining_mean] ./ avg_df[1, :individuals_remaining_mean],
)
positions = readdlm(joinpath(config.save_dir, config.save_name * ".tsv"));
fig, ax, s = scatter(
    convert(Vector{Float64}, positions[1, :]),
    convert(Vector{Float64}, positions[2, :]),
    ms = 3,
    color = :blue,
)
scatter!(tuple(config.goal["location"]...), ms = 50)
lines!(
    config.goal["location"][1] .+ config.goal["tolerance"] * cos.(0:0.01:2π),
    config.goal["location"][2] .+ config.goal["tolerance"] * sin.(0:0.01:2π);
    color = :red,
)
ax.autolimitaspect = 1
s_prev = s
record(fig, plotsdir("test_nearest.mp4"), 1:8:size(positions)[1]; framerate = 60) do i
    global s_prev
    delete!(ax, s_prev)
    trim_empty(x) = filter(i -> isa(i, Float64), x)
    x = convert(Vector{Float64}, trim_empty(positions[i, :]))
    y = convert(Vector{Float64}, trim_empty(positions[i+1, :]))
    s = scatter!(x, y, ms = 3, color = :blue)
    s_prev = s
end
