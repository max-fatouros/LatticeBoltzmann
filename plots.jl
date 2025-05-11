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
        ax = CairoMakie.Axis(fig[1, 1], aspect=DataAspect())
    end

    speeds = @lift(get_speeds($simulation))

    defaults = (; colormap=:viridis)
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

    speeds = @lift(get_speeds($simulation))

    defaults = (; algorithm=:mip, colormap=:viridis)
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

function animate_speeds!(
    simulation::Simulation;
    filename="animation.mp4",
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

function animate_speeds_live!(
    simulation;
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

    # plot_objects(
    #     sim;
    #     ax=ax,
    # )
    plot_speeds(
        sim;
        ax=ax,
        kwargs...,
    )

    display(fig)
        multithreaded_update!(sim[])
        resize_to_layout!(fig)
    for i ∈ 1:simulation.parameters.time_steps
        if (i % show_every) == 0
            notify(sim)
            @info "frame $i"
        end
        sleep(1e-3)
    end
    return fig
end
