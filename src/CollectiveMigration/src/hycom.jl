using DrWatson
@quickactivate :CollectiveNavigation
using NetCDF, Dates, Downloads, Interpolations, JSON

Base.@kwdef mutable struct HYCOM_Parameters
    name::String = "null"
    max_lat::Float64 = 57.67
    min_lat::Float64 = 43.5
    min_long::Float64 = 360 - 39.5
    max_long::Float64 = 360 - 19.8
    min_lev::Float64 = 0.0
    max_lev::Float64 = 0.0
   
    start_time::String = "2015-04-13T00:00:00Z"
    end_time::String = "2015-06-07T00:00:00Z"
    filetype::String = "nc"
    api_query::String = ""
end

Base.@kwdef mutable struct HYCOM_Flow_Data
    params::HYCOM_Parameters
    raw::Any = nothing
    max_strength::Float64 = 1.0
    interp_u::Any = nothing
    interp_v::Any = nothing
    x_to_long::Any = nothing
    y_to_lat::Any = nothing
    t_to_date::Any = nothing
    HYCOM_Flow_Data(params) = new(params, nothing, 1.0, nothing,nothing,nothing,nothing,"")
end 

function build_api_query!(h::HYCOM_Parameters) 
    """ Construct the query for the HYCOM API 
    Default format taken from HYCOM website. Note that the stride is set to 1 by
    default for all dimensions.
    """
    h.api_query = "http://apdrc.soest.hawaii.edu/erddap/griddap/hawaii_soest_a2d2_f95d_0258.$(h.filetype)?water_u[($(h.start_time)):1:($(h.end_time))][($(h.min_lev)):1:($(h.max_lev))][($(h.min_lat)):1:($(h.max_lat))][($(h.min_long)):1:($(h.max_long))],water_v[($(h.start_time)):1:($(h.end_time))][($(h.min_lev)):1:($(h.max_lev))][($(h.min_lat)):1:($(h.max_lat))][($(h.min_long)):1:($(h.max_long))]"
end

function prog_bar(total::Int, now::Int)
    """Helper function for downloads
    Indicates how many MB have been downlaoded. Note that the HYCOM API sends no indication
    of the total downlaod size, hence `total` not being used here.
    """
     print("\r $(round(now/1000000, digits=1))MB downloaded")
end

function file_exists(h::HYCOM_Parameters)::Bool
    isfile(datadir("flow_data", "$(h.name).nc")) | isfile(datadir("flow_data", "$(h.name).json"))
end

function get_flow_data(h::HYCOM_Parameters)
    """ Download flow data from HYCOM site
    Uses the HYCOM_FLow structure to query HYCOM API and download flow data. Note that uniqueness is
    only provided by the name of the file. This is not a good design. May be better to create a filename
    from the parameters
    """ 
   
    if file_exists(h)
        # Open file and get data filepath
        config = nothing
        open(datadir("flow_data", "$(h.name).json"), "r") do io
            config = read(io, String)
        end
        @info "Name already used, config is: \n $(JSON.parse(config))"
        dl_path = datadir("flow_data", "$(h.name).nc")
        return (config, dl_path)
    else
        # Dowload data using query and return path to saved file
        build_api_query!(h) 
        dl_path = Downloads.download(h.api_query, datadir("$(h.name).nc"); progress=prog_bar, timeout=30)
        open(datadir("flow_data", "$(h.name).json"), "w") do io
            write(io, json(h))
        end
        return (json(h), dl_path)
    end
end

### WORKFLOW 
# Build data structure
params = HYCOM_Parameters(
    name="n_atlantic_sei_whale",
    start_time="2021-04-13T00:00:00Z",
    end_time = "2021-06-07T00:00:00Z",
    min_lat=33.99931,
    max_lat=59.77051,
    min_long=360 - 27.88356,
    max_long=360 - 21.36017
);
# Download/Load data
config, dl_path = get_flow_data(params);
h = HYCOM_Flow_Data(params)
# Load data, shape is (long, lat, lev, time) -> (x,y,z,t) 
u_vel = ncread(dl_path, "water_u");
v_vel = ncread(dl_path, "water_v");
# Check for missing values (encoded as -30,000)
u_missing = sum(u_vel.==-30000);
v_missing = sum(v_vel.==-30000);
# v_vel = v_vel[:, :, 1, :];
# u_vel = u_vel[:, :, 1, :];
v_vel_rotate = u_vel[:, :, 1, :];
u_vel_rotate = v_vel[:, :, 1, :];
u_vel = u_vel_rotate
v_vel= v_vel_rotate
u_vel[u_vel.==-30000] .= 0.0;
v_vel[v_vel.==-30000] .= 0.0;
@info "There are $(u_missing) missing values in u_vel, $(round(100*u_missing/length(u_vel); digits=2))% of the total"
@info "There are $(v_missing) missing values in v_vel, $(round(100*v_missing/length(v_vel); digits=2))% of the total"

# Drop LEV

h.max_strength = sqrt.(maximum(u_vel .^ 2 + v_vel .^ 2))

lat = ncread(dl_path, "latitude");
long = ncread(dl_path, "longitude");
timestamp = ncread(dl_path, "time");

# Build matrix of (x,y,t,u,v)

h.raw = [long, lat, timestamp, u_vel, v_vel];


function build_t_map(h::HYCOM_Parameters)::Function
    end_date = DateTime(h.end_time, "yyyy-mm-ddTHH:MM:SSZ")
    start_date = DateTime(h.start_time, "yyyy-mm-ddTHH:MM:SSZ")
    elapsed_time = datetime2unix(end_date) - datetime2unix(start_date)
    map_t_to_date(t) = datetime2unix(end_date) - (elapsed_time .* (5000 - t) / 5000)
    return map_t_to_date
end

function build_x_to_long_map(h::HYCOM_Parameters)
    max_x = 400
    min_x = -50
    map_x_to_long(x) = h.max_long - ((h.max_long - h.min_long) .* (max_x - x) / (max_x - min_x))
    return map_x_to_long
end
function build_y_to_lat_map(h::HYCOM_Parameters)
    max_y = 75
    min_y = -75
    map_y_to_lat(y) = h.max_lat - ((h.max_lat - h.min_lat) .* (max_y - y) / (max_y - min_y))
    return map_y_to_lat
end

function build_interpolants!(h::HYCOM_Flow_Data)
    long, lat, timestamp, u_vel, v_vel = h.raw;
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

    h.y_to_lat = build_y_to_lat_map(h.params);
    h.x_to_long = build_x_to_long_map(h.params);
    h.t_to_date = build_t_map(h.params);
end

build_interpolants!(h)

flow_dic = Dict(
    "type" => "hycom",
    "strength" => 1.0,
    "config" => h
);

config = SimulationConfig(
    num_repeats=1,
    flow=flow_dic,
    sensing=Dict("type" => "ranged", "range" => 0.0),
    heading_perception=Dict("type" => "intended"),
    terminal_time=5000,
);
parse_config!(config);

stats = run_realisation(config; save_output=true);
