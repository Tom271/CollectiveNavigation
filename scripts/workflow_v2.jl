# Standard Imports 
using DrWatson
@quickactivate :CollectiveNavigation
using CairoMakie
CairoMakie.set_theme!(theme_minimal())
update_theme!(Lines=(linewidth=2,))
using PerceptualColourMaps
using Colors
using Statistics
using Pipe: @pipe

colors = cmap("D4"; N=9);

## Setup experiment configuration
sensing_values = [0.0, 1.0, 2.0, 3.0, 5.0, 10.0, 20.0, 50.0, 500.0];

config = SimulationConfig(
    num_repeats=50,
    flow=Dict("type" => "constant", "strength" => 0.0),
    sensing=Dict("type" => "ranged", "range" => 0.0),
    heading_perception=Dict("type" => "intended"),
    terminal_time=5000,
);
parse_config!(config);

## Produce or load data
ranged_flow_data = run_experiment(
    config,
    :flow,
    :sensing;
    flow_values=-0.5:0.1:0.5,
    sensing_values=sensing_values,
    show_log=false
)

# Decompress data -- should this be part of `run_experiment` ?
@info "Decompressing..."
df = decompress_data(ranged_flow_data)

# Drop irrelevant rows. For Results section:
select!(df, Not([:num_agents, :goal_tol]));
# And for metric robustness
# select!(df, Not(:flow_strength))
# Overwrite the large experiment data to free space (not necessary)
ranged_flow_data = nothing;

## Standard Manipulations
# Individuals remaining, averaged across trials w/ stdev -> line plots, density plots
mean_ind_rem = @pipe df |>
                     get_mean_individuals_remaining(_, [:sensing_range, :flow_strength]);
arrival_times = @pipe df |>
                      get_arrival_times(_, [:sensing_range, :flow_strength]);
median_arrival = get_centile_arrival(arrival_times; centile=50);
arrival_times = make_failures_explicit(median_arrival, df, [:sensing_range, :flow_strength]);

## Standard Plots

## REALISATIONS
sr = 500.0
flow = 0.1
reduced_df = @pipe df |>
                   subset(
                       _,
                       :sensing_range => x -> x .== (sr),
                       :flow_strength => x -> x .== (flow)
                   ) |>
                   groupby(_, :trial);
f = Figure()
ax = Axis(f[1, 1], xlabel="Time", ylabel="Individuals Remaining",
    title="Flow Strength = $(flow), Sensing Range = $(sr), Trials = $(maximum(df[!,:trial]))")
for trial in reduced_df
    lines!(
        trial[!, :coarse_time],
        trial[!, :individuals_remaining];
        label=string(trial[!, :trial][1]),
        color=:slategray,
        linewidth=0.5
    )
end
xlims!(0, 1200)
# f[1, 2] = Legend(f, ax, "Trial", merge=true, unique=true)
f

## DENSITY 
function plot_one_density(
    df::DataFrame,
    group::Symbol,
    flow_strength::Real;
    centiles::Vector{Int}=[99,90,75,50,25,10, 0],
    colors=cmap("D4"; N=9))
    param_vals = unique(df[!,group])
    ylabels = string.(Int.(param_vals))
    f = CairoMakie.Figure()
    ax = CairoMakie.Axis(f[1, 1], yticks = ((1:9) .* 0.02, ylabels))
    for (idx, sensing_val) in enumerate(param_vals)
        arrival_times = @pipe df |> 
        get_arrival_times(_,[:sensing_range,:flow_strength]) |>
        subset(
            _,
            :sensing_range => x-> x.==sensing_val,
            :flow_strength => x->x.==flow_strength
            )

        hist!(
            ax,
            arrival_times[!,:arrival_time_mean];
            normalization=:pdf,
            offset = idx*0.02,
            color = :slategray,
            strokewidth = 1,
            strokearound = true,
            bins = Base.range(0,stop=5000,length=500),
        )
        
        for (jdx,centile) in enumerate(centiles)
            try
                arrival = @pipe arrival_times |>
                get_centile_arrival(_;centile=centile)[1,:arrival_time_mean]
                lines!(
                    ax,
                    [arrival, arrival],
                    [idx,idx+1].*0.02; 
                    color=colors[jdx],
                    linestyle=(centile==50) ? :solid : :dot,
                    label=string.(100-centile),
                    linewidth=(centile==50) ? 3 : 2
                    )
                j+=1
            catch e
                continue
            end
        end
    return f
end



## HEATMAP
arrival_times = @pipe df |>
                      get_arrival_times(_, [:sensing_range, :flow_strength]);
median_arrival = get_centile_arrival(arrival_times; centile=50);
full_arrival_times = make_failures_explicit(median_arrival, df, [:sensing_range, :flow_strength]);
fig, ax, hm = plot_arrival_heatmap(full_arrival_times; save_plot=true);

## And just for fun, all in one: 
df = @pipe run_experiment(
    config,
    :flow,
    :sensing;
    flow_values=-0.5:0.1:0.5,
    sensing_values=sensing_values,
    show_log=false
) |>
           decompress_data(_);

fig, ax, hm = @pipe df |>
                    get_arrival_times(_, [:sensing_range, :flow_strength]) |>
                    get_centile_arrival(_; centile=50) |>
                    make_failures_explicit(_, df, [:sensing_range, :flow_strength]) |>
                    plot_arrival_heatmap(_; save_plot=true)