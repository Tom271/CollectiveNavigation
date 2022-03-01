using DrWatson
@quickactivate :CollectiveNavigation
const kappa_CDF, kappa_input = load_kappa_CDF();

function flow_vs_sensing_range()
    flow_kw = Dict(
        :strength => collect(0.0:0.1:0.5),
        :w_1 => 150,
        :w_2 => 200,
        :noise => 0.0)
    flow_kw_dicts = dict_list(flow_kw)
    allparams = Dict(
        "sensing_range" => [3,4,6,7,8,9],
        "num_agents" => [100],
        "terminal_time" => [5000],
        "goal_location" => [[100, 0]],
        "flow" => collect(0.0:0.1:0.5),
        "flow_kw" => Dict(), #flow_kw_dicts,
        "sensing_type" => "nearest",
        "n_nearest" => nothing,
    )
    dicts = dict_list(allparams)
    num_repeats = 3
    function makesim(d::Dict)
        @unpack sensing_range,
        num_agents,
        terminal_time,
        goal_location,
        flow,
        flow_kw,
        n_nearest,
        sensing_type = d
        # println("Starting sim with cross flow = $(flow), sensing_range = $sensing_range")
        agents = agent_params(
            num_agents = num_agents,
            sensing_range = sensing_range,
            sensing_type = sensing_type,
            #n_nearest = n_nearest,
        )
        domain = domain_params(
            terminal_time = terminal_time,
            goal_location = goal_location,
            flow = flow,
            flow_kw = flow_kw,
        )
        stats = run_directed_group_with_removal(
            agents,
            domain;
            kappa_input = kappa_input,
            kappa_CDF = kappa_CDF,
            save_name = savename(d),
        )
        input_parameters = copy(d)

        return merge(input_parameters, stats)
    end

    for (i, d) ∈ enumerate(dicts)
        for k ∈ 1:num_repeats
            println(string("Iteration ", k))
            experiment_data = makesim(d)
            @tagsave(
                datadir("exp_raw", savename(d, "jld2")),
                experiment_data;
                safe = true
            )
        end
    end
end


flow_vs_sensing_range()

