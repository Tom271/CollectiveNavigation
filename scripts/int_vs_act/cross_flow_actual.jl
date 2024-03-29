#= Swimming across the flow
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
    num_repeats = 10,
    flow = Dict("type" => "vertical_stream", "strength" => 0.0),
    sensing = Dict("type" => "nearest", "range" => Int64(0.0)),
    kappa_CDF = kappa_CDF,
    terminal_time = 5000,
    heading_perception = Dict("type" => "actual"),
    kappa_input = kappa_input,
);
parse_config!(config);
# df = run_realisation(config; save_output=true)
# all_data = run_many_realisations(config)
actual_cross_flow_data = run_experiment(
    config,
    :flow,
    :sensing;
    flow_values = 0.0:0.1:0.5,
    sensing_values = Int64.([0.0, 1.0, 2.0, 3.0, 5.0, 10.0, 20.0, 50.0, 500.0]),
)
actual_fig, ax, pltobj = plot_stopping_time_heatmap(
    actual_cross_flow_data,
    :individuals_remaining_mean,
    :flow,
    :sensing,
);
save(plotsdir("actual_nearest_cross_flow_ind_rem_heatmap.png"), actual_fig)
actual_cross_flow_data = nothing
actual_fig, ax, pltobj = nothing, nothing, nothing
config_intend = SimulationConfig(
    num_repeats = 10,
    flow = Dict("type" => "vertical_stream", "strength" => 0.0),
    sensing = Dict("type" => "nearest", "range" => 0),
    kappa_CDF = kappa_CDF,
    terminal_time = 5000,
    kappa_input = kappa_input,
    heading_perception = Dict("type" => "intended"),
);
parse_config!(config_intend);
intend_cross_flow_data = run_experiment(
    config_intend,
    :flow,
    :sensing;
    flow_values = 0.0:0.1:0.5,
    sensing_values = Int64.([0.0, 1.0, 2.0, 3.0, 5.0, 10.0, 20.0, 50.0, 500.0]),
)
intend_fig, ax, pltobj = plot_stopping_time_heatmap(
    intend_cross_flow_data,
    :individuals_remaining_mean,
    :flow,
    :sensing,
);
save(plotsdir("intend_nearest_cross_flow_ind_rem_heatmap.png"), intend_fig)
