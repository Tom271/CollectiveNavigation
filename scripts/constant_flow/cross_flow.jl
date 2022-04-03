#= Swimming in a cross flow
Standard configuration, averaged over 10 realisations. Ranged and Nearest neighbour 
interactions. 
=#
using DrWatson
using DelimitedFiles
@quickactivate :CollectiveNavigation
const kappa_CDF, kappa_input = load_kappa_CDF();
# Create default config
# List of parameters to vary over as input to run_experiment
config = SimulationConfig(
    num_repeats = 2, # also done 2 with pos data
    flow = Dict("type" => "vertical_stream", "strength" => 0.0),
    sensing = Dict("type" => "ranged", "range" => 0.0),
    kappa_CDF = kappa_CDF,
    terminal_time = 5000,
    kappa_input = kappa_input,
);
parse_config!(config);

ranged_cross_flow_data = run_experiment(
    config,
    :flow,
    :sensing;
    flow_values = 0.0:0.1:0.5,
    sensing_values = [0.0, 1.0, 2.0],#, 3.0, 5.0, 10.0, 20.0, 50.0, 500.0],
)

plot_animation(ranged_cross_flow_data; sensing_value = 1.0, flow_strength = 0.4)
ranged_fig, ax, pltobj = plot_stopping_time_heatmap(
    ranged_cross_flow_data,
    :individuals_remaining_mean,
    :flow,
    :sensing,
);
save(plotsdir("ranged_cross_flow_ind_rem_heatmap.png"), ranged_fig)
realisation = subset(
    ranged_cross_flow_data,
    :lw_config => ByRow(x -> filter_trajectories(x; sensing_range = 1.0)),
)
avg_df = realisation.avg_df
config = realisation.lw_config

# test_config = SimulationConfig(
#     num_repeats = 10,
#     flow = Dict("type" => "vertical_stream", "strength" => 0.1),
#     sensing = Dict("type" => "ranged", "range" => 10.0),
#     kappa_CDF = kappa_CDF,
#     terminal_time = 5000,
#     kappa_input = kappa_input,
# );
# all_data = run_many_realisations(test_config)
specific_flow_data = subset(
    ranged_cross_flow_data,
    :lw_config => ByRow(x -> filter_trajectories(x; flow_strength = 0.4)),
)
theme!()
fig = Figure(resolution = (1200, 800))
ax = Axis(fig[1, 1])
lin = [
    lines!(
        specific_flow_data.avg_df[i][!, :individuals_remaining_mean],
        label = string(specific_flow_data.lw_config[i].sensing["range"]),
    ) for i ∈ 1:length(specific_flow_data.avg_df)
]
axislegend("Sensing \nRange")
ax.xlabel = "Time"
ax.ylabel = "Individuals Remaining"
ax.title = "0.4 Flow"
xlims!(0, 5000)
save(plotsdir("ranged_04_flow_ind_rem_line.png"), fig)


## Positions are not interpolated, they are written every time
#  Could do with interpolation here on every column (?) of the matrix
for row in eachrow(ranged_cross_flow_data)
    if row.lw_config.flow["strength"] == 0.5
        config = row.lw_config
        avg_df = row.avg_df
    end
end
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
g = get_flow_function(config.flow)
f(x, y) = Point2(g(0, x, y))
streamplot!(f, -60..240, -50..50)
s_prev = s
record(
    fig,
    plotsdir("ranged_cross_flow_03_sr_2.mp4"),
    1:8:size(positions)[1];
    framerate = 60,
) do i
    global s_prev
    delete!(ax, s_prev)
    trim_empty(x) = filter(i -> isa(i, Float64), x)
    x = convert(Vector{Float64}, trim_empty(positions[i, :]))
    y = convert(Vector{Float64}, trim_empty(positions[i+1, :]))
    s = scatter!(x, y, markersize = 3, color = :blue)
    s_prev = s
end

f = lines(
    avg_df[!, :coarse_time],
    avg_df[!, :num_neighbours_mean] ./ avg_df[1, :num_neighbours_mean],
)
save(plotsdir("ranged_cross_flow_num_neighbours_line.png"), f)

f = lines(avg_df[!, :coarse_time], avg_df[!, :average_dist_to_goal_mean])
save(plotsdir("ranged_cross_flow_dist_goal_line.png"), f)
f = lines(
    avg_df[!, :coarse_time],
    avg_df[!, :individuals_remaining_mean] ./ avg_df[1, :individuals_remaining_mean],
)
save(plotsdir("ranged_cross_flow_ind_rem_line.png"), f)


config = SimulationConfig(
    num_repeats = 10,
    flow = Dict("type" => "vertical_stream", "strength" => 0.0),
    sensing = Dict("type" => "nearest", "range" => 0),
    # kappa_CDF = kappa_CDF,
    terminal_time = 5000,
    # kappa_input = kappa_input,
);
parse_config!(config);
nearest_cross_flow_data = run_experiment(
    config,
    :flow,
    :sensing;
    flow_values = 0.0:0.1:0.5,
    sensing_values = Int64.([0.0, 1.0, 2.0, 3.0, 5.0, 10.0, 20.0, 50.0, 500.0]),
)
nearest_fig, ax, pltobj = plot_stopping_time_heatmap_v2(
    nearest_cross_flow_data,
    :individuals_remaining_mean,
    :flow,
    :sensing,
);
save(plotsdir("nearest_cross_flow_ind_rem_heatmap.png"), nearest_fig)


specific_flow_data = DataFrame()
built_df = false
for row in eachrow(nearest_cross_flow_data)
    if row.lw_config.flow["strength"] == 0.0
        if !built_df
            specific_flow_data = DataFrame(row)
            built_df = true
        end
        append!(specific_flow_data, DataFrame(row))
    end
end

fig = Figure(resolution = (1200, 800))
ax = Axis(fig[1, 1])
for i ∈ 2:length(specific_flow_data.avg_df)
    sensing_range = specific_flow_data.lw_config[i].sensing["range"]
    lin = lines!(
        specific_flow_data.avg_df[i][!, :individuals_remaining_mean],
        label = string(sensing_range),
    )
end
axislegend("Neighbours")
ax.xlabel = "Time"
ax.ylabel = "Individuals Remaining"
ax.title = "0.0 Flow"
xlims!(0, 700)
save(plotsdir("nearest_0_flow_ind_rem_line.png"), fig)
