using CairoMakie
using GLMakie
using ProgressMeter

include("simulation.jl")

GLMakie.activate!(; float=true)

function plot_speeds(
    simulation::Observable{<:Simulation2D};
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
    simulation::Observable{<:Simulation3D};
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
    simulation::Observable{<:Simulation2D};
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
    simulation::Observable{<:Simulation2D};
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
    simulation::Observable{<:Simulation3D};
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
function animate_speeds!(
    simulation::Simulation;
    filename="animation.mp4",
    ax=nothing,
    kwargs...,
)
    fig = Figure()
    sim = Observable(simulation)
    ax = nothing
    if typeof(simulation) <: Simulation2D
        ax = CairoMakie.Axis(fig[1, 1]; aspect=DataAspect())
    elseif typeof(simulation) <: Simulation3D
        ax = Axis3(fig[1, 1]; aspect=:data)
    end

    @lift(
        plot_speeds(
            $sim;
            ax=ax,
            kwargs...,
        )
    )
    resize_to_layout!(fig)

    record(
        fig,
        filename,
        1:(simulation.parameters.time_steps÷100),
    ) do t
        @show t
        for _ ∈ 1:100
            multithreaded_update!(sim[])
        end
        # next!(prog)
        notify(sim)
        return sleep(1e-3)
    end
    return
end

# TODO: pass plot function
function animate_speeds_with_slider(simulations::Vector{Simulation})
    fig = Figure()
    slider = Slider(
        fig[2, 1];
        range=1:length(simulations),
    )
    index = lift(slider.value) do t
        return t
    end

    ax = Axis(fig[1, 1])
    @lift(plot_speeds(
        simulations[$index],
        ax=ax,
    ))
    display(fig)
    return
end

function animate_live!(
    simulation,
    plot_function;
    show_every=100,
    kwargs...,
)
    fig = Figure()
    sim = Observable(simulation)

    ax = nothing
    if typeof(simulation) <: Simulation2D
        ax = CairoMakie.Axis(fig[1, 1]; aspect=DataAspect())
    elseif typeof(simulation) <: Simulation3D
        ax = Axis3(fig[1, 1]; aspect=:data)
    end

    plot_function(
        sim;
        ax=ax,
        kwargs...,
    )

    display(fig)
    resize_to_layout!(fig)
    for i ∈ 1:simulation.parameters.time_steps
        multithreaded_update!(sim[])
        if (i % show_every) == 0
            notify(sim)
            @info "frame $i"
        end
        sleep(1e-3)
    end
    return fig
end
