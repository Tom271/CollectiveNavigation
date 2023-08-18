"""
    get_mean_individuals_remaining(df::DataFrame, groups::Vector{Symbol})::DataFrame
Calculates mean individuals remaining at each time across realisations.

After grouping by `groups`, calculates the mean and standard deviation
of individuals remaining. Expected input is a `DataFrame` in the form outputted
by `decompress_data`

See also [`decompress_data`](@ref)
"""
function get_mean_individuals_remaining(df::AbstractDataFrame, groups::Vector{Symbol})::DataFrame
    @pipe df |>
          groupby(_, [:coarse_time, groups...]) |>
          combine(_, :individuals_remaining => mean, :individuals_remaining => std)
end


"""
    get_arrival_times(df::DataFrame, groups::Vector{Symbol})::DataFrame
Calculates mean arrival time for the i^th individual

After splitting into `groups`, for each trial, calculate the first time at which there
were i individuals remaining. Then, take the average across trials and the standard
deviation. 

See also [`get_mean_individuals_remaining`](@ref)
"""
function get_arrival_times(df::AbstractDataFrame, groups::Vector{Symbol})
    arrival_times = df
    # Round remaining individuals to integer (fixes non-smooth line issue)
    # Done like this it also converst the column type to Integer (rather than Float64)
    arrival_times[!, :individuals_remaining] =
        convert.(Int, round.(Int, arrival_times[!, :individuals_remaining]))

    arrival_times = @pipe arrival_times |>
                          groupby(_, [groups..., :individuals_remaining, :trial]) |>
                          combine(_, :coarse_time => first) |>
                          groupby(_, [groups..., :individuals_remaining]) |>
                          combine(
                              _,
                              :coarse_time_first => mean => :arrival_time_mean,
                              :coarse_time_first => std => :arrival_time_std,
                          )

end

"""
    get_centile_arrival(arrival_times::DataFrame; centile::Int=50)::DataFrame
Calculates mean arrival time for the centile^th individual

Takes `arrival_times` from [`get_arrival_times`](@ref), and filters to the `centile`
given. Defaults to the median. Should be variable based on `num_agents`. 

See also [`get_arrival_times`](@ref)
"""
function get_centile_arrival(arrival_times::AbstractDataFrame; centile::Int=50)
    @pipe arrival_times |>
          # Remove time when no individuals have arrived (should be variable: num_agents)
          subset(_, :individuals_remaining => x -> x .< 100) |>
          subset(_, :individuals_remaining => x -> x .== centile)
end


"""
    make_failures_explicit(
        arrival_times::DataFrame,
        df::DataFrame,
        groups::Vector{Symbol})::DataFrame
Turns implicit missing values to explicit

From the `arrival_times`, and unique values of `groups` in the dataframe `df`,
constructs a frame without any implicit missing values. *Assumes all combinations
of `groups` have been used*. This is as expected from `run_experiment`

See also [`run_experiment`](@ref),[`get_arrival_times`](@ref)
"""
function make_failures_explicit(
    arrival_times::AbstractDataFrame,
    df::DataFrame,
    groups::Vector{Symbol},
)::DataFrame
    # Turn implicit missing values into explicit
    # Implicit missing values are the realisations that had more than `centile` remaining
    sensing_values = unique(df[!, groups[1]])
    flow_strengths = unique(df[!, groups[2]])
    all_combos = @pipe DataFrame(Iterators.product(sensing_values, flow_strengths)) |>
                       rename(_, [1 => groups[1], 2 => groups[2]])
    full_arrival_times = @pipe arrival_times |> outerjoin(_, all_combos, on=groups)
    return full_arrival_times
end


"""
    get_group_efficiency(df::DataFrame, groups::Vector{Symbol})::DataFrame
Calculates group efficiency at each timestep

After splitting into `groups`, for each trial, load the average distance to goal at each coarse time step. Then, take the average across trials and the standard deviation. 

See also [`get_mean_individuals_remaining`](@ref),[`get_arrival_times`](@ref)
"""
function get_group_efficiency(df::AbstractDataFrame, groups::Vector{Symbol})
    group_eff = df
    group_eff = @pipe group_eff |>
                      groupby(_, [groups..., :coarse_time, :heading_perception]) |>
                      combine(_, :average_dist_to_goal => mean, :average_dist_to_goal => std => :std_dist_to_goal) |>
                      transform(_, [:average_dist_to_goal_mean, :coarse_time] => nav_eff => :nav_eff) |>
                      transform(_, [:average_dist_to_goal_mean, :coarse_time, :flow_strength] => flow_nav_eff => :flow_nav_eff)
end
