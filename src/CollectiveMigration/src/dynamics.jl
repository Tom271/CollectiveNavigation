Base.@kwdef mutable struct SimulationConfig
    num_repeats::Int
    save_dir::String = datadir("position_data")
    save_name::String = ""
    kappa_input::Union{Matrix{Float64},Nothing} = nothing
    kappa_CDF::Union{Array{Float64,3},Nothing} = nothing
    num_agents::Int = 100
    terminal_time::Float64 = 1000
    goal::Dict{String,Any} = Dict("location" => [0.0, 0.0], "tolerance" => 10.0)
    information_field_strength::Float64 = 1.0
    flow::Dict{String,Any} = Dict()
    sensing::Dict{String,Any} = Dict("type" => "ranged", "range" => 0.0)
    initial_condition::Dict{String,Any} = Dict("position" => "box", "heading" => "sector")
    mean_run_time::Float64 = 1.0
    α::Float64 = 0.5
    heading_perception::Dict{String,String} = Dict("type" => "intended")
end

equals_range(config::SimulationConfig, range::Real) = config.sensing["range"] == range
equals_strength(config::SimulationConfig, strength::Real) = config.flow["strength"] == strength

function interpolate_time_dict(stats::Dict{String,Any}, config::SimulationConfig)
    statistics = ["individuals_remaining", "average_dist_to_goal", "num_neighbours"]
    coarse_time = 0:config.terminal_time/5000:config.terminal_time
    interpolated_stats = Dict{String,Any}("coarse_time" => coarse_time)
    for stat ∈ statistics
        interp_stat = interpolate((stats["event_times"],), stats[stat], Gridded(Linear()))
        etpf = extrapolate(interp_stat, Flat())
        interpolated_stats[stat] = etpf(coarse_time)
    end
    interpolated_stats["coarse_time"] = collect(coarse_time)
    return interpolated_stats
end

function parse_config!(config::SimulationConfig)
    # Add synonyms if flow_strength ==0; flow_name = "none" etc.
    # if sensing_range = 0 (regardless of type); sensing_type = individual
    #  removes recalculation (if num_agents etc. is consistent)
    # Pad initial conditions if not given (i.e. provide default headings/positions)
    config.initial_condition["position"] = lowercase(config.initial_condition["position"])
    # config.initial_condition["heading"] = lowercase(config.initial_condition["heading"])
    config.flow["type"] = lowercase(config.flow["type"])
    config.sensing["type"] = lowercase(config.sensing["type"])
    config.heading_perception["type"] = lowercase(config.heading_perception["type"])
    return config
end

function check_arrivals(
    positions::Matrix{Float64},
    goal_location,
    goal_tolerance::Real,
)::Tuple{Vector{Bool},Float64}
    arrived = []
    average_distance_from_goal = 0.0
    for agent_pos ∈ eachcol(positions)
        distance_from_goal = euclidean(agent_pos, goal_location)
        push!(arrived, distance_from_goal < goal_tolerance)
        average_distance_from_goal += distance_from_goal
    end
    average_distance_from_goal /= length(positions[1, :])
    return arrived, average_distance_from_goal
end

function run_realisation(config::SimulationConfig; save_output::Bool=false)
    # Code to do all run and tumble goodness
    # @unpack everything, basically `run_directed_group_with_removal`
    @unpack flow,
    sensing,
    heading_perception,
    terminal_time,
    num_agents,
    kappa_input,
    kappa_CDF,
    initial_condition,
    goal,
    mean_run_time,
    α,
    save_dir,
    save_name = config
    rng = MersenneTwister()
    flow_at = get_flow_function(flow)
    find_neighbours = get_sensing_kernel(sensing)
    starting_num_agents = copy(num_agents)
    # This should be unnecessary when running many, but required if just
    #  running one  
    if kappa_input === nothing || kappa_CDF === nothing
        kappa_CDF, kappa_input = load_kappa_CDF()
    end

    # should empty position matrices be generated into a dict by a function?
    # doesn't really add overhead, marginally cleaner?
    # would have to pass initial_pos, initial heading
    # stats matrix should be generated by a function 
    t::Float64 = 0.0
    # Generate initial positions, directions and clocks
    run_times::Vector{Float64} = rand(rng, Exponential(1 / mean_run_time), num_agents)
    # TODO: create way of passing initial condition
    initial_pos, current_headings = get_initial_condition(initial_condition, num_agents)

    current_pos = copy(initial_pos)

    # Calculate first stats
    dist_to_goal = euclidean(mean(eachcol(current_pos)), goal["location"])
    starting_dist_to_goal = copy(dist_to_goal)
    num_neighbours = length(find_neighbours(1, current_pos))
    avg_num_neighbours::Float64 = num_neighbours

    # Preallocate memory for statistics
    buffer = floor(Int64, terminal_time * num_agents / mean_run_time)
    event_times = [0.0; -1 * ones(buffer)]
    individuals_remaining = [starting_num_agents; -1 * ones(Int64, buffer)]
    average_dist_to_goal = [dist_to_goal; -1 * ones(buffer)]
    num_neighbours_t = [num_neighbours; -1 * ones(Float64, buffer)]

    if save_output
        file, config.save_name = open_save_file(save_dir, save_name)
    end
    agent_to_update::Int64 = 1
    event_count::Int64 = 1
    save_slot::Int64 = 1
    majority_travelling(num_agents) = num_agents >= 1 #ceil(0.1 * starting_num_agents)
    on_track(dist_to_goal) = dist_to_goal < 1.5 * starting_dist_to_goal
    buffer_increase::Int64 = 1

    while (majority_travelling(num_agents) && on_track(dist_to_goal) && t <= terminal_time)

        run_time::Float64, agent_to_update = findmin(run_times)
        run_times = run_times .- run_time
        # run all agents 
        prev_pos = copy(current_pos)
        current_pos =
            current_pos +
            run_time .* transpose([cos.(current_headings) sin.(current_headings)])
        current_pos =
            current_pos .+
            run_time .* hcat(flow_at.(t, current_pos[1, :], current_pos[2, :])...)
        # Tumble one agent 
        # current_headings[agent_to_update], avg_num_neighbours = tumble_agent(agent_to_update, current_pos, current_headings, find_neighbours, agents, domain, kappa_CDF, kappa_input, avg_num_neighbours)

        goal_direction =
            atan(reverse(goal["location"] .- current_pos[:, agent_to_update])...)
        updated_heading = mod(rand(rng, VonMises(goal_direction, 1)), 2π)

        neighbours = find_neighbours(agent_to_update, current_pos)
        num_neighbours = length(neighbours)
        avg_num_neighbours += num_neighbours
        position_change = current_pos .- prev_pos
        actual_headings = atan.(position_change[2, :], position_change[1, :])
        if num_neighbours > 1
            if heading_perception["type"] == "actual"
                neighbour_headings = actual_headings[neighbours]
            elseif heading_perception["type"] == "intended"
                neighbour_headings = current_headings[neighbours]
            else
                throw(DomainError(heading_perception["type"], "Invalid perception type"))
            end
            neighbour_mean = mean(Manifolds.Circle(ℝ), neighbour_headings)
            ϕ::Float64 =
                mean(Manifolds.Circle(ℝ), [neighbour_mean, updated_heading], [1 - α, α])

            weights = [(1 - α) * ones(num_neighbours); α * num_neighbours]
            κ = get_kappa(
                [neighbour_headings; updated_heading],
                weights,
                kappa_CDF,
                kappa_input,
            )
            κ = κ > 10000 ? 10000 : κ
            updated_heading = mod(rand(rng, VonMises(ϕ, κ)), 2π)
        end
        current_headings[agent_to_update] = updated_heading
        run_times[agent_to_update] = rand(rng, Exponential(1 / mean_run_time))

        t = t + run_time
        event_count += 1
        arrived, dist_to_goal =
            check_arrivals(current_pos, goal["location"], goal["tolerance"])
        # println(dist_to_goal)
        if event_count % 10 == 0
            save_slot = Int64(event_count / 10)
            average_dist_to_goal[save_slot] = dist_to_goal
            num_neighbours_t[save_slot] = avg_num_neighbours / 10
            avg_num_neighbours = 0
            event_times[save_slot] = t
            individuals_remaining[save_slot] = num_agents
            if save_output
                writedlm(file, current_pos)
            end
        end

        # Remove agents that have arrived 
        current_pos = current_pos[:, .!arrived]
        current_headings = current_headings[.!arrived]
        run_times = run_times[.!arrived]
        num_agents = length(run_times)


        if event_count >= buffer_increase * buffer
            println("Increasing storage...")
            event_times = [event_times; -1 * ones(buffer)]
            individuals_remaining = [individuals_remaining; -1 * ones(Int64, buffer)]
            average_dist_to_goal = [average_dist_to_goal; -1 * ones(Int64, buffer)]
            num_neighbours_t = [num_neighbours_t; -1 * ones(Float64, buffer)]
            # headings = [headings; -1*ones(buffer)]
            buffer_increase += 1
            println(buffer_increase)
        end
    end
    average_dist_to_goal[save_slot+1] = dist_to_goal
    num_neighbours_t[save_slot+1] = num_neighbours
    event_times[save_slot+1] = t
    individuals_remaining[save_slot+1] = num_agents
    if save_output
        writedlm(file, current_pos)
        close(file)
    end
    trim_buffer(v) = filter(x -> x >= 0, v)

    stats = Dict{String,Any}(
        "event_times" => trim_buffer(event_times),
        "average_dist_to_goal" => trim_buffer(average_dist_to_goal),
        "individuals_remaining" => trim_buffer(individuals_remaining),
        "num_neighbours" => trim_buffer(num_neighbours_t),
        # "headings" => trim_buffer(headings),
    )
    # Interpolate trajectory statistics
    interp_stats = interpolate_time_dict(stats, config)

    return interp_stats
end

function run_many_realisations(config)
    df = DataFrame()
    for i ∈ 1:config.num_repeats
        if i == config.num_repeats
            @time stats = run_realisation(config; save_output=true)
        else
            @time stats = run_realisation(config; save_output=false)
        end

        stats["trial"] = i
        if i == 1
            df = DataFrame(stats)
        else
            realisation_df = DataFrame(stats)
            # Will become very large, better to interpolate
            #   and average on the fly?
            # Interpolate in simulation loop, average after here
            append!(df, realisation_df)
        end
    end

    ## Averaging over coarse time gives funny results, comment out and store all data realisation stats.
    # Add code to do all metrics at once, not just individuals_remaining
    # gdf = groupby(df, :coarse_time)
    # avg_df = combine(
    #     gdf,
    #     [:average_dist_to_goal, :individuals_remaining, :num_neighbours] .=> mean,
    # )
    # Add number of realisations to df
    lw_config = deepcopy(config)
    lw_config.kappa_CDF = nothing
    lw_config.kappa_input = nothing
    return @strdict(lw_config, df)
end
