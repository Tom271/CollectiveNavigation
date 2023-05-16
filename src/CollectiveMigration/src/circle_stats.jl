
function circ_resultant(samples::Vector{Float64}, weights::Vector{Float64})::Float64
    R = sum(weights .* exp.(im .* samples))
    R = abs(R) ./ sum(weights)
    return R
end

function circ_resultant(samples::Vector{Float64})::Float64
    R = sum(exp.(im .* samples))
    R = abs(R) ./ length(samples)
    return R
end

function mardia_jupp_κ_mle(
    headings::Vector{Float64},
    weights::Vector{Float64}
)::Float64
    headings = headings[:]
    N = length(headings)
    if N > 1
        R = circ_resultant(headings, weights)
    else
        R = headings
    end

    if 0 <= R < 0.53
        kappa = 2 * R + R^3 + 5 * (R^5) / 6
    elseif 0.53 <= R < 0.85
        kappa = -0.4 + 1.39 * R + 0.43 / (1 - R)
    else
        kappa = 1 / (R^3 - 4 * R^2 + 3 * R)
    end
    return kappa
end

function mardia_jupp_κ_mle(headings::Vector{Float64})::Float64
    headings = headings[:]
    N = length(headings)
    if N > 1
        R = circ_resultant(headings)
    else
        R = headings
    end

    if 0 <= R < 0.53
        kappa = 2 * R + R^3 + 5 * (R^5) / 6
    elseif 0.53 <= R < 0.85
        kappa = -0.4 + 1.39 * R + 0.43 / (1 - R)
    else
        kappa = 1 / (R^3 - 4 * R^2 + 3 * R)
    end
    return kappa
end


function load_kappa_CDF()::Tuple{Array{Float64,3},Matrix{Float64}}
    lookup_table =
        jldopen(joinpath(dirname(pathof(CollectiveMigration)), "kappaCDFLookupTable.jld2"))
    kappa_CDF = lookup_table["kappa_CDF"]
    kappa_input = lookup_table["kappa_input"]
    lookup_table = nothing
    return kappa_CDF, kappa_input
end

function get_kappa(
    headings::Vector{Float64},
    weights::Vector{Float64},
    kappa_CDF,
    kappa_input,
)::Float64
    κ = mardia_jupp_κ_mle(headings, weights)
    N = length(headings)
    if κ < 25 && N < 25
        kappa_lookup_index = round(Int64, κ * 20) + 1 # equivalent to line below
        # _, kappa_lookup_index = findmin(abs.(κ - kappa_input))
        cdf_sample = rand()
        temp = findfirst(x -> cdf_sample < x, kappa_CDF[:, N-1, kappa_lookup_index])
        κ = kappa_input[temp] + rand() * (kappa_input[2] - kappa_input[1])
    end
    return κ
end

function get_kappa(headings::Vector{Float64}, kappa_CDF, kappa_input)
    κ = mardia_jupp_κ_mle(headings)
    N = length(headings)
    if κ < 25 && N < 25
        kappa_lookup_index = round(Int64, κ * 20) + 1 # equivalent to line below
        # _, kappa_lookup_index = findmin(abs.(κ - kappa_input))
        cdf_sample = rand()
        temp = findfirst(x -> cdf_sample < x, kappa_CDF[:, N-1, kappa_lookup_index])
        κ = kappa_input[temp] + rand() * (kappa_input[2] - kappa_input[1])
    end
    return κ
end
