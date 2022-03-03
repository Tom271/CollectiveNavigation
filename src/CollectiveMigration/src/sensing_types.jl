function calculate_neighbour_distance(agent_to_update::Int64, current_pos::Matrix{Float64})
    distances = pairwise(euclidean, current_pos)
    # Prevent self-interaction, you are not your own neighbour!
    distances[agent_to_update, agent_to_update] = 1E3
    nbhr_dist = distances[agent_to_update, :]
    return nbhr_dist
end

function find_neighbours_in_range(
    agent_to_update::Int64,
    current_pos::Matrix{Float64};
    sensing_range::Real = 10.0,
)
    all_distances = calculate_neighbour_distance(agent_to_update, current_pos)
    neighbours = findall(all_distances .< sensing_range)
    return neighbours
end

function find_nearest_neighbours(
    agent_to_update::Int64,
    current_pos::Matrix{Float64};
    sensing_range::Int = 5,
)
    all_distances = calculate_neighbour_distance(agent_to_update, current_pos)
    num_agents = length(all_distances)
    neighbours = partialsortperm(all_distances, 1:min(sensing_range, num_agents))
    return neighbours
end

function get_sensing_kernel(sensing::Dict{String,Any})
    kernel = sensing["type"]
    sensing_range = sensing["range"]
    sensing_kernels = Dict{String,Any}(
        "ranged" =>
            (agent_to_update, current_pos) -> find_neighbours_in_range(
                agent_to_update,
                current_pos;
                sensing_range = sensing_range,
            ),
        "nearest" =>
            (agent_to_update, current_pos) -> find_nearest_neighbours(
                agent_to_update,
                current_pos;
                sensing_range = sensing_range,
            ),
    )
    return sensing_kernels[kernel]
end
