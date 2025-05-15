include("simulation.jl")
include("plots.jl")

media_dir = "report/media"
animations_dir = "animations"
mkpath(media_dir)
mkpath(animations_dir)

CairoMakie.activate!()

"""
wrap Makie.set_theme! so that revise updates this.
"""
function set_theme()
    return set_theme!(
        Theme(;
            fontsize=20,
            linewidth=2,
            markersize=6,
        ),
    )
end
set_theme()

function single_disk_scene(reynolds_number=200)
    simulation = SimulationD2Q9()

    add_sphere!(
        simulation;
        position=(50, 50),
        radius=25,
    )

    add_source!(simulation, (5, :), 1, 0.2)
    set_reynolds_number!(simulation, reynolds_number)
    return simulation
end

function single_cylinder_scene(reynolds_number=60)
    simulation = SimulationD3Q15((200, 50, 50))

    add_cylinder!(
        simulation;
        position=(25, 25, 25),
        radius=12.5,
    )

    add_source!(simulation, (5, :, :), 1, 0.2)
    set_reynolds_number!(simulation, reynolds_number)
    return simulation
end

function make_velocity_plots()
    with_theme(
        Theme(;
            fontsize=20,
            markersize=20,
        ),
    ) do
        f = plot_velocities(SimulationD2Q9((10, 10)))
        display(f)
        path = joinpath(media_dir, "velocities_d2q9.png")
        save(path, f)

        f = plot_velocities(SimulationD3Q15((10, 10, 10)))
        display(f)
        path = joinpath(media_dir, "velocities_d3q15.png")
        return save(path, f)
    end
end

"""
Returns a vector of fit parameters in increasing order.
i.e. returns (p_1, p_2) for a_1 + a_2*X = Y
"""
function fit(X, Y)
    U = hcat.(1, X)
    P = inv(U' * U) * U' * Y
    return P
end

function make_pulse_2D()
    simulation = SimulationD2Q9()

    add_source!(simulation, (3, :), 1, 0.4)
    update!(simulation)
    pop!(simulation.sources)
    return simulation
end

function make_pulse_3D()
    simulation = SimulationD3Q15((600, 25, 25))

    add_source!(simulation, (3, :, :), 1, 0.4)
    update!(simulation)
    pop!(simulation.sources)
    return simulation
end

function record_pulse_2D()
    simulation = make_pulse_2D()
    path = joinpath(animations_dir, "pulse-2d.mp4")
    return animate!(
        simulation,
        plot_speeds;
        steps=600,
        filename=path,
        show_every=100,
    )
end

function plot_speed_of_sound_fit(dimensions=2)
    set_theme()
    CairoMakie.activate!()
    simulation = nothing
    times = nothing
    dims = nothing
    path = nothing
    if 2 == dimensions
        simulation = make_pulse_2D()
        dims = 2
        times = collect(1:500)
        path = joinpath(media_dir, "speed_fit_2d.png")
    elseif 3 == dimensions
        simulation = make_pulse_3D()
        dims = (2, 3)
        times = collect(1:500)
        path = joinpath(media_dir, "speed_fit_3d.png")
    end

    prog = Progress(length(times))
    peak_positions = []
    for i ∈ times
        next!(prog)
        speeds = get_speeds(simulation)
        peak_pos = argmax(mean(speeds; dims=dims))[1]
        push!(peak_positions, peak_pos)
        update!(simulation)
    end

    fig = Figure()
    ax = CairoMakie.Axis(fig[1, 1])
    ax.title = "$(dimensions)D pulse peak-fit over time"
    ax.xlabel = "time [lt]"
    ax.ylabel = "space [lx]"
    CairoMakie.scatter!(ax, peak_positions; label="peak-positions")

    parameters = fit(times, peak_positions)
    fit_line = parameters[1] .+ parameters[2] * times

    CairoMakie.lines!(ax, fit_line; color=:red, linestyle=:dot, label="fit")

    axislegend(ax; halign=:left)

    display(fig)

    save(path, fig)

    @show fit_diff_std = std(fit_line .- peak_positions)
    @show "fit_slope: $(parameters[2])"
    @show parameters[2] - 1 / sqrt(3)
end


function plot_vortex_2d()
    sim = single_disk_scene()
    fig = Figure()

    CairoMakie.activate!()

    final_simulations = []

    ax = Makie.Axis(fig[1, 1])
    for reynolds_number ∈ (
        25,
        50,
        100,
        200,
        300,
    )
        absolute_vorticities = []
        reset!(sim)
        set_reynolds_number!(sim, reynolds_number)


        steps = 5000
        prog = Progress(steps)

        for t ∈ 1:steps
            next!(prog)
            absolute_vorticity = sum(abs.(get_curls(sim)))
            push!(absolute_vorticities, absolute_vorticity)
            update!(sim)
        end

        push!(final_simulations, deepcopy(sim))

        Makie.lines!(ax, absolute_vorticities; label="$reynolds_number")
    end

    save(final_simulations, "vortex_simulations")

    axislegend(ax)
    ax.xlabel = L"time $[lt]$"
    ax.ylabel = L"absolute vorticity $[lt^{-1}]$"
    ax.title = "2D Vorticity for different Reynolds numbers"

    path = joinpath(media_dir, "vortex-2d.png")
    Makie.save(path, fig)



    return fig
end


function plot_vortex_3d()
    sim = single_cylinder_scene()
    fig = Figure()

    CairoMakie.activate!()

    final_simulations = []

    ax = Makie.Axis(fig[1, 1])
    for reynolds_number ∈ (
        25,
        50,
        100,
        200,
        300,
    )
        absolute_vorticities = []
        reset!(sim)
        set_reynolds_number!(sim, reynolds_number)


        steps = 50
        prog = Progress(steps)

        for t ∈ 1:steps
            next!(prog)
            absolute_vorticity = sum(get_curl_norms(sim))
            push!(absolute_vorticities, absolute_vorticity)
            update!(sim)
        end

        push!(final_simulations, deepcopy(sim))

        Makie.lines!(ax, absolute_vorticities; label="$reynolds_number")
    end

    save(final_simulations, "vortex_simulations")

    axislegend(ax)
    ax.xlabel = L"time $[lt]$"
    ax.ylabel = L"absolute vorticity $[lt^{-1}]$"
    ax.title = "2D Vorticity for different Reynolds numbers"

    path = joinpath(media_dir, "vortex-3d.png")
    Makie.save(path, fig)



    return fig
end




function plot_all(sim::SimulationD2)
    CairoMakie.activate!()
    fig = Figure()

    axes = [Makie.Axis(fig[i, 1]) for i ∈ 1:3]
    configs = [
        Config(property; ax=axes[i])
        for (i, property)
        ∈ enumerate((
            :speed,
            :curl,
            :velocity,
        ))
    ]

    plot(sim, Config(:speed; ax=axes[1]))
    plot(sim, Config(:curl; ax=axes[2]))
    plot_velocities(
        sim;
        ax=axes[3],
        density=0.75,
        arrow_size=10,
        maxsteps=5000,
    )

    for i ∈ 1:length(fig.layout.rowsizes)
        rowsize!(fig.layout, i, Aspect(1, get_aspect(sim)))
        Box(fig[i, 2]; color=:gray90)
        Label(
            fig[i, 2],
            "$(configs[i].property)";
            rotation=pi / 2,
            tellheight=false,
        )
    end
    axes[1].xticklabelsvisible = false
    axes[2].xticklabelsvisible = false

    axes[2].ylabel = "y [lx]"
    axes[3].xlabel = "x [lx]"

    resize_to_layout!(fig)

    path = joinpath(media_dir, "all_2d.png")
    save(path, fig)

    return fig
end

function plot_vortices(filename="vortex_simulations")
    CairoMakie.activate!()
    sims = load(filename)

    fig = Figure()
    for (i, sim) ∈ enumerate(sims)
        ax = Makie.Axis(fig[i, 1])
        plot(sim, Config(:speed; ax=ax))
        rowsize!(fig.layout, i, Aspect(1, get_aspect(sim)))
        if i <= (length(sims) - 1)
            ax.xticklabelsvisible = false
        else
            ax.xlabel = "x [lx]"
        end
        ax.ylabel = "y [lx]"
        Box(fig[i, 2]; color=:gray90)
        Label(
            fig[i, 2],
            "$(round(Int, get_reynolds_number(sim)))";
            rotation=pi / 2,
            tellheight=false,
        )
    end

    resize_to_layout!(fig)

    path = joinpath(media_dir, "vortex_speeds_2d.png")
    Makie.save(path, fig)

    return fig
end
