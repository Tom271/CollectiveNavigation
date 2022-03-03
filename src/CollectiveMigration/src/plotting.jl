function plot_stopping_time_heatmap_v2(results, stat, x_param, y_param)
    xlabels = Float64[]
    ylabels = Float64[]
    stopping_times = Union{Float64,Missing}[]
    function stopping_time_index(row)
        idx = findfirst(x -> x <= 0.2 * row[1], row)
        return isnothing(idx) ? missing : idx
    end
    # Iterate through results, calculate stopping time for stat and store
    #  param labels
    for row in eachrow(results)
        x_param_value = getproperty(row.lw_config, x_param)["strength"]
        push!(xlabels, x_param_value)

        y_param_value = getproperty(row.lw_config, y_param)["range"]
        push!(ylabels, y_param_value)
        data = row.avg_df
        stopping_time = stopping_time_index(data[!, stat])
        if ismissing(stopping_time)
            push!(stopping_times, missing)
        else
            push!(stopping_times, data.coarse_time[stopping_time])
        end
    end

    xlabels = unique(xlabels)
    ylabels = unique(ylabels)

    Z = reshape(stopping_times, (length(ylabels), length(xlabels)))
    @show Z
    logZ = log.(Z)
    normalZ = Z ./ Z[1, 1]
    fig, ax, pltobj = GLMakie.heatmap(
        1:length(xlabels),
        1:length(ylabels),
        Z';
        axis = (;
            xlabel = "Flow Strength",
            ylabel = "Sensing Range",
            xticks = (1:length(xlabels), string.(xlabels)),
            yticks = (1:length(ylabels), string.(ylabels)),
        ),
        colormap = Reverse(:balance),
    )
    text!(
        string.(round.(100 .* normalZ) ./ 100)[:],
        position = Point.((1:length(xlabels))', (1:length(ylabels)))[:],
        align = (:center, :baseline),
        color = :white,
    )
    Colorbar(fig[1, 2], pltobj, label = "Stopping Time")
    display(fig)
    return fig, ax, pltobj
end
