using DrWatson
@quickactivate "Animal Navigation"

using DataFrames
using Interpolations
using Plots
using Statistics

df = collect_results(datadir("exp_raw"))

for row ∈ eachrow(df)
    individuals_remaining = row.individuals_remaining
    grid_time = 0:row.terminal_time/2000:row.terminal_time

    itp = interpolate((row.event_times,), individuals_remaining, Gridded(Linear()))
    etpf = extrapolate(itp, Flat())
    row["individuals_remaining"] = round.(etpf(grid_time))

    distance = row.average_dist_to_goal
    itp = interpolate((row.event_times,), distance, Gridded(Linear()))
    etpf = extrapolate(itp, Flat())
    row["average_dist_to_goal"] = round.(etpf(grid_time))

    neighbours = row.num_neighbours
    itp = interpolate((row.event_times,), neighbours, Gridded(Linear()))
    etpf = extrapolate(itp, Flat())
    row["num_neighbours"] = round.(etpf(grid_time))
    println(basename(row.path))
    d = Dict(names(row) .=> values(row))
    safesave(datadir("exp_pro", basename(row.path)), d)
end
