"""
get_mean_individuals_remaining(df::DataFrame, groups::Vector{Symbol})::DataFrame
Calculates mean individuals remaining at each time across realisations.

After grouping by `groups`, calculates the mean and standard deviation
of individuals remaining. Expected input is a `DataFrame` in the form outputted
by `decompress_data`

See also [`decompress_data`](@ref)
"""
function get_mean_individuals_remaining(df::DataFrame, groups::Vector{Symbol})::DataFrame
    @pipe df |>
          groupby(_, [:coarse_time, groups...]) |>
          combine(_, :individuals_remaining => mean, :individuals_remaining => std)
end
