struct CyclicContainer{T} <: AbstractVector{T}
    c::Vector{T}
    n::Int
end
CyclicContainer(c) = CyclicContainer(c, 0)

Base.length(c::CyclicContainer) = length(c.c)
Base.size(c::CyclicContainer) = size(c.c)
Base.getindex(c::CyclicContainer, i::Int) = c.c[mod1(i, length(c.c))]
function Base.getindex(c::CyclicContainer)
    c.n += 1
    c[c.n]
end
Base.iterate(c::CyclicContainer, i = 1) = iterate(c.c, i)
Base.getindex(c::CyclicContainer, i) = [c[j] for j in i]

COLORS = [
    "#440154"
    "#472c7b"
    "#3a528b"
    "#2c728e"
    "#20908c"
    "#28ae7f"
    "#5ec961"
    "#addc30"
    "#fde724"
]
Zissou = ["#3B9AB2", "#78B7C5", "#EBCC2A", "#E1AF00", "#F21A00"]
CCOLORS = CyclicContainer(COLORS)
LINESTYLES = CyclicContainer(["-", ":", "--", "-."])

function generate_cmap(n)
    if n > length(COLORS)
        return :viridis
    else
        return cgrad(COLORS[1:n], n; categorical = true)
    end
end
function theme!()
    set_theme!(; palette = (color = COLORS,), fontsize = 26, linewidth = 5)
end


function plot_stopping_time_heatmap(results, stat, x_param, y_param)
    xlabels = Float64[]
    ylabels = Float64[]
    stopping_times = Union{Float64,Missing}[]
    function stopping_time_index(row)
        idx = findfirst(x -> x <= 0.99 * row[1], row)
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
    # @show Z
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

function plot_animation(df::DataFrame; sensing_value = missing, flow_strength = missing)
    specific_flow_data = subset(
        df,
        :lw_config => ByRow(
            x -> filter_trajectories(
                x;
                flow_strength = flow_strength,
                sensing_range = sensing_value,
            ),
        ),
    )
    config = specific_flow_data.lw_config[1]
    @show config
    positions = readdlm(joinpath(config.save_dir, config.save_name * ".tsv"))
    fig, ax, s = scatter(
        convert(Vector{Float64}, positions[1, :]),
        convert(Vector{Float64}, positions[2, :]),
        ms = 3,
        color = Zissou[4],
    )
    scatter!(
        tuple(config.goal["location"]...);
        markersize = 2 * config.goal["tolerance"],
        color = Zissou[5],
        markerspace = SceneSpace,
    )
    ax.autolimitaspect = 1

    g = get_flow_function(config.flow)
    f(x, y) = Point2(g(0, x, y))
    streamplot!(f, -60..240, -50..150)
    xlims!(-60, 240)
    ylims!(-50, 150)
    record(fig, plotsdir("test2.mp4"), 1:50:size(positions)[1]; framerate = 30) do i
        delete!(ax, s)
        trim_empty(x) = filter(i -> isa(i, Float64), x)
        x = convert(Vector{Float64}, trim_empty(positions[i, :]))
        y = convert(Vector{Float64}, trim_empty(positions[i+1, :]))
        s = scatter!(x, y, markersize = 3, color = :blue)
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

