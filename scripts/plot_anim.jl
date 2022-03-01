# using Plots
using Revise
using DrWatson
@quickactivate "Animal Navigation"
using AnimalNavigation
using Makie
using GLMakie
using DelimitedFiles

agents = agent_params(num_agents = 100, sensing_range = 20)
domain = domain_params(
    terminal_time = 4000,
    flow = "annulus",
    flow_kw = Dict(:strength => 1, :inner_radius => 100, :outer_radius => 200),
    goal_location = [0, 0],
)

annulus =
    get_flow_function("annulus"; strength = 0.45, inner_radius = 100, outer_radius = 200)

num_agents = 100
stats = run_directed_group_with_removal(
    agents,
    domain;
    save_output = true,
    save_dir = datadir(),
)
current_positions = stats["initial_positions"]
headings = stats["headings"]
current_headings = headings[1:num_agents]
updated_headings = headings[(num_agents+1):end]
event_times = stats["event_times"]
prepend!(event_times, 0.0)
agent_updated = stats["agent_updated"]

Base.@kwdef mutable struct Particles
    τ = 0.1
    num_agents = 100
    positions = ones(2, num_agents)
    headings = ones(num_agents)
end

p = Particles(0, 100, current_positions, current_headings, 0)
fig, ax, s = scatter(p.positions[1, :], p.positions[2, :], ms = 3, color = :blue)
# xlims!(0,340)
# ylims!(-60,60)
scatter!(domain.goal_location, ms = 50)

lines!(
    domain.goal_location[1] .+ domain.goal_tolerance * cos.(0:0.01:2π),
    domain.goal_location[2] .+ domain.goal_tolerance * sin.(0:0.01:2π);
    color = :red,
)
plot_flow_field!(
    annulus;
    x = range(-200, stop = 340, length = 300),
    y = range(-200, stop = 200, length = 300),
)
# scatter!(current_positions[1,:], current_positions[2,:], ms=3)


# index = Observable(1)


# p.positions = @lift begin
#     p.τ = event_times[$index+1] - event_times[$index]
#     p.positions = p.positions .+ p.τ .* transpose([cos.(p.headings) sin.(p.headings)])
#     agent_heading = updated_headings[$index]
#     agent_to_update = agent_updated[$index]
#     p.headings[$agent_to_update]  = $agent_heading
# end 


# scatter!(ax, current_positions[1,:], current_positions[2,:], ms=3)
global s_prev = s
record(fig, "test_Makie.mp4", eachindex(event_times[1:end-1]); framerate = 60) do i
    p.τ = event_times[i+1] - event_times[i]
    p.positions = p.positions + p.τ .* transpose([cos.(p.headings) sin.(p.headings)])
    agent_heading = updated_headings[i]
    agent_to_update = agent_updated[i]
    # println(length(p.headings))
    # println(agent_to_update)
    p.headings[agent_to_update] = agent_heading
    global s_prev
    delete!(ax, s_prev)
    s = scatter!(
        p.positions[1, :],
        p.positions[2, :],
        ms = 3,
        color = :blue,
        axis = (names = (title = event_times[i],),),
    )
    s_prev = s

    arrived, dist_to_goal =
        check_arrivals(p.positions, domain.goal_location, domain.goal_tolerance)
    p.positions = p.positions[:, .!arrived]
    p.headings = p.headings[.!arrived]
end


# particles = Particles(current_headings = current_headings, current_positions=current_positions)

# anim = Animation();
anim = @animate for i in eachindex(event_times[1:100])
    # p = plot(xlim=(0,320),ylim=(-50,50));
    τ = event_times[i+1] - event_times[i]
    global current_positions =
        current_positions + τ .* transpose([cos.(current_headings) sin.(current_headings)])
    global current_headings[agent_updated[i]] = updated_headings[i]
    scatter!(p, current_positions[1, :], current_positions[2, :], ms = 3)
    # frame(anim)
end
gif(anim, "test_agents_3.gif", fps = 30)


# positions = readdlm("positions_2021_11_25_15_10_14.tsv");
# positions = readdlm("positions_2021_11_30_15_14_17.tsv");
positions = readdlm(datadir("positions_2021_11_30_15_14_17.tsv"));

positions = readdlm(
    datadir(
        "flow=smooth_vertical_stream_num_agents=100_sensing_range=20_terminal_time=1000.tsv",
    ),
)

positions = readdlm(datadir("test_nearest.tsv"));
fig, ax, s = scatter(
    convert(Vector{Float64}, positions[1, :]),
    convert(Vector{Float64}, positions[2, :]),
    ms = 3,
    color = :blue,
)
domain.goal_location = [100, 0]
scatter!(tuple(domain.goal_location...), ms = 50)

lines!(
    domain.goal_location[1] .+ domain.goal_tolerance * cos.(0:0.01:2π),
    domain.goal_location[2] .+ domain.goal_tolerance * sin.(0:0.01:2π);
    color = :red,
)
vert_stream = get_flow_function(
    "smooth_vertical_stream";
    w_1 = 150,
    w_2 = 200,
    strength = 0.5,
    noise = 0.1,
)
plot_flow_field!(
    vert_stream;
    x = range(-210, stop = 210, length = 50),
    y = range(-210, stop = 210, length = 50),
)

ax.autolimitaspect = 1
s_prev = s
record(fig, plotsdir("test_nearest.mp4"), 1:8:size(positions)[1]; framerate = 60) do i
    global s_prev
    delete!(ax, s_prev)
    trim_empty(x) = filter(i -> isa(i, Float64), x)
    x = convert(Vector{Float64}, trim_empty(positions[i, :]))
    y = convert(Vector{Float64}, trim_empty(positions[i+1, :]))
    s = scatter!(x, y, ms = 3, color = :blue)
    s_prev = s
end
