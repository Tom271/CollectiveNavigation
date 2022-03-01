using Revise
using DrWatson
@quickactivate "Animal Navigation"
using AnimalNavigation
using Makie
using GLMakie
using DelimitedFiles
include(srcdir("processing.jl"))
function flow_and_terminal_time(flow, terminal_time, sensing_range, position_data)::Bool
    has_flow = !ismissing(flow)
    has_time = terminal_time == 5000
    has_pos_data = !ismissing(position_data)
    high_sensing = sensing_range == 0
    has_flow && has_time && has_pos_data && high_sensing
end

filter_func = flow_and_terminal_time
df = get_trajectory_data(
    [:flow_kw, :terminal_time, :sensing_range, :position_data],
    filter_func,
);
interpolate_time!(df);

simulation = df[1, :];
file_path = simulation["position_data"]
positions = readdlm(file_path);
goal_location = simulation["goal_location"];
goal_tolerance = 10;

fig, ax, s = scatter(
    convert(Vector{Float64}, positions[1, :]),
    convert(Vector{Float64}, positions[2, :]),
    ms = 3,
    color = :blue,
)

scatter!(tuple(goal_location...), ms = 50)

lines!(
    goal_location[1] .+ goal_tolerance * cos.(0:0.01:2π),
    goal_location[2] .+ goal_tolerance * sin.(0:0.01:2π);
    color = :red,
)
vert_stream = get_flow_function(
    "smooth_vertical_stream";
    w_1 = 150,
    w_2 = 200,
    strength = 0.5,
    noise = 0.1,
)
# plot_flow_field!(vert_stream; x=range(-210, stop = 210, length = 50), y=range(-210, stop = 210, length = 50))

ax.autolimitaspect = 1
s_prev = s
record(
    fig,
    plotsdir("test.mp4"),
    1:8:size(positions)[1];
    framerate = 60,
) do i
    global s_prev
    delete!(ax, s_prev)
    trim_empty(x) = filter(i -> isa(i, Float64), x)
    x = convert(Vector{Float64}, trim_empty(positions[i, :]))
    y = convert(Vector{Float64}, trim_empty(positions[i+1, :]))
    s = scatter!(x, y, ms = 3, color = :blue)
    s_prev = s
end
