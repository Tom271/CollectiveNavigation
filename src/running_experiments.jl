DrWatson.default_allowed(::SimulationConfig) = (Real, String, Symbol, Dict)
DrWatson.allaccess(::SimulationConfig) = [
    "sensing",
    "flow",
    "heading_perception",
    "num_repeats",
    "mean_run_time",
    "num_agents",
    "terminal_time",
    "goal",
    "initial_condition",
]
DrWatson.default_expand(::SimulationConfig) =
    ["sensing", "flow", "goal", "initial_condition", "heading_perception"]

function run_experiment(
    default_config::SimulationConfig,
    flow_param::Symbol,
    sensing_param::Symbol;
    flow_values=0.0:0.1:0.1,
    sensing_values=[0.0, 500.0],
    show_log=true
)
    df = DataFrame()
    if default_config.kappa_input === nothing || default_config.kappa_CDF === nothing
        default_config.kappa_CDF, default_config.kappa_input = load_kappa_CDF()
    end
    parse_config!(default_config)
    for flow_value in flow_values
        config = deepcopy(default_config)
        config.save_name = ""
        flow_dict = getproperty(config, flow_param)
        flow_dict["strength"] = flow_value
        setproperty!(config, flow_param, flow_dict)
        for sensing_value in sensing_values
            # short circuit
            show_log && logmessage(flow_value, sensing_value)
            sense_dict = getproperty(config, sensing_param)
            sense_dict["range"] = sensing_value
            setproperty!(config, sensing_param, sense_dict)
            # safe save not necessary as realisations are averaged over
            file, path = produce_or_load(
                String(datadir("realisation_data")),
                config,
                run_many_realisations;
                verbose=false
            )
            if flow_value == flow_values[1] && sensing_value == sensing_values[1]
                df = DataFrame(file)
            else
                append!(df, file)
            end
        end
    end

    return df
end


function run_experiment_one_param(
    default_config::SimulationConfig,
    sensing_param::Symbol;
    sensing_values=[0.0, 500.0],
    show_log=true
)
    df = DataFrame()
    if default_config.kappa_input === nothing || default_config.kappa_CDF === nothing
        default_config.kappa_CDF, default_config.kappa_input = load_kappa_CDF()
    end
    parse_config!(default_config)
    config = deepcopy(default_config)
    config.save_name = ""
    for sensing_value in sensing_values
        show_log && logmessage(0.0, sensing_value)
        sense_dict = getproperty(config, sensing_param)
        sense_dict["range"] = sensing_value
        setproperty!(config, sensing_param, sense_dict)
        # safe save not necessary as realisations are averaged over
        data, file = produce_or_load(
            String(datadir("realisation_data_met_rob")),
            config,
            run_many_realisations;
            verbose=true
        )
        if sensing_value == sensing_values[1]
            df = DataFrame(data)
        else

            append!(df, data)
        end
    end

    return df
end


function run_experiment_flow_angle(
    default_config::SimulationConfig,
    angle::Symbol;
    angle_values=[0.0, 500.0],
    show_log=true
)
    df = DataFrame()
    if default_config.kappa_input === nothing || default_config.kappa_CDF === nothing
        default_config.kappa_CDF, default_config.kappa_input = load_kappa_CDF()
    end
    parse_config!(default_config)
    config = deepcopy(default_config)
    config.save_name = ""
    for angle_value in angle_values
        show_log && logmessage(0.0, angle_value)
        flow_dict = getproperty(config, :flow)
        flow_dict["angle"] = angle_value
        setproperty!(config, :flow, flow_dict)
        # safe save not necessary as realisations are averaged over
        data, file = produce_or_load(
            String(datadir("realisation_data_angle")),
            config,
            run_many_realisations;
            verbose=true
        )
        if angle_value == angle_values[1]
            df = DataFrame(data)
        else
            append!(df, data)
        end
    end

    return df
end
