DrWatson.default_allowed(::SimulationConfig) = (Real, String, Symbol, Dict)
DrWatson.allaccess(::SimulationConfig) = [
    "sensing",
    "flow",
    "num_repeats",
    "mean_run_time",
    "num_agents",
    "terminal_time",
    "goal",
    "initial_condition",
]
DrWatson.default_expand(::SimulationConfig) =
    ["sensing", "flow", "goal", "initial_condition"]

function run_experiment(
    default_config::SimulationConfig,
    flow::Symbol,
    sensing::Symbol;
    flow_values = 0.0:0.1:0.1,
    sensing_values = [0.0, 500.0],
)
    df = DataFrame()
    if default_config.kappa_input === nothing || default_config.kappa_CDF === nothing
        default_config.kappa_CDF, default_config.kappa_input = load_kappa_CDF()
    end
    parse_config!(default_config)
    for flow_value in flow_values
        config = default_config
        config.save_name = ""
        flow_dict = getproperty(config, flow)
        flow_dict["strength"] = flow_value
        setproperty!(config, flow, flow_dict)
        for sensing_value in sensing_values
            logmessage(flow_value, sensing_value)
            sense_dict = getproperty(config, sensing)
            sense_dict["range"] = sensing_value
            setproperty!(config, sensing, sense_dict)
            # safe save not necessary as realisations are averaged over
            file, path = produce_or_load(datadir(), config, run_many_realisations;verbose=false)
            if flow_value == flow_values[1] && sensing_value == sensing_values[1]
                df = DataFrame(file)
            else
                append!(df, file)
            end
        end
    end

    return df
end
