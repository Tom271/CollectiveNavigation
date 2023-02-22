CairoMakie.set_theme!(theme_minimal())
update_theme!(
    Lines=(linewidth=4,),
    palette=(color=["#5BBCD6", "#F98400", "#F2AD00", "#00A08A", "#FF0000"],),
)

Zissou = ["#3B9AB2", "#78B7C5", "#EBCC2A", "#E1AF00", "#F21A00"]

function plot_averages(
    df::DataFrame,
    fixed_param::Pair{Symbol,T} where {T<:Real};
    add_ribbon::Bool=true,
    colors=cmap("D4"; N=9))
    fig = Figure()
    ax = Axis(fig[1, 1]; xlabel="Time", ylabel="Individuals Remaining",
        title="$(string(fixed_param[1])) = $(fixed_param[2])")
    arrival_times = @pipe df |>
                          subset(_, fixed_param[1] => x -> x .== fixed_param[2]) |>
                          groupby(_, [:coarse_time, :sensing_range]) |>
                          combine(_, :individuals_remaining => mean, :individuals_remaining => std)

    for (idx, sr) in enumerate(unique(arrival_times[!, :sensing_range]))
        test = @pipe arrival_times |> subset(_, :sensing_range => x -> x .== sr)
        mu_t = test[!, :individuals_remaining_mean]
        sigma_t = test[!, :individuals_remaining_std]
        t = test[!, :coarse_time]
        # Plot Standard deviation ribbon
        add_ribbon && band!(t, mu_t - sigma_t, mu_t + sigma_t; color=(colors[idx], 0.2))
        lines!(
            t,
            mu_t;
            color=colors[idx],
            label=(sr == 0.0) ? "Individual" : string(sr),
            linestyle=(sr == 0.0) ? :dot : :solid)
    end

    axislegend("Sensing Range"; merge=true)
    limits = @pipe arrival_times |>
                   subset(_, :individuals_remaining_mean => x -> ((x .> 0) .& (x .< 100))) |>
                   combine(
                       _,
                       :coarse_time => minimum => :first_arrival,
                       :coarse_time => maximum => :last_arrival
                   )

    xlims!(limits[1, :first_arrival], limits[1, :last_arrival])

    return (fig, ax)
end

function plot_one_density(
    df::DataFrame,
    group::Symbol,
    flow_strength::Real;
    centiles::Vector{Int}=[99, 90, 75, 50, 25, 1, 0],
    colors=cmap("D4"; N=9)
)
    param_vals = unique(df[!, group])
    ylabels = string.(Int.(param_vals))
    f = CairoMakie.Figure()
    ax = CairoMakie.Axis(f[1, 1], yticks=((1:9) .* 0.02, ylabels))
    for (idx, sensing_val) in enumerate(param_vals)
        arrival_times = @pipe df |>
                              get_arrival_times(_, [:sensing_range, :flow_strength]) |>
                              subset(
                                  _,
                                  :sensing_range => x -> x .== sensing_val,
                                  :flow_strength => x -> x .== flow_strength,
                                  :individuals_remaining => ByRow(<(100))
                              )

        hist!(
            ax,
            arrival_times[!, :arrival_time_mean];
            normalization=:pdf,
            offset=idx * 0.02,
            color=:slategray,
            # strokewidth=1,
            # strokearound=true,
            bins=Base.range(0, stop=5000, length=500)
        )

        for (jdx, centile) in enumerate(centiles)
            try
                arrival = @pipe arrival_times |>
                                get_centile_arrival(_; centile=centile)[1, :arrival_time_mean]
                lines!(
                    ax,
                    [arrival, arrival],
                    [idx, idx + 1] .* 0.02;
                    color=colors[jdx],
                    linestyle=(centile == 50) ? :solid : :dot,
                    label=string.(100 - centile),
                    linewidth=(centile == 50) ? 3 : 2
                )
                j += 1
            catch e
                continue
            end
        end
    end
    return (f, ax)
end

function plot_arrival_heatmap(
    arrival_times::DataFrame;
    save_plot=false,
    logged=true,
    normalised=true
)
    xlabels = unique(arrival_times[!, :flow_strength])
    ylabels = unique(arrival_times[!, :sensing_range])
    sort!(arrival_times, [:sensing_range, :flow_strength])
    Z = reshape(arrival_times[!, :arrival_time_mean], (length(xlabels), length(ylabels)))
    fig, ax, hm = GLMakie.heatmap(
        1:length(xlabels),
        1:length(ylabels),
        logged ? log.(Z) : Z;
        colormap=cmap("D4"),
        axis=(;
            xlabel="Flow Strength",
            ylabel="Sensing Range",
            xticks=(1:length(xlabels), string.(xlabels)),
            yticks=(1:length(ylabels), ["Individual", string.(Int.(ylabels))[begin+1:end]...])
        )
    )
    # hlines!(1.5; color=:white, linewidth=1.5)
    # vlines!([5.5, 6.5]; color=:white, linewidth=1.5)
    ref_point = @pipe arrival_times |>
                      subset(
        _,
        :sensing_range => ByRow(==(0)),
        :flow_strength => ByRow(==(0))
    )
    normalZ = Z ./ ref_point[1, :arrival_time_mean]
    normalZ = [ismissing(i) ? 0 : i for i ∈ normalZ]
    Z = [ismissing(i) ? 0 : i for i ∈ Z]
    Z = convert.(Int64, round.(Z))
    labels = string.(normalised ? round.(normalZ, sigdigits=2) : Z)
    text!(
        labels[:],
        position=Point.((1:length(xlabels)), (1:length(ylabels))')[:],
        align=(:center, :baseline),
        color=:white,
        textsize=normalised ? 20 : 15
    )
    c = Colorbar(
        fig[1, 2],
        hm,
        label="Stopping Time",
        tickformat=xs -> ["$(round(Int64,exp(x)))" for x in xs]
    )

    if (save_plot)
        @info "Saved as heatmap.png"
        save(plotsdir("heatmap.png"), fig,)
    end
    return fig, ax, hm
end

function get_stopping_time(avg_df, stat, fraction_arrived)
    avg_stat = avg_df[!, stat]
    idx = findfirst(x -> x <= (1 - fraction_arrived) * avg_stat[1], avg_stat)
    return isnothing(idx) ? missing : avg_df.coarse_time[idx]
end

function get_stopping_times(results::DataFrame; fraction_arrived=0.9)
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

function arrivaltimeheatmap(stopping_times; logged=true, normalised=true)
    xlabels = unique(stopping_times.flow_strength)
    ylabels = unique(stopping_times.sensing_range)
    stopping_time = stopping_times.stopping_time
    Z = reshape(stopping_time, (length(ylabels), length(xlabels)))

    fig, ax, plotobj = GLMakie.heatmap(
        1:length(xlabels),
        1:length(ylabels),
        logged ? log.(Z') : Z';
        colormap=cmap("D4"),
        axis=(;
            xlabel="Flow Strength",
            ylabel="Sensing Range",
            xticks=(1:length(xlabels), string.(xlabels)),
            yticks=(1:length(ylabels), string.(ylabels))
        )
    )
    # Add labels
    normalZ = Z ./ Z[ylabels.==0.0, xlabels.==0.0]
    normalZ = [ismissing(i) ? 0 : i for i ∈ normalZ]
    Z = [ismissing(i) ? 0 : i for i ∈ Z]
    Z = convert.(Int64, Z)
    labels = string.(normalised ? round.(normalZ, sigdigits=2) : Z)
    text!(
        labels[:],
        position=Point.((1:length(xlabels))', (1:length(ylabels)))[:],
        align=(:center, :baseline),
        color=:white,
        textsize=normalised ? 20 : 15,
    )
    c = Colorbar(
        fig[1, 2],
        plotobj,
        label="Stopping Time",
        tickformat=xs -> ["$(round(Int64,exp(x)))" for x in xs],
    )



    return fig, ax, plotobj
end

function plot_stopping_time_heatmap(
    results;
    save_plot=false,
    logged=true,
    normalised=true,
    fraction_arrived=0.9
)

    stopping_times = get_stopping_times(results; fraction_arrived)
    fig, ax, plotobj =
        arrivaltimeheatmap(stopping_times; logged=logged, normalised=normalised)
    if (save_plot)
        sensing_type = results[1, :].lw_config.sensing["type"]
        perception_type = results[1, :].lw_config.heading_perception["type"]
        flow_type = results[1, :].lw_config.flow["type"]
        @info "Saved as ind_rem_sr=$(sensing_type)_perc=$(perception_type)_flow=$(flow_type)_heatmap_fraction$(fraction_arrived).png"
        save(
            plotsdir(
                "ind_rem_sr=$(sensing_type)_perc=$(perception_type)_flow=$(flow_type)_heatmap_fraction$(fraction_arrived).png",
            ),
            fig,
        )
    end

    return fig, ax, plotobj
end

function plot_animation_v2(df::DataFrame; sensing_range=missing, flow_strength=missing)

    traj = filter(
        :lw_config =>
            x -> equals_range(x, sensing_range) && equals_strength(x, flow_strength),
        df,
    )

    config = traj.lw_config[1]
    # @show config

    positions = readdlm(joinpath(config.save_dir, config.save_name * ".tsv"))
    # Arrived particles are stored as empty 
    positions[positions.==""] .= config.goal["location"][1]
    positions = convert.(Float64, positions)

    x_pos = positions[1:2:end, :]
    y_pos = positions[2:2:end, :]

    x_node = Observable(x_pos[1, :])
    y_node = Observable(y_pos[1, :])
    fig, ax, s = scatter(x_node, y_node, ms=3, color=Zissou[4])
    xlims!(ax, (-1.5 * maximum(x_pos[1, :]), 1.5 * maximum(x_pos[1, :])))
    ylims!(ax, (-1.5 * maximum(y_pos[1, :]), 1.5 * maximum(y_pos[1, :])))

    scatter!(
        tuple(config.goal["location"]...);
        markersize=2 * config.goal["tolerance"],
        color=Zissou[5],
        markerspace=SceneSpace
    )
    ax.autolimitaspect = 1
    record(
        fig,
        plotsdir("sr=$(sensing_range)_flow=$(flow_strength).mp4"),
        1:2:size(x_pos)[1];
        framerate=30
    ) do i
        x_node[] = x_pos[i, :]
        y_node[] = y_pos[i, :]
    end
end

# Diagram Style
function plot_individual!(
    ax::Any,
    pos::Tuple{T,T} where {T},
    heading::Real;
    size::Real=1,
    colour=Zissou[1],
    arrow_colour=Zissou[2],
    arrow_length=1.5
)
    poly!(ax, Makie.Circle(Point2f(pos[1], pos[2]), size), color=colour)
    arrows!(
        ax,
        [pos[1]],
        [pos[2]],
        [arrow_length * cos(heading)],
        [arrow_length * sin(heading)],
        color=arrow_colour,
        arrowsize=20,
        linewidth=4,
    )
    return nothing
end

function plot_group!(
    ax::Any,
    pos,
    heading::Vector{T} where {T};
    size::Real=1,
    colour=Zissou[1],
    arrow_colour=Zissou[2],
    arrow_length=1.5
)
    poly!(ax, Makie.Circle.(Point2f.(pos[1, :], pos[2, :]), size), color=colour)
    arrows!(
        ax,
        pos[1, :],
        pos[2, :],
        arrow_length .* cos.(heading),
        arrow_length .* sin.(heading),
        color=arrow_colour,
        arrowsize=20,
        linewidth=4,
    )
    return nothing
end

function plot_hycom_data()
    params = HYCOM_Parameters(
        name="n_atlantic_whole",
        start_time="2021-04-13T00:00:00Z",
        end_time="2021-04-15T00:00:00Z",
        min_lat=29,
        max_lat=69,
        min_long=296,
        max_long=360,
    )
    flow_config, dl_path = get_flow_data(params)
    h = HYCOM_Flow_Data(params)
    h, params = sanitise_flow_data!(params, dl_path)

    time_point = 1
    worldCountries = GeoJSON.read(read("medium_custom.geo.json", String))
    fig = Figure(resolution=(1200, 800))
    ga = GeoMakie.GeoAxis(
        fig[1, 1]; # any cell of the figure's layout
        # source="+proj=longlat +datum=WGS84",
        # lonlims ="automatic",
        dest="+proj=longlat" # the CRS in which you want to plot
        # coastlines=true # plot coastlines from Natural Earth, as a reference.
    )
    long = h.raw[1] .- 360 # shift to align with map
    lat = h.raw[2]
    u_vel = h.raw[4][:, :, time_point]
    v_vel = h.raw[5][:, :, time_point]

    hm = heatmap!(
        ga,
        long,
        lat,
        log.(sqrt.(u_vel .^ 2 + v_vel .^ 2));
        colormap=colormap("Purples")
    )
    hm2 = poly!(
        ga, worldCountries;
        strokecolor=:black,
        color=:white,
        strokewidth=0.5
    )


    ga.xlabel = "Longitude"
    ga.ylabel = "Latitude"
    xlims!(0.92 * minimum(long,), 1.08 * maximum(long,))
    ylims!(0.85 * minimum(lat,), 1.15 * maximum(lat,))
    ga.xticks = 360 .+ round.(0.92*minimum(long,):10:1.08*maximum(long,)) # shift back coord
    ga.xtickformat = "{:d}°"
    ga.yticks = round.(0.85*minimum(lat,):10:1.15*maximum(lat,))
    ga.ytickformat = "{:d}°"
    fig
end