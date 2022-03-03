function get_initial_condition(initial_condition, num_agents)
    initial_pos::Matrix{Float64} =
        get_initial_position("box"; bounds = [180, 220, -20, 20], num_agents = num_agents)
    current_headings::Vector{Float64} =
        get_initial_heading("sector"; bounds = [0, 2π], num_agents = num_agents)
    return (initial_pos, current_headings)
end

function get_initial_position(
    initial_position::String;
    bounds::Vector{T} where {T<:Real} = [0, 1, 0, 1],
    num_agents::Int64 = 10,
)
    @assert(length(bounds) == 4, "Bounds of initial condition incorrect length")
    initial_position = lowercase(initial_position)

    initial_positions =
        Dict{String,Any}("box" => box_position(bounds = bounds, num_agents = num_agents))

    try
        return initial_positions[initial_position]
    catch e
        println("Unknown initial position name, using box...")
        return box_position(bounds, num_agents)
    end

end

function box_position(; bounds = bounds, num_agents = num_agents)
    @assert(bounds[1] < bounds[2], "x_2>x_1, check input of bounds")
    @assert(bounds[3] < bounds[4], "x_3>x_4, check input of bounds")
    return [
        rand(Uniform(bounds[1], bounds[2]), (1, num_agents))
        rand(Uniform(bounds[3], bounds[4]), (1, num_agents))
    ]
end

function get_initial_heading(
    initial_heading::String;
    bounds::Vector{T} where {T<:Real} = [0, 2π],
    num_agents::Int64 = 10,
)
    @assert(length(bounds) == 2, "Bounds of initial heading incorrect length")
    @assert(all(bounds .>= 0) & all(bounds .<= 2π), "Bounds must be between 0 and 2π")
    initial_heading = lowercase(initial_heading)

    initial_headings = Dict{String,Any}(
        "sector" => sector_heading(bounds = bounds, num_agents = num_agents),
    )

    try
        return initial_headings[initial_heading]
    catch e
        println("Unknown initial heading name, using full circle...")
        return sector_heading(bounds, num_agents)
    end
end

function sector_heading(; bounds = [0, 2 * π], num_agents = 0)
    return rand(Uniform(bounds[1], bounds[2]), num_agents)
end

