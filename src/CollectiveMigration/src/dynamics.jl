function check_arrivals(positions::Matrix{Float64}, goal_location, goal_tolerance::Real)::Tuple{Vector{Bool}, Float64}
    arrived = []
    average_distance_from_goal = 0.0
    for agent_pos ∈ eachcol(positions)
        distance_from_goal = euclidean(agent_pos, goal_location)
        push!(arrived,  distance_from_goal < goal_tolerance)

        average_distance_from_goal += distance_from_goal
    end
    average_distance_from_goal /= length(positions[1,:])
    return arrived, average_distance_from_goal
end
