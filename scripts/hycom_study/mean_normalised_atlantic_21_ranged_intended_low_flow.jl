using DrWatson
@quickactivate :CollectiveNavigation
using Interpolations, NetCDF, Dates
using CairoMakie
using Pipe: @pipe
using PerceptualColourMaps
include("../../notebooks/final_figures/theme.jl")
size_pt = (390, 390)
fig = CairoMakie.Figure(resolution=size_pt)

### WORKFLOW 
# Build data structure
params = HYCOM_Parameters(
    name="n_atlantic_sei_whale_correct",
    start_time="2021-04-13T00:00:00Z",
    end_time="2021-06-07T00:00:00Z",
    min_lat=34.00,
    max_lat=59.76,
    min_long=321.76,
    max_long=332.08,
);
# Download/Load data
flow_config, dl_path = get_flow_data(params);
h = HYCOM_Flow_Data(params)
h, params = sanitise_flow_data!(params, dl_path)
build_interpolants!(h)

flow_dic = Dict(
    "type" => "hycom_mean",
    "strength" => 1.0,
    "config" => h
);

config = SimulationConfig(
    num_repeats=25,
    flow=flow_dic,
    sensing=Dict("type" => "ranged", "range" => 0.0),
    heading_perception=Dict("type" => "intended"),
    terminal_time=5000,
);
parse_config!(config);
#### RUN EXPERIMENT
sensing_values = [0.0, 1.0, 2.0, 3.0, 5.0, 10.0, 20.0, 50.0, 500.0];
## Run simulation or load data from file if it exists.
hycom_flow_data = run_experiment(
    config,
    :flow,
    :sensing;
    flow_values=collect(0.0:0.05:0.25),  # [0.0, collect(5:2.0:10)...],
    sensing_values=sensing_values,
    show_log=true
)
@info "Decompressing..."
df = decompress_data(hycom_flow_data)
arrival_times = @pipe df |>
                      get_arrival_times(_, [:sensing_range, :flow_strength]);
median_arrival = get_centile_arrival(arrival_times; centile=50);
full_arrival_times = make_failures_explicit(median_arrival, df, [:sensing_range, :flow_strength]);
using JLD2
jldsave(datadir("LowFlowHYCOM_intended_ranged.jld2"); full_arrival_times)

arrival_times = full_arrival_times
arrival_times.heading_perception .= "intended"
arrival_times.sensing_type .= "ranged"
ref_point = @pipe arrival_times |>
                  subset(
    _,
    :heading_perception => ByRow(==("intended")),
    :sensing_range => ByRow(==(0)),
    :flow_strength => ByRow(==(0))
)
no_flow_mean = ref_point[1, :arrival_time_mean]

colorrange = log(no_flow_mean) .+ (-1.25, 1.25)
color_length = 2.5 #(colorrange[end]-colorange[begin])
palette = cgrad(hm_colors)
cbar_range = palette[((log(500):0.1:colorrange[2]).-colorrange[1])./2.5]

c = Colorbar(
    fig[2, 1],
    colormap=hm_colors,
    colorrange=log(no_flow_mean) .+ (-0.2, 0.2),
    label="Arrival Time",
    tickformat=xs -> ["$(round(Int64,exp(x)))" for x in xs],
    ticks=log.(500:50:750),
    vertical=false,
    flipaxis=false,
    size=10
)
c.labelpadding = -2
ylabels = nothing

sensing, perc = ("ranged", "intended")
df = subset(arrival_times, :heading_perception => ByRow(==(perc)),
    :sensing_type => ByRow(==(sensing)))
xlabels = unique(df[!, :flow_strength])
ylabels = unique(df[!, :sensing_range])
ax = CairoMakie.Axis(
    fig[1, 1];
    xlabel="Flow Strength",
    ylabel="Sensing Range",
    xticks=(1:length(xlabels), string.(xlabels)),
    yticks=(1:length(ylabels), string.(ylabels))
)
sort!(df, [:sensing_range, :flow_strength])
Z = reshape(df[!, :arrival_time_mean], (length(xlabels), length(ylabels)))
solo_nav = @pipe df |>
                 subset(
                     _,
                     :sensing_range => ByRow(==(0))
                 ) |>
                 select(_, :flow_strength, :arrival_time_mean) |>
                 rename(_, :arrival_time_mean => :solo_time) |>
                 #map missing dta to 5000
                 coalesce.(_, 5000)

test = @pipe df |>
             leftjoin(_, solo_nav, on=:flow_strength) |>
             coalesce.(_, 5000)
test2 = transform(
    test,
    [:arrival_time_mean, :solo_time] =>
        ByRow((x, y) -> (x < y ? "*" : " ")) =>
            :better
)
hm = CairoMakie.heatmap!(
    ax,
    1:length(xlabels),
    1:length(ylabels),
    log.(Z);
    colormap=hm_colors,
    colorrange=log(no_flow_mean) .+ (-0.2, 0.2)
)
Z = convert.(Int64, round.(Z))

normalZ = Z ./ ref_point[1, :arrival_time_mean]
normalZ = [ismissing(i) ? 0 : i for i ∈ normalZ]

normalised = true

labels = string.(normalised ? round.(normalZ, sigdigits=2) : Z)
text!(
    labels[:],
    position=Point.((1:length(xlabels)), (1:length(ylabels))')[:],
    align=(:center, :baseline),
    color=:white,
    fontsize=14,
    font=:bold
)
# labels = string.(test2[!, :better])
# text!(ax,
#     labels[:],
#     position=Point.((1:length(xlabels)), ((1:length(ylabels)) .- 0.55)')[:],
#     align=(:center, :baseline),
#     color=:white,
#     fontsize=14,
#     font=:bold
#     # fontsize=normalised ? 20 : 15
# )
hlines!(ax, 1.5; color=:white, linewidth=1.5)
vlines!(ax, 1.5; color=:white, linewidth=1.5)
# ax.aspect = 1
ax.ylabelpadding = 1
push!(ax_list, ax)

# rowsize!(fig.layout,1,Aspect(1,1.25))
# rowsize!(fig.layout,2,Relative(0.1))
save(String(plotsdir("hycom_flow_ranged_intended_low_flow_heatmap.png_v2.svg")), fig, pt_per_unit=1)
fig