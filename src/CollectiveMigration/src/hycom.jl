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
    mean_strength::Float64 = 1.0
    interp_u::Any = nothing
    interp_v::Any = nothing
    x_to_long::Any = nothing
    y_to_lat::Any = nothing
    t_to_date::Any = nothing
    HYCOM_Flow_Data(params) = new(params, nothing, 1.0, 1.0, nothing, nothing, nothing, nothing, "")
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
    of the total download size, hence `total` not being used here.
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
        open(String(datadir("flow_data", "$(h.name).json")), "r") do io
            config = read(io, String)
        end
        @info "Name already used, config is: \n $(JSON.parse(config))"
        dl_path = String(datadir("flow_data", "$(h.name).nc"))
        return (config, dl_path)
    else
        # Dowload data using query and return path to saved file
        build_api_query!(h)
        dl_path = Downloads.download(h.api_query, datadir("flow_data\\$(h.name).nc"); progress=prog_bar)
        open(String(datadir("flow_data", "$(h.name).json")), "w") do io
            write(io, json(h))
        end
        return (json(h), dl_path)
    end
end

function sanitise_flow_data!(params::HYCOM_Parameters, dl_path::String)::Tuple
    h = HYCOM_Flow_Data(params)

    # Load data, shape is (long, lat, lev, time) -> (x,y,z,t) 
    u_vel = ncread(dl_path, "water_u")
    v_vel = ncread(dl_path, "water_v")
    # Check for missing values (encoded as -30,000)
    u_missing = sum(u_vel .== -30000)
    v_missing = sum(v_vel .== -30000)
    # Drop LEV, take only highest data level
    v_vel = v_vel[:, :, 1, :]
    u_vel = u_vel[:, :, 1, :]
    # Set missing values to zero flow
    u_vel[u_vel.==-30000] .= 0.0
    v_vel[v_vel.==-30000] .= 0.0

    @info "There are $(u_missing) missing values in u_vel, $(round(100*u_missing/length(u_vel); digits=2))% of the total"
    @info "There are $(v_missing) missing values in v_vel, $(round(100*v_missing/length(v_vel); digits=2))% of the total"

    h.max_strength = sqrt.(maximum(u_vel .^ 2 + v_vel .^ 2))
    h.mean_strength = mean(sqrt.(u_vel .^ 2 + v_vel .^ 2))
    @info "Mean flow strength is $(h.mean_strength)"
    lat = ncread(dl_path, "latitude")
    long = ncread(dl_path, "longitude")
    h.params.min_long = minimum(long)
    h.params.max_long = maximum(long)
    h.params.min_lat = minimum(lat)
    h.params.max_lat = maximum(lat)
    timestamp = ncread(dl_path, "time")

    # Build matrix of (x,y,t,u,v)

    h.raw = [long, lat, timestamp, u_vel, v_vel]
    params.min_long = minimum(long)
    params.max_long = maximum(long)
    params.min_lat = minimum(lat)
    params.max_lat = maximum(lat)

    return (h, params)
end

function build_t_map(h::HYCOM_Parameters)::Function
    end_date = DateTime(h.end_time, "yyyy-mm-ddTHH:MM:SSZ")
    start_date = DateTime(h.start_time, "yyyy-mm-ddTHH:MM:SSZ")
    elapsed_time = datetime2unix(end_date) - datetime2unix(start_date)
    map_t_to_date(t) = datetime2unix(end_date) - (elapsed_time .* (5000 - t) / 5000)
    return map_t_to_date
end

function build_x_to_long_map(params::HYCOM_Parameters)
    # max_x = 400
    # min_x = -50
    max_x = 75
    min_x = -75
    map_x_to_long(x) = params.max_long - ((params.max_long - params.min_long) .* (max_x - x) / (max_x - min_x))
    return map_x_to_long
end
function build_y_to_lat_map(params::HYCOM_Parameters)
    # max_y = 75
    # min_y = -75
    max_y = 400
    min_y = -50
    map_y_to_lat(y) = params.max_lat - ((params.max_lat - params.min_lat) .* (max_y - y) / (max_y - min_y))
    return map_y_to_lat
end

function build_interpolants!(h::HYCOM_Flow_Data)
    long, lat, timestamp, u_vel, v_vel = h.raw
    long_step = 0.08
    long_range = long[begin]:long_step:(long[end]+long_step)
    lat_step = 0.04
    lat_range = lat[begin]:lat_step:(lat[end]+lat_step)
    timestamp_step = (timestamp[2] - timestamp[1])
    timestamp_range = timestamp[begin]:timestamp_step:(timestamp[end])
    interp_u = CubicSplineInterpolation((long_range, lat_range, timestamp_range), u_vel; extrapolation_bc=Periodic())
    interp_v = CubicSplineInterpolation((long_range, lat_range, timestamp_range), v_vel; extrapolation_bc=Periodic())

    h.interp_u = interp_u
    h.interp_v = interp_v

    h.y_to_lat = build_y_to_lat_map(h.params)
    h.x_to_long = build_x_to_long_map(h.params)
    h.t_to_date = build_t_map(h.params)
end
