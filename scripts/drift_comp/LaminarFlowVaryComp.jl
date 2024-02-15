using DrWatson
@time @quickactivate :CollectiveNavigation
using Pipe: @pipe
@time using CairoMakie

include("../../notebooks/final_figures/theme.jl")
# Angle Flow Intended
intend_config = SimulationConfig(
    num_repeats=20,
    flow=Dict("type" => "angle", "strength" => 0.2, "angle" => π / 2), # cross flow
    sensing=Dict("type" => "ranged", "range" => 50.0),
    heading_perception=Dict("type" => "intended"),
    terminal_time=5000,
    χ=0
);
parse_config!(intend_config);
intend_comp_flow_data = run_experiment_flow_comp(
    intend_config,
    :flow, :χ,
    flow_values=0:0.1:0.5,
    comp_values=0:0.1:0.5,
    show_log=true
)
intend_df = decompress_data(intend_comp_flow_data; show_progress=false);
intend_comp_flow_data = nothing;


actual_config = intend_config;
actual_config.heading_perception["type"] = "actual"
actual_angle_flow_data = run_experiment_flow_comp(
    actual_config,
    :flow, :χ,
    flow_values=0:0.1:0.5,
    comp_values=0:0.1:0.5,
    show_log=true
)

actual_df = decompress_data(actual_angle_flow_data; show_progress=false);
actual_angle_flow_data = nothing;

# # Stack them together to get a complete dataset
df = vcat(intend_df, actual_df)
(intend_df, actual_df) = (nothing, nothing)

perc_type = "intended"
int_arrival_times = @pipe df |>
                          subset(_, :heading_perception => ByRow(==(perc_type))) |>
                          get_arrival_times(_, [:χ, :flow_strength]) |>
                          get_centile_arrival(_; centile=50) |>
                          make_failures_explicit(_, df, [:χ, :flow_strength])
int_arrival_times[!, "heading_perception"] .= "intended"
int_arrival_times[!, "heading_perception_code"] .= 1
perc_type = "actual"
act_arrival_times = @pipe df |>
                          subset(_, :heading_perception => ByRow(==(perc_type))) |>
                          get_arrival_times(_, [:χ, :flow_strength]) |>
                          get_centile_arrival(_; centile=50) |>
                          make_failures_explicit(_, df, [:χ, :flow_strength])
act_arrival_times[!, "heading_perception"] .= "actual"
act_arrival_times[!, "heading_perception_code"] .= 2
# arrival_times = vcat(int_arrival_times, act_arrival_times)
# jldsave(datadir("AngleFlow.jld2");arrival_times)
# arrival_times = load(datadir("AngleFlow.jld2"), "arrival_times")
arrival_times = int_arrival_times
logged = true
size_pt = 420 .* (1.2, 1)
# 
xlabels = unique(arrival_times[!, :flow_strength])
ylabels = unique(arrival_times[!, :χ])
sort!(arrival_times, [:χ, :flow_strength])
Z = reshape(arrival_times[!, :arrival_time_mean], (length(xlabels), length(ylabels)))
limits = extrema(skipmissing(Z))
fig = CairoMakie.Figure(resolution=size_pt)
ax1 = CairoMakie.Axis(
    fig[1, 1];
    xlabel="Flow Strength",
    ylabel="χ",
    xticks=(1:length(xlabels), string.(xlabels)),
    yticks=(1:length(ylabels), string.(ylabels))
)
hm = CairoMakie.heatmap!(ax1,
    1:length(xlabels),
    1:length(ylabels),
    logged ? log.(Z) : Z;
    colormap=cmap("D4"),
    colorrange=log.(limits))
normalised = true
ref_point = @pipe arrival_times |>
                  subset(
    _,
    :χ => ByRow(==(0)),
    :flow_strength => ByRow(==(0))
)
normalZ = Z ./ ref_point[1, :arrival_time_mean]
normalZ = [ismissing(i) ? 0 : i for i ∈ normalZ]
labels = string.(normalised ? round.(normalZ, sigdigits=2) : Z)
text!(
    labels[:],
    position=Point.((1:length(xlabels)), (1:length(ylabels))')[:],
    align=(:center, :baseline),
    color=:white,
    fontsize=10
    # fontsize=normalised ? 20 : 15
)
c = Colorbar(
    fig[1, 2],
    colormap=cmap("D4"),
    colorrange=log.(limits),
    label="Arrival Time",
    tickformat=xs -> ["$(round(Int64,exp(x)))" for x in xs]
)
fig
save(String(plotsdir("drift_comp", "perc_type=$(perc_type)_heatmap.svg")), fig, pt_per_unit=1)