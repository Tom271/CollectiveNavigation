using DrWatson
using DelimitedFiles
@time @quickactivate :CollectiveNavigation
using Pipe: @pipe
@time using CairoMakie

include("../../notebooks/final_figures/theme.jl")
angle = pi
h1 = "actual"
h2 = "actual"
## intended without drift compensation
intend_config = SimulationConfig(
    num_repeats=1,
    flow=Dict("type" => "angle", "strength" => 0.2, "angle" => π / 2),
    sensing=Dict("type" => "ranged", "range" => 50.0),
    heading_perception=Dict("type" => h1),
    terminal_time=5000,
    χ=0,
);
parse_config!(intend_config);
savename(intend_config)
intend_data = run_experiment_flow_angle(
    intend_config,
    :angle,
    angle_values=[angle],
    show_log=true
)
## intended with drift compensation
slight_comp_config = SimulationConfig(
    num_repeats=1,
    flow=Dict("type" => "angle", "strength" => 0.2, "angle" => 0.0),
    sensing=Dict("type" => "ranged", "range" => 50.0),
    heading_perception=Dict("type" => h2),
    terminal_time=5000,
    χ=0.2
);
parse_config!(slight_comp_config);
slight_comp_data = run_experiment_flow_angle(
    slight_comp_config,
    :angle,
    angle_values=[angle],
    show_log=true
)
# full_comp_df = decompress_data(full_comp_angle_flow_data; show_progress=false);
# full_comp_angle_flow_data = nothing;

# # intended without drift compensation
# intended_config = SimulationConfig(
#     num_repeats=1,
#     flow=Dict("type" => "angle", "strength" => 0.2, "angle" => π / 2),
#     sensing=Dict("type" => "ranged", "range" => 50.0),
#     heading_perception=Dict("type" => "intended"),
#     terminal_time=5000,
#     χ=0
# );
# parse_config!(intended_config);
# intended_data = run_experiment_flow_angle(
#     intended_config,
#     :angle,
#     angle_values=[0],
#     show_log=true
# )

# # intended with drift compensation
# intended_comp_config = SimulationConfig(
#     num_repeats=1,
#     flow=Dict("type" => "angle", "strength" => 0.2, "angle" => π / 2),
#     sensing=Dict("type" => "ranged", "range" => 50.0),
#     heading_perception=Dict("type" => "intended"),
#     terminal_time=5000,
#     χ=0.2
# );
# parse_config!(intended_comp_config);
# intended_data = run_experiment_flow_angle(
#     intended_comp_config,
#     :angle,
#     angle_values=[0],
#     show_log=true
# )
# intend_comp_df = decompress_data(intend_comp_angle_flow_data; show_progress=false);
# intend_comp_angle_flow_data = nothing;

# df = vcat(intend_df, full_comp_df, intend_comp_df)
# intended_df = decompress_data(intended_data; show_progress=true);
# Add intended data as a step two. First aim is to plot just intended headings
realisation = subset(intend_data, :lw_config => ByRow(x -> (x.sensing["range"] .== 50.0) & (x.flow["angle"] == angle) & (x.χ == 0.0)));
config = realisation.lw_config[1];
positions = readdlm(joinpath(config.save_dir, config.save_name * ".tsv"));
positions[positions.==""] .= 0;
positions = convert.(Float64, positions);
x_pos = positions[1:2:end, :];
y_pos = positions[2:2:end, :];

# full_comp_config = SimulationConfig(
#     num_repeats=1,
#     flow=Dict("type" => "angle", "strength" => 0.2, "angle" => 0),
#     sensing=Dict("type" => "ranged", "range" => 50.0),
#     heading_perception=Dict("type" => "intended"),
#     terminal_time=5000,
#     χ=0.2
# );
# parse_config!(full_comp_config);
# full_comp_angle_flow_data = run_experiment_flow_angle(
#     full_comp_config,
#     :angle,
#     angle_values=collect(0:(π/2/18):(π/18)),
#     show_log=true
# )
realisation = subset(slight_comp_data, :lw_config => ByRow(x -> (x.sensing["range"] .== 50.0) & (x.flow["angle"] == angle) & (x.χ == 0.2)));
intended_config = realisation.lw_config[1];
intended_positions = readdlm(joinpath(intended_config.save_dir, intended_config.save_name * ".tsv"));
intended_positions[intended_positions.==""] .= 0;
intended_positions = convert.(Float64, intended_positions);
intended_x_pos = intended_positions[1:2:end, :];
intended_y_pos = intended_positions[2:2:end, :];


# Scatter agents
sample_size = 50
sample = 1:sample_size
size_pt = 390 .* (1, 0.75)
fig = Figure(resolution=size_pt)
ax1 = CairoMakie.Axis(
    fig[1, 1]; title="Slightly Compensating, Good Navigation", subtitle="χ = $(intended_config.χ), $(intended_config.heading_perception["type"]) (yellow), χ=$(config.χ), $(config.heading_perception["type"]) (blue)"
)
for i in 1:5:minimum(hcat(length(intended_y_pos[:, 1]), length(y_pos[:, 1])))
    scatter!(
        ax1,
        x_pos[i, sample],
        y_pos[i, sample];
        markersize=1,
        color=intended_color
    )
    scatter!(
        ax1,
        intended_x_pos[i, sample],
        intended_y_pos[i, sample];
        markersize=1,
        color=actual_color
    )
end
for i in 5:-2:1
    scatter!(
        (0, 0);
        markersize=5 * (i + 1),
        color=:white,
        markerspace=:data
    )
    scatter!(
        (0, 0);
        markersize=5 * i,
        color=(:red, 0.8),
        markerspace=:data
    )
end
hidedecorations!(ax1)
hidespines!(ax1)
ax1.aspect = DataAspect()
ϑ = intended_config.flow["angle"]
ζ = intended_config.flow["strength"]
text!([(-190, 150)]; text="ζ=$(ζ)", fontsize=16)
arrows!([-115], [140], [50ζ * cos(ϑ)], [50ζ * sin(ϑ)], arrowsize=10, lengthscale=7.5,)
fig
save(String(plotsdir("test", "scatter_traj_perc=$(intended_config.heading_perception["type"])_χ=$(intended_config.χ)_flow=$(intended_config.flow["strength"])_angle=$(intended_config.flow["angle"]).png")), fig)


intend_df = decompress_data(intend_data)
comp_df = decompress_data(slight_comp_data)

include("../../notebooks/final_figures/theme.jl")
size_pt = (500, 275)
fig2 = CairoMakie.Figure(resolution=size_pt)
ax = Axis(fig2[1, 1]; title="ζ=$(intended_config.flow["strength"]), ϑ = $(round(intended_config.flow["angle"];digits=2))", subtitle="χ = $(intended_config.χ), $(intended_config.heading_perception["type"]) (yellow), χ=$(config.χ), $(config.heading_perception["type"]) (blue)")
lines!(ax, intend_df[!, :coarse_time], intend_df[!, :individuals_remaining])

lines!(comp_df[!, :coarse_time], comp_df[!, :individuals_remaining])
xlims!(0, 1500)
fig2