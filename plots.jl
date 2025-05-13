using CairoMakie
using GLMakie
using ProgressMeter

include("simulation.jl")

GLMakie.activate!(; float=true)

function plot_speeds(
    simulation::Observable{<:SimulationD2};
    ax=nothing,
    kwargs...,
)
    fig = nothing
    if isnothing(ax)
        fig = Figure()
        ax = CairoMakie.Axis(
            fig[1, 1];
            aspect=DataAspect(),
            xgridvisible=false,
            ygridvisible=false,
        )
    end

    speeds = @lift begin
        sim = $simulation
        speeds = get_speeds(sim)
        speeds[sim.object_mask] .= NaN
        return speeds
    end

    defaults = (;
        colormap=:viridis,
        nan_color=:black,
    )
    kwargs = merge(defaults, kwargs)

    CairoMakie.image!(
        ax,
        speeds;
        kwargs...,
    )
    return fig
end

function plot_speeds(
    simulation::Observable{<:SimulationD3};
    ax=nothing,
    kwargs...,
)
    fig = nothing
    if isnothing(ax)
        fig = Figure()
        ax = Axis3(fig[1, 1]; aspect=:data)
    end

    speeds = @lift begin
        sim = $simulation
        speeds = get_speeds(sim)
        speeds[sim.object_mask] .= NaN
        return speeds
    end

    defaults = (;
        algorithm=:mip,
        colormap=:viridis,
        nan_color=:black,
    )
    kwargs = merge(defaults, kwargs)

    GLMakie.volume!(
        ax,
        speeds;
        kwargs...,
    )

    return fig
end

function plot_speeds(
    simulation::Simulation;
    ax=nothing,
    kwargs...,
)
    return plot_speeds(Observable(simulation); ax=ax, kwargs...)
end

function plot_velocities(
    simulation::Observable{<:SimulationD2};
    ax=nothing,
    kwargs...,
)
    fig = nothing
    if isnothing(ax)
        fig = Figure()
        ax = CairoMakie.Axis(fig[1, 1]; aspect=DataAspect())
    end

    # speeds = @lift(get_speeds($simulation))

    defaults = (; colormap=:viridis)
    kwargs = merge(defaults, kwargs)

    # f(x, simulation) = Point2f(simulation.momentum_densities[round.(Int, x)..., :])
    # f(x) = @lift(f(x, $simulation))
    field = @lift begin
        sim = $simulation
        (x, y) -> Point2f(sim.momentum_densities[round(Int, x), round(Int, y), :])
    end

    CairoMakie.streamplot!(
        ax,
        field,
        1:400,
        1:100;
        kwargs...,
    )

    return fig
end

function plot_velocities(
    simulation::Simulation;
    ax=nothing,
    kwargs...,
)
    return plot_velocities(Observable(simulation); ax=ax, kwargs...)
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
    CairoMakie.image!(
        ax,
        @lift(identity($simulation.object_mask));
        kwargs...,
    )
    return fig
end

function plot_objects(
    simulation::Observable{<:SimulationD3};
    ax=nothing,
    kwargs...,
)
    fig = nothing
    if isnothing(ax)
        fig = Figure()
        ax = Axis3(fig[1, 1]; aspect=:data)
    end
    GLMakie.volume!(
        ax,
        @lift(identity($simulation.object_mask));
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
    plot_function;
    steps=100,
    filename="animation.mp4",
    ax=nothing,
    show_every=10,
    kwargs...,
)
    GLMakie.activate!(; float=true)
    fig = Figure()
    sim = Observable(simulation)
    ax = nothing
    if typeof(simulation) <: SimulationD2
        ax = CairoMakie.Axis(fig[1, 1]; aspect=DataAspect())
    elseif typeof(simulation) <: SimulationD3
        ax = Axis3(fig[1, 1]; aspect=:data)
    end

    @lift(
        plot_function(
            $sim;
            ax=ax,
            kwargs...,
        )
    )
    resize_to_layout!(fig)

    prog = Progress(steps)

    record(
        fig,
        filename,
        1:(steps÷show_every),
    ) do t
        for _ ∈ 1:show_every
            next!(prog)
            multithreaded_update!(sim[])
        end
        notify(sim)
        return sleep(1e-3)
    end
    return
end

# TODO: pass plot function
function animate_with_slider!(
    simulation::Simulation,
    plot_function;
    steps=100,
    ax=nothing,
)
    GLMakie.activate!(; float=true)

    fig = Figure()
    if typeof(simulation) <: SimulationD2
        ax = CairoMakie.Axis(fig[1, 1]; aspect=DataAspect())
    elseif typeof(simulation) <: SimulationD3
        ax = Axis3(fig[1, 1]; aspect=:data)
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
        plot_function(
            simulations[$index],
            ax=ax,
        )
    )
    display(fig)
    return
end

function animate_live!(
    simulation,
    plot_function;
    steps=nothing,
    show_every=100,
    kwargs...,
)
    GLMakie.activate!(; float=true)
    fig = Figure()
    sim = Observable(simulation)

    ax = nothing
    if typeof(simulation) <: SimulationD2
        ax = CairoMakie.Axis(fig[1, 1]; aspect=DataAspect())
    elseif typeof(simulation) <: SimulationD3
        ax = Axis3(fig[1, 1]; aspect=:data)
    end

    plot_function(
        sim;
        ax=ax,
        kwargs...,
    )

    display(fig)
    resize_to_layout!(fig)
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
