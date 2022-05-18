#= Varying Goal Tolerance
How does  the size of the goal affect the performance? 
Seen differences in results for between 5 and 10. Also need to test 
distance from goal.
=#
using DrWatson
using DelimitedFiles
@quickactivate :CollectiveNavigation
const kappa_CDF, kappa_input = load_kappa_CDF();
for num_agents ∈ [30, 100, 500, 1000]
    for tol ∈ [5.0, 10.0, 20.0]
        # Create default config
        # List of parameters to vary over as input to run_experiment
        config = SimulationConfig(
            num_repeats=10,
            flow=Dict("type" => "constant", "strength" => 0.0),
            sensing=Dict("type" => "ranged", "range" => 0.0),
            goal=Dict("location" => [0.0, 0.0], "tolerance" => tol),
            # kappa_CDF = kappa_CDF,
            terminal_time=5000,
            num_agents=num_agents,
            # kappa_input = kappa_input,
        )
        parse_config!(config)
        # df = run_realisation(config; save_output=true)
        # all_data = run_many_realisations(config)
        data = run_experiment_one_param(
            config,
            :sensing;
            sensing_values=[0.0, 1.0, 2.0, 3.0, 5.0, 10.0, 20.0, 50.0, 500.0]
        )
    end
end