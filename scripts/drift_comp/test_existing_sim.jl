using DrWatson
using DelimitedFiles
@time @quickactivate :CollectiveNavigation
using Pipe: @pipe
@time using CairoMakie

include("../../notebooks/final_figures/theme.jl")
## Angle Flow Intended, simulations that worked previously.
intend_config = SimulationConfig(
    num_repeats=3,
    flow=Dict("type" => "angle", "strength" => 0.2, "angle" => π / 2),
    sensing=Dict("type" => "ranged", "range" => 50.0),
    heading_perception=Dict("type" => "intended"),
    terminal_time=5000,
    χ=0,
);
parse_config!(intend_config);
savename(intend_config)
intend_angle_flow_data = run_experiment_flow_angle(
    intend_config,
    :angle,
    angle_values=collect(0:(π/18):(π/18)),
    show_log=true
)
"""Adjust compensation parameter """
full_comp_config = SimulationConfig(
    num_repeats=3,
    flow=Dict("type" => "angle", "strength" => 0.2, "angle" => π / 2),
    sensing=Dict("type" => "ranged", "range" => 50.0),
    heading_perception=Dict("type" => "ideal"),
    terminal_time=5000,
    χ=1
);
parse_config!(full_comp_config);
full_comp_angle_flow_data = run_experiment_flow_angle(
    full_comp_config,
    :angle,
    angle_values=collect(0:(π/18):(π/18)),
    show_log=true
)
# full_comp_df = decompress_data(full_comp_angle_flow_data; show_progress=false);
# full_comp_angle_flow_data = nothing;

"""Adjust to intended headings """
intend_comp_config = SimulationConfig(
    num_repeats=3,
    flow=Dict("type" => "angle", "strength" => 0.2, "angle" => π / 2),
    sensing=Dict("type" => "ranged", "range" => 50.0),
    heading_perception=Dict("type" => "intended"),
    terminal_time=5000,
    χ=1
);
parse_config!(intend_comp_config);
intend_comp_angle_flow_data = run_experiment_flow_angle(
    intend_comp_config,
    :angle,
    angle_values=collect(0:(π/18):(π/18)),
    show_log=true
)
# intend_comp_df = decompress_data(intend_comp_angle_flow_data; show_progress=false);
# intend_comp_angle_flow_data = nothing;

# df = vcat(intend_df, full_comp_df, intend_comp_df)
# intended_df = decompress_data(intended_data; show_progress=true);
# Add ideal data as a step two. First aim is to plot just intended headings
realisation = subset(intend_angle_flow_data, :lw_config => ByRow(x -> (x.sensing["range"] .== 50.0) & (x.flow["angle"] == 0.0) & (x.χ == 0.0)));
config = realisation.lw_config[1];
positions = readdlm(joinpath(config.save_dir, config.save_name * ".tsv"));
positions[positions.==""] .= 0;
positions = convert.(Float64, positions);
x_pos = positions[1:2:end, :];
y_pos = positions[2:2:end, :];

full_comp_config = SimulationConfig(
    num_repeats=3,
    flow=Dict("type" => "angle", "strength" => 0.2, "angle" => π / 2),
    sensing=Dict("type" => "ranged", "range" => 50.0),
    heading_perception=Dict("type" => "intended"),
    terminal_time=5000,
    χ=1.0
);
parse_config!(full_comp_config);
full_comp_angle_flow_data = run_experiment_flow_angle(
    full_comp_config,
    :angle,
    angle_values=collect(0:(π/18):(π/18)),
    show_log=true
)
realisation = subset(full_comp_angle_flow_data, :lw_config => ByRow(x -> (x.sensing["range"] .== 50.0) & (x.flow["angle"] == 0.0) & (x.χ == 1.0)));
ideal_config = realisation.lw_config[1];
ideal_positions = readdlm(joinpath(ideal_config.save_dir, ideal_config.save_name * ".tsv"));
ideal_positions[ideal_positions.==""] .= 0;
ideal_positions = convert.(Float64, ideal_positions);
ideal_x_pos = ideal_positions[1:2:end, :];
ideal_y_pos = ideal_positions[2:2:end, :];


# Scatter agents
sample_size = 50
sample = 1:sample_size
size_pt = 390 .* (1, 0.75)
fig = Figure(resolution=size_pt)
ax1 = CairoMakie.Axis(
    fig[1, 1]; title=L"$\chi = 1, \kappa_1 = \kappa_2 = 1$, Intended compensating (yellow), Intended (blue)"
)
for i in 1:5:minimum(hcat(length(ideal_y_pos[:, 1]), length(y_pos[:, 1])))
    scatter!(
        ax1,
        x_pos[i, sample],
        y_pos[i, sample];
        markersize=1,
        color=intended_color
    )
    scatter!(
        ax1,
        ideal_x_pos[i, sample],
        ideal_y_pos[i, sample];
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

fig
save(String(plotsdir("test", "scatter_traj_intended_χ=1.png")), fig)