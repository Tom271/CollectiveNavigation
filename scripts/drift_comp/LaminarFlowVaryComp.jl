using DrWatson
@time @quickactivate :CollectiveNavigation
using Pipe: @pipe
@time using CairoMakie

include("final_figures/theme.jl")
# Angle Flow Intended
intend_config = SimulationConfig(
    num_repeats=50,
    flow=Dict("type" => "angle", "strength" => 0.2, "angle" => π / 2), # cross flow
    sensing=Dict("type" => "ranged", "range" => 50.0),
    heading_perception=Dict("type" => "intended"),
    terminal_time=5000,
    χ=0
);
parse_config!(intend_config);
intend_angle_flow_data = run_experiment_flow_angle(
    intend_config,
    :angle,
    angle_values=collect(0:(π/18):(35π/18)),
    show_log=true
)
# intend_df = decompress_data(intend_angle_flow_data; show_progress=false);
# intend_angle_flow_data = nothing;

# actual_config = intend_config;
# actual_config.heading_perception["type"] = "actual"
# actual_angle_flow_data = run_experiment_flow_angle(
#     actual_config,
#     :angle,
#     angle_values=collect(0:(π/18):(35π/18)),
#     show_log=true
# )

# actual_df = decompress_data(actual_angle_flow_data; show_progress=false);
# actual_angle_flow_data = nothing;

# # Stack them together to get a complete dataset
# df = vcat(intend_df, actual_df)
# (intend_df, actual_df) = (nothing, nothing)

# perc_type = "intended"
# int_arrival_times = @pipe df |>
#                           subset(_, :heading_perception => ByRow(==(perc_type))) |>
#                           get_arrival_times(_, [:flow_angle, :flow_strength]) |>
#                           get_centile_arrival(_; centile=50) |>
#                           make_failures_explicit(_, df, [:flow_angle, :flow_strength])
# int_arrival_times[!, "heading_perception"] .= "intended"
# int_arrival_times[!, "heading_perception_code"] .= 1
# perc_type = "actual"
# act_arrival_times = @pipe df |>
#                           subset(_, :heading_perception => ByRow(==(perc_type))) |>
#                           get_arrival_times(_, [:flow_angle, :flow_strength]) |>
#                           get_centile_arrival(_; centile=50) |>
#                           make_failures_explicit(_, df, [:flow_angle, :flow_strength])
# act_arrival_times[!, "heading_perception"] .= "actual"
# act_arrival_times[!, "heading_perception_code"] .= 2
# arrival_times = vcat(int_arrival_times, act_arrival_times)
# jldsave(datadir("AngleFlow.jld2");arrival_times)
arrival_times = load(datadir("AngleFlow.jld2"), "arrival_times")
int_arrival_times = @pipe arrival_times |>
                          subset(_, :heading_perception => ByRow(==("intended"))) |>
                          select(_, [:flow_angle, :heading_perception, :arrival_time_mean])
act_arrival_times = @pipe arrival_times |>
                          subset(_, :heading_perception => ByRow(==("actual"))) |>
                          select(_, [:flow_angle, :heading_perception, :arrival_time_mean])

percent_diff = @pipe leftjoin(
                         int_arrival_times,
                         act_arrival_times;
                         on=:flow_angle, makeunique=true) |>
                     transform(
                         _,
                         [:arrival_time_mean, :arrival_time_mean_1] =>
                             ((x, y) -> (100 .* (x .- y) ./ y)) =>
                                 :difference
                     ) |>
                     select(_, [:flow_angle, :difference])


