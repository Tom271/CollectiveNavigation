#= Swimming against the flow
Standard configuration, averaged over 10 realisations. Actual and intended headings
=#
using DrWatson
using DelimitedFiles
@quickactivate :CollectiveNavigation
const kappa_CDF, kappa_input = load_kappa_CDF();
# Create default config
# List of parameters to vary over as input to run_experiment
config = SimulationConfig(
    num_repeats = 10,
    flow = Dict("type" => "constant", "strength" => 0.0),
    sensing = Dict("type" => "nearest", "range" => 0),
    kappa_CDF = kappa_CDF,
    terminal_time = 5000,
    heading_perception = Dict("type" => "actual"),
    kappa_input = kappa_input,
);
parse_config!(config);
# df = run_realisation(config; save_output=true)
# all_data = run_many_realisations(config)
actual_against_flow_data = run_experiment(
    config,
    :flow,
    :sensing;
    flow_values = 0.0:0.1:0.5,
    sensing_values = Int64.([0.0, 1.0, 2.0, 3.0, 5.0, 10.0, 20.0, 50.0, 500.0]),
)
actual_fig, ax, pltobj = plot_stopping_time_heatmap(
    actual_against_flow_data,
    :individuals_remaining_mean,
    :flow,
    :sensing,
);
save(plotsdir("actual_nearest_against_flow_ind_rem_heatmap.png"), actual_fig)
actual_against_flow_data = nothing
config = SimulationConfig(
    num_repeats = 10,
    flow = Dict("type" => "constant", "strength" => 0.0),
    sensing = Dict("type" => "nearest", "range" => 0),
    kappa_CDF = kappa_CDF,
    terminal_time = 5000,
    kappa_input = kappa_input,
);
parse_config!(config);
intend_against_flow_data = run_experiment(
    config,
    :flow,
    :sensing;
    flow_values = 0.0:0.1:0.5,
    sensing_values = Int64.([0.0, 1.0, 2.0, 3.0, 5.0, 10.0, 20.0, 50.0, 500.0]),
)
intend_fig, ax, pltobj = plot_stopping_time_heatmap(
    intend_against_flow_data,
    :individuals_remaining_mean,
    :flow,
    :sensing,
);
save(plotsdir("intend_nearest_against_flow_ind_rem_heatmap.png"), intend_fig)