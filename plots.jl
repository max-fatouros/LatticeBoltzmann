using CairoMakie
using GLMakie
using ProgressMeter

GLMakie.activate!(; float=true)

function plot_speeds(
    simulation::Simulation;
    ax=nothing,
)
    fig = nothing
    if isnothing(ax)
        fig = Figure()
        ax = Axis(fig[1, 1])
    end

    velocities = (
        simulation.momentum_densities
        ./
        simulation.mass_densities
    )

    speeds = dropdims(
        sqrt.(sum(velocities .^ 2; dims=3));
        dims=3,
    )

    CairoMakie.image!(ax, speeds; colormap=:viridis)

    return fig
end

function animate_speeds!(
    simulation::Simulation,
    filename="animation.mp4",
)
    fig = Figure()
    sim = Observable(simulation)
    ax = Axis(fig[1, 1]; aspect=DataAspect())
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

    simulation,
function animate_speeds_live!(
)
    fig = Figure()
    sim = Observable(simulation)

    ax = Axis(fig[1, 1]; aspect=DataAspect())
    @lift(
        plot_speeds(
            $sim,
            ax=ax,
        )
    )

    display(fig)
    for i ∈ 1:simulation.time_steps
        multithreaded_update!(sim[])
        resize_to_layout!(fig)
        notify(sim)
        sleep(1e-3)
    end
    return
end
