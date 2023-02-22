using DrWatson
@quickactivate :CollectiveNavigation
using Interpolations, NetCDF, Dates
using GLMakie
using Pipe: @pipe
using PerceptualColourMaps

### WORKFLOW 
# Build data structure
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
    "type" => "hycom",
    "strength" => 1.0,
    "config" => h
);

config = SimulationConfig(
    num_repeats=5,
    flow=flow_dic,
    sensing=Dict("type" => "ranged", "range" => 0.0),
    heading_perception=Dict("type" => "intended"),
    terminal_time=5000,
);
parse_config!(config);
#### RUN EXPERIMENT
sensing_values = [0.0, 1.0, 2.0, 3.0, 5.0, 10.0, 20.0, 50.0, 500.0];
## Run simulation or load data from file if it exists.
hycom_flow_data = run_experiment(
    config,
    :flow,
    :sensing;
    flow_values=collect(0.0:0.25:5.0),
    sensing_values=sensing_values,
    show_log=true
)
@info "Decompressing..."
df = decompress_data(hycom_flow_data)
## REALISATIONS
sr = 0.0
reduced_df = @pipe df |>
                   subset(
                       _,
                       :sensing_range => x -> x .== (sr),
                   ) |>
                   groupby(_, [:sensing_range, :trial]);
f = Figure()
ax = Axis(f[1, 1], xlabel="Time", ylabel="Individuals Remaining",
    title="Sensing Range = $(sr), Trials = $(maximum(df[!,:trial]))",
    xtickformat=x -> Dates.format.(unix2datetime.(x), "dd/mm/yy"))
for trial in reduced_df
    lines!(
        h.t_to_date.(trial[!, :coarse_time]),
        trial[!, :individuals_remaining];
        label=string(trial[!, :trial][1]),
        color=:slategray,
        linewidth=0.5
    )
end
save(plotsdir("hycom_ind_rem_low_flow.png"), f)
arrival_times = @pipe df |>
                      get_arrival_times(_, [:sensing_range, :flow_strength]);
median_arrival = get_centile_arrival(arrival_times; centile=50);
full_arrival_times = make_failures_explicit(median_arrival, df, [:sensing_range, :flow_strength]);
arrival_times = full_arrival_times
fig, ax, hm = plot_arrival_heatmap(arrival_times)
file_name = "hycom_heatmap_low_flow.png"
@info "Saved as $(file_name)"
save(plotsdir(file_name), fig,)

## ANIMATION
# stats = run_realisation(config; save_output=true);
# df = DataFrame(stats);
# lw_config = deepcopy(config);
# lw_config.kappa_CDF = nothing;
# lw_config.kappa_input = nothing;
# df = DataFrame(@strdict(lw_config, df));
# using DelimitedFiles
# positions = readdlm(datadir("position_data", join([df.lw_config[1].save_name, ".tsv"])));
# positions[positions.==""] .= 0;
# positions = convert.(Float64, positions);
# flow_test = get_flow_function(flow_dic);
# x_pos = positions[1:2:end, :];
# y_pos = positions[2:2:end, :];

# x_node = Observable(x_pos[1, :]);
# y_node = Observable(y_pos[1, :]);
# u = Observable([flow_test(0, x, y)[1] for x in -75:0.5:75, y in -10:0.5:400]);
# v = Observable([flow_test(0, x, y)[2] for x in -75:0.5:75, y in -10:0.5:400]);

# strength = Observable(sqrt.(u[] .^ 2.0 .+ v[] .^ 2.0));
# fig = Figure(resolution=(550, 1920));
# ax = Axis(fig[1, 1]; aspect=100 / 500);
# hm = heatmap!(ax,
#     -75:0.5:75,
#     -10:0.5:400,
#     strength
# );
# s = scatter!(x_node, y_node, ms=3, color=:red);

# ylims!(ax, (-10, 400));

# xlims!(ax, (-50, 50));

# scatter!(
#     (0, 0);
#     markersize=2 * 10,
#     color=:blue,
#     markerspace=SceneSpace
# );

# record(
#     fig,
#     plotsdir("test_full_hycom_high_strength_correct.mp4"),
#     1:20:size(x_pos)[1];
#     framerate=30
# ) do i
#     x_node[] = x_pos[i, :]
#     y_node[] = y_pos[i, :]
#     # ROTATED
#     u[] = [flow_test(i * 5000 / size(x_pos)[1], x, y)[1] for x in -75:0.5:75, y in -10:0.5:400]
#     v[] = [flow_test(i * 5000 / size(x_pos)[1], x, y)[2] for x in -75:0.5:75, y in -10:0.5:400]
#     strength[] = sqrt.(u[] .^ 2.0 .+ v[] .^ 2.0)
#     ax.title[] = string(i)
# end
