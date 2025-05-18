using CairoMakie
using GLMakie
using ProgressMeter

include("simulation.jl")

GLMakie.activate!(; float=true)

mutable struct Config
    property::Any
    ax::Any
    kwargs::Any
end

function Config(
    property=:speed;
    ax=nothing,
    kwargs...,
)
    return Config(
        property,
        ax,
        kwargs,
    )
end

#!format: off
get_axis(simulation::SimulationD2, fig_element) = (
    Makie.Axis(
        fig_element;
    )
)
get_axis(simulation::SimulationD3, fig_element) = (
    Makie.Axis3(
        fig_element;
        aspect=:data,
    )
)
#!format: on

function get_aspect(simulation::SimulationD2)
    sizes = size(simulation.mass_densities)
    return sizes[2] / sizes[1]
end

function plot(
    simulation::Observable{<:SimulationD2},
    config=nothing,
    kwargs...,
)
    defaults = (;
        colormap=:viridis,
        nan_color=:black,
    )
    config.kwargs = merge(defaults, config.kwargs)

    if isnothing(config)
        config = Config()
    end
    fig = nothing
    if isnothing(config.ax)
        fig = Figure()
        config.ax = CairoMakie.Axis(
            fig[1, 1];
            xgridvisible=false,
            ygridvisible=false,
        )
    end

    get_property = nothing
    if :speed == config.property
        get_property = get_speeds
    elseif :curl == config.property
        get_property = get_curls
    end

    values = @lift begin
        sim = $simulation
        values = get_property(sim)
        if :curl == config.property
            negative_values = values .< 0
            positive_values = values .>= 0
            values[negative_values] .= -1
            values[positive_values] .= 1
            # values[abs.(values) .< 0.005] .= NaN
            # values[abs.(values) .> 0.02] .= NaN
        end
        values[sim.object_mask] .= NaN

        if !isnothing(fig)
            rowsize!(fig.layout, 1, Aspect(1, get_aspect(sim)))
        end
        return values
    end

    if !isnothing(fig)
        resize_to_layout!(fig)
    end
    CairoMakie.image!(
        config.ax,
        values;
        config.kwargs...,
    )
    return fig
end

function plot(
    simulation::Observable{<:SimulationD3},
    config=nothing,
)
    if isnothing(config)
        config = Config()
    end
    fig = nothing
    if isnothing(config.ax)
        fig = Figure()
        config.ax = Makie.Axis3(
            fig[1, 1];
            xgridvisible=false,
            ygridvisible=false,
        )
    end

    get_property = nothing
    if :speed == config.property
        get_property = get_speeds
    elseif :curl == config.property
        get_property = get_curls
    end

    values = @lift begin
        sim = $simulation
        values = get_property(sim)

        # HACK: remove boundaries
        object_mask = sim.object_mask[:, 2:end-1, 2:end-1]

        values[:, 2:end-1, 2:end-1][object_mask] .= NaN

        return values
    end

    defaults = (;
        algorithm=:mip,
        colormap=:viridis,
        nan_color=:black,
    )
    config.kwargs = merge(defaults, config.kwargs)

    GLMakie.volume!(
        config.ax,
        values;
        config.kwargs...,
    )

    plot_objects(
        simulation;
        ax=config.ax,
    )

    return fig
end

function plot(
    simulation::Simulation,
    config=nothing,
)
    return plot(
        Observable(simulation),
        config,
    )
end

function plot_velocities(
    simulation::Observable{<:SimulationD2},
    config=nothing;
    kwargs...,
)

    if isnothing(config)
        config = Config()
    end

    fig = nothing
    if isnothing(config.ax)
        fig = Figure()
        config.ax = CairoMakie.Axis(fig[1, 1];)
    end

    defaults = (; colormap=:viridis)
    kwargs = merge(defaults, kwargs)

    field = @lift begin
        sim = $simulation
        (x, y) -> Point2f(sim.momentum_densities[round(Int, x), round(Int, y), :])
    end

    CairoMakie.streamplot!(
        config.ax,
        field,
        1:400,
        1:100;
        kwargs...,
    )
    plot_objects(sim; ax=config.ax)

    return fig
end

function plot_velocities(
    simulation::Simulation,
    config=nothing;
    kwargs...,
)
    return plot_velocities(Observable(simulation), config; kwargs...)
end

function plot_objects(
    simulation::Observable{<:SimulationD2};
    ax=nothing,
    kwargs...,
)
    fig = nothing
    if isnothing(ax)
        fig = Figure()
        ax = CairoMakie.Axis(fig[1, 1]; aspect=DataAspect())
    end
    mask = @lift begin
        sim = $simulation
        mask = zeros(
            Float64,
            size(sim.object_mask)...,
        )
        mask .= NaN
        mask[sim.object_mask.==1] .= 1
        return mask
    end
    CairoMakie.image!(
        ax,
        mask;
        colormap=[:black],
        kwargs...,
    )
    return fig
end




function plot_objects(
    simulation::Observable{<:SimulationD3};
    ax=nothing,
    kwargs...,
)
    GLMakie.activate!()
    fig = nothing
    if isnothing(ax)
        fig = Figure()
        ax = Axis3(fig[1, 1]; aspect=:data)
    end

    mask = @lift begin
        sim = $simulation
        # HACK: remove boundaries
        mask = zeros(
            Bool,
            size(sim.object_mask)...,
        )
        mask .= 0
        mask[sim.object_mask.==1] .= 1
        mask[:, :, 1] .= false
        mask[:, :, end] .= false
        mask[:, 1, :] .= false
        mask[:, end, :] .= false

        return mask
    end

    GLMakie.volume!(
        ax,
        mask;
        colormap=[:transparent, :black],
        # nan_color=:transparent,
        # @lift(identity($simulation.object_mask));
        kwargs...,
    )
    return fig
end

function plot_objects(
    simulation::Simulation;
    ax=nothing,
    kwargs...,
)
    return plot_objects(
        Observable(simulation);
        ax=ax,
        kwargs...,
    )
end

# TODO: pass plot function
function animate!(
    simulation::Simulation,
    configs=nothing;
    steps=100,
    filename="animation.mp4",
    show_every=10,
    kwargs...,
)
    if isnothing(configs)
        configs = Config()
    end

    if !(typeof(configs) <: Array)
        configs = [configs;;]
    end

    fig = Figure()
    sim = Observable(simulation)

    for index ∈ CartesianIndices(configs)
        configs[index].ax = get_axis(simulation, fig[Tuple(index)...])
        plot_function = nothing
        if :velocity == configs[index].property
            plot_function = plot_velocities
        else
            plot_function = plot
        end

        @lift(
            plot_function(
                $sim,
                configs[index];
                kwargs...,
            )
        )

        right_grid_index = (Tuple(index) .+ (0, 1))
        Box(fig[right_grid_index...]; color=:gray90)
        Label(
            fig[right_grid_index...],
            "$(configs[index].property)";
            rotation=pi / 2,
            tellheight=false,
        )
    end


    for i in 1:length(fig.layout.rowsizes)
        rowsize!(fig.layout, i, Aspect(1, get_aspect(simulation)))
    end

    resize_to_layout!(fig)

    prog = Progress(steps)
    record(
        fig,
        filename,
        1:(steps÷show_every);
        kwargs...,
    ) do t
        for _ ∈ 1:show_every
            next!(prog)
            update!(sim[])
        end
        notify(sim)
        return sleep(1e-3)
    end
    return
end

# TODO: pass plot function
function animate_with_slider!(
    simulation::Simulation,
    config=nothing;
    # plot_function;
    steps=100,
    # ax=nothing,
)
    if isnothing(config)
        config = Config()
    end
    GLMakie.activate!(; float=true)

    fig = Figure()
    if typeof(simulation) <: SimulationD2
        config.ax = CairoMakie.Axis(fig[1, 1]; aspect=DataAspect())
    elseif typeof(simulation) <: SimulationD3
        config.ax = Axis3(fig[1, 1]; aspect=:data)
    end
    slider = Slider(
        fig[2, 1];
        range=1:steps,
    )
    index = lift(slider.value) do t
        return t
    end

    simulations = []
    prog = Progress(steps)
    for i ∈ 1:steps
        next!(prog)
        push!(simulations, deepcopy(simulation))
        update!(simulation)
    end

    @lift(
        plot(
            simulations[$index],
            config,
        )
    )
    display(fig)
    return
end

function animate_live!(
    simulation::Simulation,
    configs=nothing;
    steps=100,
    show_every=10,
)
    GLMakie.activate!(; float=true)
    fig = Figure()
    sim = Observable(simulation)

    if isnothing(configs)
        configs = Config()
    end

    if !(typeof(configs) <: Array)
        configs = [configs;;]
    end

    for index ∈ CartesianIndices(configs)
        configs[index].ax = get_axis(simulation, fig[Tuple(index)...])

        @lift(
            plot(
                $sim,
                configs[index],
            )
        )

        right_grid_index = (Tuple(index) .+ (0, 1))
        Box(fig[right_grid_index...]; color=:gray90)
        Label(
            fig[right_grid_index...],
            "$(configs[index].property)";
            rotation=pi / 2,
            tellheight=false,
        )
    end

    for i in 1:length(fig.layout.rowsizes)
        rowsize!(fig.layout, i, Aspect(1, get_aspect(simulation)))
    end

    resize_to_layout!(fig)
    display(fig)
    i = 0
    while isnothing(steps) || i < steps
        update!(sim[])
        if (i % show_every) == 0
            notify(sim)
            @info "frame $i"
        end
        sleep(1e-3)
        i += 1
    end
    return fig
end

function plot_velocities(
    simulation::SimulationD2;
)
    fig = Figure()
    CairoMakie.activate!()

    ax = CairoMakie.Axis(fig[1, 1])

    xs = collect([0 for velocity ∈ simulation.velocities])
    ys = collect([0 for velocity ∈ simulation.velocities])
    us = collect([velocity[1] for velocity ∈ simulation.velocities])
    vs = collect([velocity[2] for velocity ∈ simulation.velocities])

    arrows!(
        ax,
        xs[2:end],
        ys[2:end],
        us[2:end],
        vs[2:end],
    )

    text!(
        ax,
        0.3,
        0.15;
        text=L"v_{1}",
        align=(:center, :center),
        fontsize=30,
    )

    for i ∈ 2:length(simulation.velocities)
        text!(
            ax,
            1.2 * simulation.velocities[i]...;
            text=L"v_{%$i}",
            align=(:center, :center),
            fontsize=30,
        )
    end

    colsize!(fig.layout, 1, Aspect(1, 1.0))
    ax.xlabel = "x-layer"
    ax.ylabel = "y-layer"
    resize_to_layout!(fig)
    return fig
end

function plot_velocities(
    simulation::SimulationD3Q15;
)
    fig = Figure()

    CairoMakie.activate!()

    us = collect([velocity[1] for velocity ∈ simulation.velocities])
    vs = collect([velocity[2] for velocity ∈ simulation.velocities])
    ws = collect([velocity[3] for velocity ∈ simulation.velocities])

    for i ∈ -1:1
        indices = findall(
            x -> x == i,
            ws,
        )
        ax = CairoMakie.Axis(fig[1, i]; aspect=DataAspect())

        scatter!(
            ax,
            us[indices],
            vs[indices],
        )

        for index ∈ indices
            if index in (1, 6, 7)
                text!(
                    ax,
                    0.3,
                    0.15;
                    text=L"v_{%$index}",
                    align=(:center, :center),
                    fontsize=30,
                )
            else
                text!(
                    ax,
                    1.2 * simulation.velocities[index]...;
                    text=L"v_{%$index}",
                    align=(:center, :center),
                    fontsize=30,
                )
            end
        end
        colsize!(fig.layout, i, Aspect(1, 1.0))
        ax.title = "Z-layer $i"
        ax.xlabel = "x-layer"

        if i == -1
            ax.ylabel = "y-layer"
            continue
        end
        ax.yticklabelsvisible = false
        ax.yticksvisible = false
    end

    resize_to_layout!(fig)
    return fig
end
