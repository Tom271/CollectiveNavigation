using DrWatson
@quickactivate :CollectiveNavigation
using NetCDF, Dates, Downloads, Interpolations, JSON
using Pipe: @pipe
Base.@kwdef mutable struct HYCOM_Flow
    name::String = "null"
    max_lat::Float64 = 57.67
    min_lat::Float64 = 43.5
    min_long::Float64 = 360 - 39.5
    max_long::Float64 = 360 - 19.8
    min_lev::Float64 = 0.0
    max_lev::Float64 = 0.0
    max_strength::Float64 = 1.0
    start_time::String = "2005-04-13T00:00:00Z"
    end_time::String = "2005-06-07T00:00:00Z"
    filetype::String = "nc"
    interp_u::Any = nothing
    interp_v::Any = nothing
    x_to_long::Any = nothing
    y_to_lat::Any = nothing
    t_to_date::Any = nothing
end
function get_flow_data(h::HYCOM_Flow)
    prog_bar(total::Int, now::Int) = print("\r $(round(now/1000000, digits=1))MB downloaded")

    query = "http://apdrc.soest.hawaii.edu/erddap/griddap/hawaii_soest_a2d2_f95d_0258.$(h.filetype)?water_u[($(h.start_time)):1:($(h.end_time))][($(h.min_lev)):1:($(h.max_lev))][($(h.min_lat)):1:($(h.max_lat))][($(h.min_long)):1:($(h.max_long))],water_v[($(h.start_time)):1:($(h.end_time))][($(h.min_lev)):1:($(h.max_lev))][($(h.min_lat)):1:($(h.max_lat))][($(h.min_long)):1:($(h.max_long))]"

    if isfile(datadir("flow_data", "$(h.name).nc")) | isfile(datadir("flow_data", "$(h.name).json"))
        config = nothing
        open(datadir("flow_data", "$(h.name).json"), "r") do io
            config = read(io, String)
        end
        @info "Name already used, config is: \n $(JSON.parse(config))"
        dl_path = datadir("flow_data", "$(h.name).nc")
        return (config, dl_path)
    else
        dl_path = Downloads.download(query, datadir("$(h.name).nc"); progress=prog_bar)
        open(datadir("flow_data", "$(h.name).json"), "w") do io
            write(io, json(h))
        end
        return (json(h), dl_path)
    end
end

h = HYCOM_Flow(
    name="n_atlantic_sei_whale",
    start_time="2005-04-13T00:00:00Z",
    end_time = "2005-06-07T00:00:00Z",
    min_lat=33.99931,
    max_lat=59.77051,
    min_long=360 - 27.88356,
    max_long=360 - 21.36017);
config, dl_path = get_flow_data(h);

##### Wrap these as their own function
u_vel = ncread(dl_path, "water_u");
v_vel = ncread(dl_path, "water_v");
# Drop LEV # Rotate 90 degrees
v_vel = u_vel[:, :, 1, :]
u_vel = v_vel[:, :, 1, :]
h.max_strength = sqrt.(maximum(u_vel .^ 2 + v_vel .^ 2))

lat = ncread(dl_path, "latitude");
long = ncread(dl_path, "longitude");
timestamp = ncread(dl_path, "time");

# Interpolate flow data, again wrap this up as a function
# include in prevuous function with extra flag of add_interps or something
long_step = (long[2] - long[1])
long_range = long[begin]:long_step:(long[end]+long_step)
lat_step = (lat[2] - lat[1])
lat_range = lat[begin]:lat_step:(lat[end]+lat_step)
timestamp_step = (timestamp[2] - timestamp[1])
timestamp_range = timestamp[begin]:timestamp_step:(timestamp[end])
interp_u = CubicSplineInterpolation((long_range, lat_range, timestamp_range), u_vel);
interp_v = CubicSplineInterpolation((long_range, lat_range, timestamp_range), v_vel);

h.interp_u = interp_u;
h.interp_v = interp_v;

function build_t_map(h::HYCOM_Flow)::Function
    end_date = DateTime(h.end_time, "yyyy-mm-ddTHH:MM:SSZ")
    start_date = DateTime(h.start_time, "yyyy-mm-ddTHH:MM:SSZ")
    elapsed_time = datetime2unix(end_date) - datetime2unix(start_date)
    map_t_to_date(t) = datetime2unix(end_date) - (elapsed_time .* (5000 - t) / 5000)
    return map_t_to_date
end

function build_x_to_long_map(h::HYCOM_Flow)
    max_x = 400
    min_x = -50
    map_x_to_long(x) = h.max_long - ((h.max_long - h.min_long) .* (max_x - x) / (max_x - min_x))
    return map_x_to_long
end
function build_y_to_lat_map(h::HYCOM_Flow)
    max_y = 75
    min_y = -75
    map_y_to_lat(y) = h.max_lat - ((h.max_lat - h.min_lat) .* (max_y - y) / (max_y - min_y))
    return map_y_to_lat
end

h.y_to_lat = build_y_to_lat_map(h);
h.x_to_long = build_x_to_long_map(h);
h.t_to_date = build_t_map(h);

#####
flow_dic = Dict(
    "type" => "hycom",
    "strength" => 1.0,
    "config" => h
);

config = SimulationConfig(
    num_repeats=10,
    flow=flow_dic,
    sensing=Dict("type" => "ranged", "range" => 0.0),
    heading_perception=Dict("type" => "intended"),
    terminal_time=5000,
);
sensing_values = [0.0, 1.0, 2.0, 3.0, 5.0, 10.0, 20.0, 50.0, 500.0];
parse_config!(config);
## Run simulation or load data from file if it exists.
hycom_flow_data = run_experiment(
    config,
    :flow,
    :sensing;
    flow_values=0.0:0.1:0.5,
    sensing_values=sensing_values,
    show_log=true
)
@info "Decompressing..."
df = decompress_data(hycom_flow_data)
## REALISATIONS
sr = 500.0
reduced_df = @pipe df |>
                #    subset(
                #        _,
                #        :sensing_range => x -> x .== (sr),
                #    ) |>
                   groupby(_, [:sensing_range, :trial]);
f = Figure()
ax = Axis(f[1, 1], xlabel="Time", ylabel="Individuals Remaining",
    title="Sensing Range = $(sr), Trials = $(maximum(df[!,:trial]))")
for trial in reduced_df
    lines!(
        trial[!, :coarse_time],
        trial[!, :individuals_remaining];
        label=string(trial[!, :trial][1]),
        color=:slategray,
        linewidth=0.5
    )
end

arrival_times = @pipe df |>
                      get_arrival_times(_, [:sensing_range, :flow_strength]);
median_arrival = get_centile_arrival(arrival_times; centile=50);
full_arrival_times = make_failures_explicit(median_arrival, df, [:sensing_range, :flow_strength]);
arrival_times = full_arrival_times
xlabels = unique(arrival_times[!, :flow_strength])
ylabels = unique(arrival_times[!, :sensing_range])
sort!(arrival_times, [:sensing_range, :flow_strength])
Z = reshape(arrival_times[!, :arrival_time_mean], (length(xlabels), length(ylabels)))
logged=true
normalised=true
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
    ref_point = @pipe arrival_times |>
                      subset(
        _,
        :sensing_range => ByRow(==(0)),
        :flow_strength => ByRow(==(0.0))
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