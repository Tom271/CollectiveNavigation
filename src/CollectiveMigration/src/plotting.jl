CairoMakie.set_theme!(theme_minimal())
update_theme!(
    Lines = (linewidth = 4,),
    palette = (color = ["#5BBCD6", "#F98400", "#F2AD00", "#00A08A", "#FF0000"],),
)

Zissou = ["#3B9AB2", "#78B7C5", "#EBCC2A", "#E1AF00", "#F21A00"]

function get_stopping_time(avg_df, stat, fraction_arrived)
    avg_stat = avg_df[!, stat]
    idx = findfirst(x -> x <= (1 - fraction_arrived) * avg_stat[1], avg_stat)
    return isnothing(idx) ? missing : avg_df.coarse_time[idx]
end

function get_stopping_times(results::DataFrame; fraction_arrived = 0.9)
    return select(
        results,
        :lw_config => ByRow(x -> x.flow["strength"]) => :flow_strength,
        :lw_config => ByRow(x -> x.sensing["range"]) => :sensing_range,
        :avg_df =>
            ByRow(
                x -> get_stopping_time(x, :individuals_remaining_mean, fraction_arrived),
            ) => :stopping_time,
    )
end

function arrivaltimeheatmap(
    stopping_times;
    logged = true,
    normalised = true
    )
    xlabels = unique(stopping_times.flow_strength)
    ylabels = unique(stopping_times.sensing_range)
    stopping_time = stopping_times.stopping_time
    Z = reshape(stopping_time, (length(ylabels), length(xlabels)))

    fig, ax, plotobj = GLMakie.heatmap(
        1:length(xlabels),
        1:length(ylabels),
        logged ? log.(Z') : Z';
        colormap = cmap("D4"),
        axis = (;
            xlabel = "Flow Strength",
            ylabel = "Sensing Range",
            xticks = (1:length(xlabels), string.(xlabels)),
            yticks = (1:length(ylabels), string.(ylabels)),
        ),
    )
    # Add labels
    normalZ = Z ./ Z[ylabels.==0.0, xlabels.==0.0]
    normalZ = [ismissing(i) ? 0 : i for i ∈ normalZ]
    Z = [ismissing(i) ? 0 : i for i ∈ Z]
    Z = convert.(Int64, Z)
    labels = string.(normalised ? round.(normalZ, sigdigits=2) : Z)
    text!(
        labels[:],
        position = Point.((1:length(xlabels))', (1:length(ylabels)))[:],
        align = (:center, :baseline),
        color = :white,
        textsize = normalised ? 20 : 15
    )
    c = Colorbar(
        fig[1, 2],
        plotobj,
        label = "Stopping Time",
        tickformat = xs -> ["$(round(Int64,exp(x)))" for x in xs]
    )



    return fig, ax, plotobj
end

function plot_stopping_time_heatmap(
    results;
    save_plot = false,
    logged = true,
    normalised = true,
    fraction_arrived = 0.9)

    stopping_times = get_stopping_times(results; fraction_arrived)
    fig,ax,plotobj = arrivaltimeheatmap(
        stopping_times;
        logged = logged,
        normalised = normalised
        )
    if(save_plot)
        sensing_type  = results[1,:].lw_config.sensing["type"]
        perception_type  = results[1,:].lw_config.heading_perception["type"]
        flow_type  = results[1,:].lw_config.flow["type"]
        @info "Saved as ind_rem_sr=$(sensing_type)_perc=$(perception_type)_flow=$(flow_type)_heatmap_fraction$(fraction_arrived).png"
        save(plotsdir("ind_rem_sr=$(sensing_type)_perc=$(perception_type)_flow=$(flow_type)_heatmap_fraction$(fraction_arrived).png"),fig)
    end

    return fig, ax, plotobj
end

function plot_animation_v2(
    df::DataFrame;
    sensing_range = missing,
    flow_strength = missing
    )

    traj = filter(
        :lw_config => x-> equals_range(x,sensing_range) &&
        equals_strength(x,flow_strength),
        df
    )

    config = traj.lw_config[1]
    @show config
    
    positions = readdlm(joinpath(config.save_dir, config.save_name * ".tsv"))
    # Arrived particles are stored as empty 
    positions[positions.==""] .= config.goal["location"][1]
    positions = convert.(Float64, positions)
    
    x_pos = positions[1:2:end,:]
    y_pos = positions[2:2:end,:]

    x_node = Observable(x_pos[1,:])
    y_node = Observable(y_pos[1,:])
    fig, ax, s = scatter(
        x_node,
        y_node,
        ms = 3,
        color = Zissou[4],
    )
    xlims!(ax, (-1.5*maximum(x_pos[1,:]), 1.5*maximum(x_pos[1,:]) ) )
    ylims!(ax, (-1.5*maximum(y_pos[1,:]), 1.5*maximum(y_pos[1,:])))

    scatter!(
        tuple(config.goal["location"]...);
        markersize = 2 * config.goal["tolerance"],
        color = Zissou[5],
        markerspace = SceneSpace,
    )
    # ax.autolimitaspect = 1
    record(fig, plotsdir("sr=$(sensing_range)_flow=$(flow_strength).mp4"), 1:2:size(x_pos)[1]; framerate = 30) do i
        x_node[] = x_pos[i,:] 
        y_node[] =  y_pos[i,:]
    end
end

# Diagram Style
function plot_individual!(
    ax::Any,
    pos::Tuple{T,T} where {T},
    heading::Real;
    size::Real = 1,
    colour = Zissou[1],
    arrow_colour = Zissou[2],
    arrow_length = 1.5,
)
    poly!(ax, Makie.Circle(Point2f(pos[1], pos[2]), size), color = colour)
    arrows!(
        ax,
        [pos[1]],
        [pos[2]],
        [arrow_length * cos(heading)],
        [arrow_length * sin(heading)],
        color = arrow_colour,
        arrowsize = 20,
        linewidth = 4,
    )
    return nothing
end

function plot_group!(
    ax::Any,
    pos,
    heading::Vector{T} where {T};
    size::Real = 1,
    colour = Zissou[1],
    arrow_colour = Zissou[2],
    arrow_length = 1.5,
)
    poly!(ax, Makie.Circle.(Point2f.(pos[1, :], pos[2, :]), size), color = colour)
    arrows!(
        ax,
        pos[1, :],
        pos[2, :],
        arrow_length .* cos.(heading),
        arrow_length .* sin.(heading),
        color = arrow_colour,
        arrowsize = 20,
        linewidth = 4,
    )
    return nothing
end

