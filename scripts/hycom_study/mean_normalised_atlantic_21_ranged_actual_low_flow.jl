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
    "type" => "hycom_mean",
    "strength" => 1.0,
    "config" => h
);

config = SimulationConfig(
    num_repeats=25,
    flow=flow_dic,
    sensing=Dict("type" => "ranged", "range" => 0.0),
    heading_perception=Dict("type" => "actual"),
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
    flow_values=collect(0.0:0.05:0.25),  # [0.0, collect(5:2.0:10)...],
    sensing_values=sensing_values,
    show_log=true
)
@info "Decompressing..."
df = decompress_data(hycom_flow_data)
arrival_times = @pipe df |>
                      get_arrival_times(_, [:sensing_range, :flow_strength]);
median_arrival = get_centile_arrival(arrival_times; centile=50);
full_arrival_times = make_failures_explicit(median_arrival, df, [:sensing_range, :flow_strength]);
arrival_times = full_arrival_times
fig, ax, hm = plot_arrival_heatmap(arrival_times)
save(plotsdir("hycom_flow_ranged_actual_low_flow_heatmap.png"), fig)
fig