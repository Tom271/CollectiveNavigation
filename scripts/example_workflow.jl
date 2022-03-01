using DrWatson
@quickactivate :CollectiveNavigation
# using CollectiveMigration
# include(srcdir("processing.jl"))
# include(srcdir("running_experiments.jl"))
function flow_and_terminal_time(
    flow,
    terminal_time,
    sensing_type,
    sensing_range,
    position_data,
)::Bool
    has_flow = !ismissing(flow) & isa(flow, Real)
    # flow_type = flow == #isa(#"annulus" #isa(flow, String) #vortex, vertical_stream
    # flow_type = sensing_range = 500
    has_time = terminal_time == 5000
    is_ranged = sensing_type == "ranged"

    # has_pos_data = !ismissing(position_data)
    has_flow && has_time && is_ranged #&& flow_type
end
terminal_time = 5000;
filter_func = flow_and_terminal_time
df = get_trajectory_data(
    [:flow, :terminal_time, :sensing_type, :sensing_range, :position_data],
    filter_func,
);
interpolate_time!(df);
avg_df = calculate_average(df, "individuals_remaining", :sensing_range, :flow)
# Plot std ribbons and means for flow/sensing range
subs = subset(avg_df, :flow => ByRow(==(0.1)))
g = plot(
    df.coarse_time[1],
    subs.avg_individuals_remaining;
    ribbon = subs.std_individuals_remaining,
    fillalpha = 0.2,
    label = hcat(subs.sensing_range)',
)
xlims!((0, 800))
title!("Flow = 0.1")
xlabel!("Time")
ylabel!("Individuals Remaining")
save(plotsdir("01_flow_sensing_range_ranged.png"), g)


function stopping_time_index(row)
    idx = findfirst(x -> x <= 0.2 * row[1], row)
    return isnothing(idx) ? missing : idx
end

avg_df = transform(
    avg_df,
    :avg_individuals_remaining => ByRow(stopping_time_index) => :stopping_time_index,
)
sort!(avg_df)
plot(
    df.coarse_time[1],
    avg_df.avg_individuals_remaining,
    label = hcat(avg_df.sensing_range)',
)

ylabels = string.(sort(unique(avg_df.sensing_range)))
ylabels[end] = "∞"
xlabels = string.(sort(unique(avg_df.flow)))

# Shape list
coarse_time = range(0, terminal_time; length = 2001)
stopping_times = []
for stopping_time_index in avg_df.stopping_time_index
    println(stopping_time_index)
    if ismissing(stopping_time_index)
        push!(stopping_times, missing)
    else
        push!(stopping_times, coarse_time[stopping_time_index])
    end
end
# stopping_times = coarse_time[avg_df.stopping_time_index]
Z = reshape(avg_df.stopping_time_index, (length(xlabels), length(ylabels)))
# Log scale, go from index to time.
logZ = log.(Z)
normalZ = Z./Z[1,1]
# h = heatmap(xlabels, ylabels, log.(Z), colorbar = :none)
using CairoMakie
fig, ax, pltobj = CairoMakie.heatmap(
    1:length(unique(avg_df.flow)),
    1:length(unique(avg_df.sensing_range)),
    logZ;
    axis=(; xlabel="Flow Strength", ylabel="Sensing Range", xticks=(1:6,xlabels), yticks=(1:6,ylabels)),
    colormap=Reverse(:balance))
text!(
    string.(round.(100 .* normalZ) ./ 100)[:],
    position = Point.(
            (1:length(xlabels)),
            (1:length(ylabels))',
        )[:],
    align = (:center, :baseline),
    color = :white,
)
Colorbar(fig[1, 2], pltobj)
fig
save(plotsdir("const_flow_ranged_heatmap_log_scaled.png"), h)
