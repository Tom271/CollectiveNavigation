using DrWatson
@quickactivate :CollectiveNavigation
using NetCDF, Dates, Downloads, Interpolations, JSON
using Pipe: @pipe
using DelimitedFiles
params = HYCOM_Parameters(
    name="n_atlantic_sei_whale_correct",
    start_time="2021-04-13T00:00:00Z",
    end_time="2021-06-07T00:00:00Z",
    min_lat=34.00,
    max_lat=59.76,
    min_long=321.76,
    max_long=332.08,
);
# Download/Load data
flow_config, dl_path = get_flow_data(params);
h = HYCOM_Flow_Data(params)
h, params = sanitise_flow_data!(params, dl_path)
build_interpolants!(h)

flow_dic = Dict(
    "type" => "hycom_mean",
    "strength" => 1.0,
    "config" => h
);

config = SimulationConfig(
    num_repeats=25,
    flow=flow_dic,
    sensing=Dict("type" => "ranged", "range" => 0.0),
    heading_perception=Dict("type" => "intended"),
    terminal_time=5000,
);
parse_config!(config);
sensing_values = [0.0, 1.0, 2.0, 3.0, 5.0, 10.0, 20.0, 50.0, 500.0];
## Run simulation or load data from file if it exists.
hycom_flow_data = run_experiment(
    config,
    :flow,
    :sensing;
    flow_values=collect(0.0:0.25:1.5),  # [0.0, collect(5:2.0:10)...],
    sensing_values=sensing_values,
    show_log=true
)
realisation = subset(hycom_flow_data, :lw_config => ByRow(x -> (x.sensing["range"] .== 10.0) & (x.flow["strength"] == 0.25)));
config = realisation.lw_config[1];
positions = readdlm(joinpath(config.save_dir, config.save_name * ".tsv"));
hycom_flow_data = nothing;
positions[positions.==""] .= 0;
positions = convert.(Float64, positions);
flow_test = get_flow_function(flow_dic);
x_pos = positions[1:2:end, :];
y_pos = positions[2:2:end, :];

x_node = Observable(x_pos[1, :]);
y_node = Observable(y_pos[1, :]);
u = Observable([flow_test(0, x, y)[1] for x in -75:0.5:75, y in -10:0.5:400]);
v = Observable([flow_test(0, x, y)[2] for x in -75:0.5:75, y in -10:0.5:400]);

strength = Observable(sqrt.(u[] .^ 2.0 .+ v[] .^ 2.0));
fig = Figure(resolution=(550, 1920));
ax = Axis(fig[1, 1]; aspect=100 / 500);
hm = heatmap!(ax,
    -75:0.5:75,
    -10:0.5:400,
    strength
);
s = scatter!(x_node, y_node, ms=3, color=:red);

ylims!(ax, (-10, 400));

xlims!(ax, (-50, 50));

scatter!(
    (0, 0);
    markersize=2 * 10,
    color=:blue,
    markerspace=SceneSpace
);

record(
    fig,
    plotsdir("hycom_intended_sr=10_flow=0.25.mp4"),
    1:20:size(x_pos)[1];
    framerate=30
) do i
    x_node[] = x_pos[i, :]
    y_node[] = y_pos[i, :]
    # ROTATED
    u[] = [flow_test(i * 5000 / size(x_pos)[1], x, y)[1] for x in -75:0.5:75, y in -10:0.5:400]
    v[] = [flow_test(i * 5000 / size(x_pos)[1], x, y)[2] for x in -75:0.5:75, y in -10:0.5:400]
    strength[] = sqrt.(u[] .^ 2.0 .+ v[] .^ 2.0)
    ax.title[] = string(i)
end

