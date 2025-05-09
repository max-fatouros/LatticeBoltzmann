using CairoMakie
using GLMakie
using ProgressMeter

include("simulation.jl")

GLMakie.activate!(; float=true)

function plot_speeds(
    simulation::Simulation2D;
    ax=nothing,
)
    fig = nothing
    if isnothing(ax)
        fig = Figure()
        ax = Axis(fig[1, 1])
    end

    speeds = get_speeds(simulation)

    CairoMakie.image!(ax, speeds; colormap=:viridis)

    return fig
end

function plot_speeds(
    simulation::Simulation3D;
    ax=nothing,
)
    fig = nothing
    if isnothing(ax)
        fig = Figure()
        ax = Axis3(fig[1, 1]; aspect=:data)
    end

    speeds = get_speeds(simulation)

    GLMakie.volume!(
        ax,
        speeds;
        algorithm=:mip,
        colormap=:viridis,
        alpha=0.5,
    )

    return fig
end

function plot_objects(
    simulation::Simulation3D;
    ax,
)
    GLMakie.volume!(
        ax,
        simulation.object_mask;
        alpha=0.8,
    )
    return
end

function animate_speeds!(
    simulation::Simulation,
    filename="animation.mp4",
)
    fig = Figure()
    sim = Observable(simulation)
    ax = nothing
    if typeof(simulation) <: Simulation2D
        ax = Axis(fig[1, 1]; aspect=DataAspect())
    elseif typeof(simulation) <: Simulation3D
        ax = Axis3(fig[1, 1]; aspect=:data)
    end

    @lift(
        plot_speeds(
            $sim,
            ax=ax,
        )
    )
    resize_to_layout!(fig)

    record(
        fig,
        filename,
        1:(simulation.time_steps÷100),
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
)
    fig = Figure()
    sim = Observable(simulation)

    ax = nothing
    if typeof(simulation) <: Simulation2D
        ax = Axis(fig[1, 1]; aspect=DataAspect())
    elseif typeof(simulation) <: Simulation3D
        ax = Axis3(fig[1, 1]; aspect=:data)
    end
    @lift(
        plot_speeds(
            $sim,
            ax=ax,
        )
    )

    # @lift(
    #     plot_objects(
    #         $sim,
    #         ax=ax,
    #     )
    # )

    display(fig)
    for i ∈ 1:simulation.time_steps
        multithreaded_update!(sim[])
        resize_to_layout!(fig)
        if (i % show_every) == 0
            notify(sim)
            @info "frame $i"
        end
        sleep(1e-3)
    end
    return
end
