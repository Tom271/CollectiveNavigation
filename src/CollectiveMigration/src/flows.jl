function hycom_flow(
    t::Real,
    x::Real,
    y::Real,
    strength::Float64,
    h::Any
)::(Vector{T} where {T<:Real})
    # (x,y,t) are coordinates in data axis, we need to convert
    # to lat/long/date
    long = h.x_to_long(x)
    lat = h.y_to_lat(y)
    unix_t = h.t_to_date(t)
    return (strength / h.max_strength) .* [h.interp_u(long, lat, unix_t); h.interp_v(long, lat, unix_t)]
end

function hycom_flow_mean(
    t::Real,
    x::Real,
    y::Real,
    strength::Float64,
    h::Any
)::(Vector{T} where {T<:Real})
    # (x,y,t) are coordinates in data axis, we need to convert
    # to lat/long/date
    long = h.x_to_long(x)
    lat = h.y_to_lat(y)
    unix_t = h.t_to_date(t)
    return (strength / h.mean_strength) .* [h.interp_u(long, lat, unix_t); h.interp_v(long, lat, unix_t)]
end

function hybrid_flow(
    t::Real,
    x::Real,
    y::Real,
    strength::Float64,
    h::Any # Should be HYCOM_Flow when in package.
)::(Vector{T} where {T<:Real})
    # (x,y,t) are coordinates in data axis, we need to convert
    # to lat/long/date
    long = h.x_to_long(x)
    lat = h.y_to_lat(y)
    unix_t = h.t_to_date(t)
    hycom = (strength / h.max_strength) .* [h.interp_u(long, lat, unix_t); h.interp_v(long, lat, unix_t)]
    linear =
        return
end

function vortex_flow(
    t::Real,
    x::Real,
    y::Real;
    strength::Real=1.0,
    left_bound::Real=0.0,
    right_bound::Real=10.0
)::(Vector{T} where {T<:Real})
    flow = 0.5 * (1 - tanh(0.1 * x^2 + 0.1 * y^2 - 10))

    return flow .* [-0.1 * x - y; x - 0.1 * y]
end

function annulus_flow(
    t::Real,
    x::Real,
    y::Real;
    strength::Real=1.0,
    inner_radius::Real=2.0,
    outer_radius::Real=5.0,
    noise::Real=0.0
)::(Vector{T} where {T<:Real})
    noise_xy = noise .* randn(Float64, 2)
    r = sqrt(x^2 + y^2)
    if r <= inner_radius || r >= outer_radius
        return [0.0; 0.0] + noise_xy
    end

    θ = atan(y, x)
    ϕ = θ + π / 2

    return [strength * cos(ϕ); strength * sin(ϕ)] + noise_xy
end

function vertical_stream(
    t::Real,
    x::Real,
    y::Real;
    strength::Real=1.0,
    left_bound::Real=-10000.0,
    right_bound::Real=10000.0,
    noise::Real=0.0
)::(Vector{T} where {T<:Real})
    noise_xy = noise .* randn(Float64, 2)
    if x <= left_bound || x >= right_bound
        return [0.0; 0.0] + noise_xy
    end
    return [0.0; strength] + noise_xy
end

function smooth_vertical_stream(
    t::Real,
    x::Real,
    y::Real;
    strength::Real=1.0,
    w_1::Real=0.0,
    w_2::Real=0.0,
    noise::Real=0.0
)::(Vector{T} where {T<:Real})
    noise_xy = noise .* randn(Float64, 2)
    return (tanh(x .- w_1) - tanh(x .- w_2)) * [0.0; strength] + noise_xy
end

function horizontal_stream(
    t::Real,
    x::Real,
    y::Real;
    strength::Real=1.0,
    lower_bound::Real=0.0,
    upper_bound::Real=10.0,
    noise::Real=0.0
)::(Vector{T} where {T<:Real})
    noise_xy = noise .* randn(Float64, 2)
    if y <= lower_bound || y >= upper_bound
        return [0.0; 0.0] + noise_xy
    end
    return [strength; 0.0] + noise_xy
end

function constant_angle_flow(t::Real, x::Real, y::Real; strength_x, strength_y)
    return [strength_x; strength_y]
end
# ```
#     get_flow_function(flow_strength::Real)
#     get_flow_function(flow_direction::Vector{T} where T <: Real)
#     get_flow_function(flow_name::String; kw...)
#     get_flow_function(flow_func)

# Get function to evaluate flow at point (t,x,y). 

# If `flow_strength` is passed, function will return flow in the ``x``-direction 
# at that strength. If instead a vector `flow_direction` is given, flow will be
# constant in that direction. `flow_name` finds the function in a dictionary 
# and returns that. Else it is assumed a function has been passed and it will 
# be left unchanged. 
# ```

function get_flow_function(flow_strength::Real; flow_kw...)
    (t, x, y) -> [flow_strength; 0.0]
end

function get_flow_function(flow_direction::Vector{T} where {T<:Real}; flow_kw...)
    (t, x, y) -> flow_direction
end

function get_flow_function(flow::Dict{String,Any})
    flow_name = flow["type"]
    kw::Dict{Symbol,Any} = Dict()
    kw[:strength] = flow["strength"]
    flow_name = lowercase(flow_name)
    flow_functions = Dict{String,Any}(
        "vortex" => (t, x, y) -> vortex_flow(t, x, y; kw...),
        "annulus" => (t, x, y) -> annulus_flow(t, x, y; kw...),
        "vertical_stream" => (t, x, y) -> vertical_stream(t, x, y; kw...),
        "horizontal_stream" => (t, x, y) -> horizontal_stream(t, x, y; kw...),
        "smooth_vertical_stream" => (t, x, y) -> smooth_vertical_stream(t, x, y; kw...),
        "constant" => get_flow_function(flow["strength"]),
        "hycom" => (t, x, y) -> hycom_flow(t, x, y, flow["strength"], flow["config"]),
        "hycom_mean" => (t, x, y) -> hycom_flow_mean(t, x, y, flow["strength"], flow["config"]),
        "hybrid" => (t, x, y) -> (1 - flow["lambda"]) * get_flow_function(flow["strength"]) + flow["lambda"] * hycom_flow(t, x, y, flow["strength"], flow["config"]),
    )
    if flow_name == "angle"
        kw[:angle] = flow["angle"]
        strength_x = kw[:strength] * cos(kw[:angle])
        strength_y = kw[:strength] * sin(kw[:angle])
        flow_functions["angle"] = get_flow_function([strength_x; strength_y]; kw...)
    end
    return flow_functions[flow_name]
end

function get_flow_function(flow_func)
    return (t, x, y) -> flow_func(t, x, y; kw...)
end


function plot_flow_field(flow_func; t=0, x=-10:1:10, y=-10:1:10)
    X = x' .* ones(length(y))
    Y = ones(length(x))' .* y
    # flow_func_tuple = (x,y) -> tuple(flow_func(0,x,y)...)
    flow = flow_func.(0, X, Y)
    u = [flow[i][1] for i in eachindex(flow)]
    v = [flow[i][2] for i in eachindex(flow)]
    println(x)
    n = vec(norm.(Vec2f.(u, v)))
    U = reshape(u, length(y), length(x))
    V = reshape(v, length(y), length(x))
    arrows(vec(Point2f.(X, Y)), vec(Point2f.(U, V)), arrowsize=10 * n, arrowcolour=n)
end

function plot_flow_field!(flow_func; t=0, x=-10:1.0:10, y=-10:1.0:10)
    X = x' .* ones(length(y))
    Y = ones(length(x))' .* y
    # flow_func_tuple = (x,y) -> tuple(flow_func(0,x,y)...)
    flow = flow_func.(0, X, Y)
    u = [flow[i][1] for i in eachindex(flow)]
    v = [flow[i][2] for i in eachindex(flow)]
    println(x)
    n = vec(norm.(Vec2f.(u, v)))
    U = reshape(u, length(y), length(x))
    V = reshape(v, length(y), length(x))
    arrows!(vec(Point2f.(X, Y)), vec(Point2f.(U, V)), arrowsize=10 * n, arrowcolour=n)
end
