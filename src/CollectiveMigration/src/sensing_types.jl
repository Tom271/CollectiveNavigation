d(x1, y1, x2, y2) = sqrt((x1 - x2)^2 + (y1 - y2)^2)

function mydistmat_self_one_agent(x, agent_to_update)
    n = size(x)[2]
    out = zeros(n)
    @inbounds for j in 1:n
        out[j] = d(x[1, agent_to_update], x[2, agent_to_update], x[1, j], x[2, j])
    end
    out
end

function calculate_neighbour_distance(agent_to_update::Int64, current_pos::Matrix{Float64})
    nbhr_dist = mydistmat_self_one_agent(current_pos, agent_to_update)
    # Prevent self-interaction, you are not your own neighbour! 
    nbhr_dist[agent_to_update] = 1E6
    return nbhr_dist
end

# function calculate_neighbour_distance_old(agent_to_update::Int64, current_pos::Matrix{Float64})
#     distances = pairwise(euclidean, current_pos)
#     # Prevent self-interaction, you are not your own neighbour! 
#     distances[agent_to_update, agent_to_update] = 1E6
#     nbhr_dist = distances[agent_to_update, :]
#     return nbhr_dist
# end

function find_neighbours_in_range(
    agent_to_update::Int64,
    current_pos::Matrix{Float64};
    sensing_range::Real=10.0
)
    all_distances = calculate_neighbour_distance(agent_to_update, current_pos)
    neighbours = findall(all_distances .< sensing_range)
    return neighbours
end

function find_nearest_neighbours(
    agent_to_update::Int64,
    current_pos::Matrix{Float64};
    sensing_range::Int=5
)
    all_distances = calculate_neighbour_distance(agent_to_update, current_pos)
    num_agents = length(all_distances)
    # num_agents-1 so that sef interaction never occurs (set in calculate_neighbour_distance to be largest)
    neighbours = partialsortperm(all_distances, 1:min(sensing_range, num_agents - 1))
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
                sensing_range=sensing_range
            ),
        "nearest" =>
            (agent_to_update, current_pos) -> find_nearest_neighbours(
                agent_to_update,
                current_pos;
                sensing_range=sensing_range
            ),
    )
    return sensing_kernels[kernel]
end
