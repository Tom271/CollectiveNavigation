#= Swimming against the flow
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
    flow = Dict("type" => "constant", "strength" => 0.0),
    sensing = Dict("type" => "ranged", "range" => 0.0),
    # kappa_CDF = kappa_CDF,
    terminal_time = 5000,
    # kappa_input = kappa_input,
);
parse_config!(config);
# df = run_realisation(config; save_output=true)
# all_data = run_many_realisations(config)
ranged_against_flow_data = run_experiment(
    config,
    :flow,
    :sensing;
    flow_values = 0.0:0.1:0.5,
    sensing_values = [0.0, 1.0, 2.0, 3.0, 5.0, 10.0, 20.0, 50.0, 500.0],
)
ranged_fig, ax, pltobj = plot_stopping_time_heatmap_v2(
    ranged_against_flow_data,
    :individuals_remaining_mean,
    :flow,
    :sensing,
);
save(plotsdir("ranged_against_flow_ind_rem_heatmap.png"), ranged_fig)

config = SimulationConfig(
    num_repeats = 10,
    flow = Dict("type" => "constant", "strength" => 0.0),
    sensing = Dict("type" => "nearest", "range" => 0),
    # kappa_CDF = kappa_CDF,
    terminal_time = 5000,
    # kappa_input = kappa_input,
);
parse_config!(config);
nearest_against_flow_data = run_experiment(
    config,
    :flow,
    :sensing;
    flow_values = 0.0:0.1:0.5,
    sensing_values = Int64.([0.0, 1.0, 2.0, 3.0, 5.0, 10.0, 20.0, 50.0, 500.0]),
)
nearest_fig, ax, pltobj = plot_stopping_time_heatmap_v2(
    nearest_against_flow_data,
    :individuals_remaining_mean,
    :flow,
    :sensing,
);
save(plotsdir("nearest_against_flow_ind_rem_heatmap.png"), nearest_fig)
