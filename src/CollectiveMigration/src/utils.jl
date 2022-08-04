function open_save_file(save_dir, save_name)
    if save_name == ""
        date = Dates.now()
        name = Dates.format(date, "yyyy_mm_dd_HH_MM_SS")
    else
        name = save_name
    end
    touch(save_dir * "\\$name.tsv")
    file = open(save_dir * "\\$name.tsv", "w")
    return file, name
end

function logmessage(flow_value, sensing_value)
    # current time
    time = Dates.format(now(), dateformat"yyyy-mm-dd HH:MM:SS")

    # memory the process is using 
    maxrss = "$(round(Sys.maxrss()/1048576, digits=2)) MiB"

    logdata = (; flow_value, sensing_value, maxrss) # lastly the amount of memory being used

    println(
        savename(
            time,
            logdata;
            connector = " | ",
            equals = " = ",
            sort = false,
            digits = 2,
        ),
    )
end

function load_HYCOM_data(file_path::String)
    sea = matread(file_path)
    data_name = " "
    for i in keys(sea)
        println(i)
        data_name = i
    end
    sea = sea[data_name]
    return sea
end

function filter_trajectories(
    lw_config::SimulationConfig;
    sensing_range = missing,
    flow_strength = missing,
)::Bool
    has_flow_strength =
        (flow_strength === missing) ? true : (lw_config.flow["strength"] == flow_strength)
    has_sensing_range =
        (sensing_range === missing) ? true : (lw_config.sensing["range"] == sensing_range)
    has_sensing_range && has_flow_strength
end

"""
    decompress_data(compressed_df::DataFrame)
Decompress the output of `run_experiment` into a long tidy form.

Will append some configuration data *but not all*. Use with caution outside
of intended use cases.

See also [`run_experiment`](@ref)
"""
function decompress_data(compressed_df::DataFrame)::DataFrame
    df = DataFrame()
    i = 1
    for row in ProgressBar(eachrow(compressed_df))
        sensing_range = row.lw_config.sensing["range"]
        flow_strength = row.lw_config.flow["strength"]
        goal_tol = row.lw_config.goal["tolerance"]
        num_agents = row.lw_config.num_agents

        realisation_config = DataFrame(
            sensing_range = fill(sensing_range, size(row.df)[1]),
            flow_strength = fill(flow_strength, size(row.df)[1]),
            goal_tol = fill(goal_tol, size(row.df)[1]),
            num_agents = fill(num_agents, size(row.df)[1]),
        )
        temp = hcat(row.df, realisation_config)
        if i == 1
            df = temp
            i += 1
        else
            df = vcat(df, temp)
        end
    end
    return (df)
end
