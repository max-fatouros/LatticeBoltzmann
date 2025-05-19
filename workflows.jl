using ImageFiltering

include("simulation.jl")
include("plots.jl")

media_dir = "report/media"
animations_dir = "animations"
mkpath(media_dir)
mkpath(animations_dir)

CairoMakie.activate!()

# >>> utilities
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

"""
Returns a vector of fit parameters in increasing order.
i.e. returns (p_1, p_2) for a_1 + a_2*X = Y
"""
function fit(X, Y)
    U = hcat.(1, X)
    P = inv(U' * U) * U' * Y
    return P
end

function wing_forces(simulation)
    forces = []
    steps = 1000
    prog = Progress(steps)
    for i ∈ 1:steps
        next!(prog)
        update!(simulation)
        force = get_forces(simulation)
        push!(forces, force)
    end
    return forces
end

rad_to_ang(radians) = radians * (360 / (2 * pi))
ang_to_rad(ang) = ang * ((2 * pi) / 360)

# <<< utilities
# >>> scenes

function single_disk_scene(reynolds_number=300)
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

function wing_scene_2d(;
    reynolds_number=500,
    angle=20,
)
    simulation = SimulationD2Q9()
    @info "initiated simulation"

    point_cloud = get_point_cloud("wing.tiff")
    @info "loaded point cloud"

    # add_source!(simulation, (5, :), 1, 0.25)
    add_source!(simulation, (5, 5:95), 1, 0.1)
    set_reynolds_number!(simulation, reynolds_number)

    simulation.object_mask .= 0
    simulation.object_mask[1:end, 1] .= true
    simulation.object_mask[1:end, end] .= true
    add_point_cloud(
        simulation,
        point_cloud;
        position=(75, 50),
        rotation=pi / 2 + ang_to_rad(angle),
        side_length=75,
    )
    return simulation
end

function wing_scene_3d(;
    reynolds_number=250,
    angle=20,
)
    GLMakie.activate!()
    simulation = SimulationD3Q15((100, 50, 50))
    @info "initiated simulation"

    point_cloud = load("wing_point_cloud")
    @info "loaded point cloud"

    # add_source!(simulation, (5, :), 1, 0.25)
    add_source!(simulation, (5, 5:45, 5:45), 1, 0.1)
    set_reynolds_number!(simulation, reynolds_number)

    simulation.object_mask .= 0
    simulation.object_mask[:, :, 1] .= true
    simulation.object_mask[:, :, end] .= true
    simulation.object_mask[:, 1, :] .= true
    simulation.object_mask[:, end, :] .= true
    add_point_cloud(
        simulation,
        point_cloud;
        position=(25, 25, 25),
        rotation=(0, -ang_to_rad(angle), 0),
        side_length=40,
    )
    return simulation
end
# <<< scenes
# >>> plots
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

    save(final_simulations, "vortex_simulations_2d")

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

        steps = 5000
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

    save(final_simulations, "vortex_simulations_3d")

    axislegend(ax)
    ax.xlabel = L"time $[lt]$"
    ax.ylabel = L"absolute vorticity $[lt^{-1}]$"
    ax.title = "3D Vorticity for different Reynolds numbers"

    path = joinpath(media_dir, "vortex-3d.png")
    Makie.save(path, fig)

    return fig
end

function plot_all(sim::SimulationD2, filename)
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

    configs[3].kwargs = (
        density=0.75,
        arrow_size=10,
        maxsteps=100,
        stepsize=1,
    )

    plot(sim, Config(:speed; ax=axes[1]))
    plot(sim, Config(:curl; ax=axes[2]))
    plot_velocities(
        sim,
        configs[3];
        # density=0.75,
        # arrow_size=10,
        # maxsteps=5000,
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

    # path = joinpath(media_dir, filename)
    # Makie.save(path, fig)

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

function plot_wing_sims(filename="wing_2d")
    CairoMakie.activate!()
    sims = load(filename)

    sims = sims[[1, 6, 11, 16]]

    # HACK: hardcoded angles!
    angles = [0, 10, 20, 30]

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
            L"%$(angles[i])$^\circ$";
            rotation=pi / 2,
            tellheight=false,
        )
    end

    resize_to_layout!(fig)

    path = joinpath(media_dir, "wing_speeds_2d.png")
    Makie.save(path, fig)

    return fig
end

function angle_of_attack_2d(;
    reynolds_number=500,
    steps=10_000,
)
    angles = 0:2:30
    simulations = Array{Simulation}(undef, length(angles))
    ratios = zeros(length(angles))
    prog = Progress(length(angles))
    Threads.@threads for i ∈ 1:length(angles)
        simulation = wing_scene_2d(;
            reynolds_number=reynolds_number,
            angle=angles[i],
        )

        forces = []
        next!(prog)
        for _ ∈ 1:steps
            singlethreaded_update!(simulation)
            force = get_forces(simulation)
            push!(forces, force)
        end
        drag = mean(slice(forces, 1)[steps÷2:end])
        lift = mean(slice(forces, 2)[steps÷2:end])
        ratio = lift / drag
        ratios[i] = ratio
        simulations[i] = simulation
    end

    fig = Figure()
    ax = Makie.Axis(fig[1, 1])
    Makie.scatterlines!(ax, angles, ratios)
    ax.xlabel = "angle of attack [degrees]"
    ax.ylabel = "lift / drag"
    ax.title = "lift / drag ratio in 2D"
    path = joinpath(media_dir, "wing-2d.png")
    Makie.save(path, fig)
    save(simulations, "wing_2d")

    return fig
end

function angle_of_attack_2d(;
    reynolds_number=500,
    steps=10_000,
)
    angles = 0:2:30
    simulations = Array{Simulation}(undef, length(angles))
    ratios = zeros(length(angles))
    prog = Progress(length(angles))
    Threads.@threads for i ∈ 1:length(angles)
        simulation = wing_scene_2d(;
            reynolds_number=reynolds_number,
            angle=angles[i],
        )

        forces = []
        next!(prog)
        for _ ∈ 1:steps
            singlethreaded_update!(simulation)
            force = get_forces(simulation)
            push!(forces, force)
        end
        drag = mean(slice(forces, 1)[steps÷2:end])
        lift = mean(slice(forces, 2)[steps÷2:end])
        ratio = lift / drag
        ratios[i] = ratio
        simulations[i] = simulation
    end

    fig = Figure()
    ax = Makie.Axis(fig[1, 1])
    Makie.scatterlines!(ax, angles, ratios)
    ax.xlabel = "angle of attack [degrees]"
    ax.ylabel = "lift / drag"
    ax.title = "lift / drag ratio in 2D"
    path = joinpath(media_dir, "wing-2d.png")
    Makie.save(path, fig)
    save(simulations, "wing_2d")

    return fig
end

function angle_of_attack_3d(;
    reynolds_number=250,
    steps=1_000,
)
    angles = 0:6:30
    ratios = zeros(length(angles))
    prog = Progress(length(angles))
    Threads.@threads for i ∈ 1:length(angles)
        simulation = wing_scene_3d(;
            reynolds_number=reynolds_number,
            angle=angles[i],
        )

        forces = []
        next!(prog)
        for _ ∈ 1:steps
            singlethreaded_update!(simulation)
            force = get_forces(simulation)
            push!(forces, force)
        end
        drag = mean(slice(forces, 1)[steps÷2:end])
        lift = mean(slice(forces, 3)[steps÷2:end])
        ratio = lift / drag
        ratios[i] = ratio
    end

    fig = Figure()
    ax = Makie.Axis(fig[1, 1])
    Makie.scatterlines!(ax, angles, ratios)
    ax.xlabel = "angle of attack [degrees]"
    ax.ylabel = "lift / drag"
    ax.title = "lift / drag ratio in 3D"
    path = joinpath(media_dir, "wing-3d.png")
    Makie.save(path, fig)

    return fig
end

slice(tuples, i) = [tuple[i] for tuple ∈ tuples]
function slice(tuples, i, width)
    ker = ImageFiltering.Kernel.gaussian((3,))
    output = [tuple[i] for tuple ∈ tuples]
    return imfilter(output, ker)
end

function plot_forces(forces)
    CairoMakie.activate!()

    fig = Figure()
    ax = Makie.Axis(fig[1, 1])

    width = 10

    xs = slice(forces, 1, width)
    ys = slice(forces, 2, width)

    Makie.lines!(ax, xs; label="drag")
    Makie.lines!(ax, ys; label="lift")
    axislegend(ax)

    @show mean(ys) / mean(xs)

    return fig
end

# <<< plots
# >>> animations
function animate_pulse_2D()
    CairoMakie.activate!()
    simulation = make_pulse_2D()
    path = joinpath(animations_dir, "pulse-2d.mp4")
    return animate!(
        simulation,
        Config(:speed);
        steps=600,
        filename=path,
        show_every=1,
    )
end

function animate_disk()
    sim = single_disk_scene()

    path = joinpath(animations_dir, "disk.mp4")
    run!(sim; steps=10_000)
    return animate!(
        sim;
        steps=10_000,
        show_every=50,
        filename=path,
    )
end

function animate_all_plots!(sim)
    path = joinpath(animations_dir, "vortex_all.mp4")
    animate!(
        sim,
        [
            Config(:speed);
            Config(:curl);
            Config(
            :velocity;
            density=0.75,
            arrow_size=10,
            maxsteps=100,
            stepsize=1
        );;
        ];
        steps=10_000,
        show_every=50,
        filename=path,
    )
    return
end

function animate_reynolds_numbers()
    fig = Figure()
    CairoMakie.activate!()

    sims = [
        single_disk_scene(reynolds_number)
        for reynolds_number ∈ (
            25,
            50,
            100,
            200,
            300,
        )
    ]

    sim_observables = [
        Observable(sim)
        for sim ∈ sims
    ]
    axes = [
        Makie.Axis(fig[i, 1])
        for i ∈ 1:length(sims)
    ]
    for (i, sim) ∈ enumerate(sim_observables)
        @lift(
            plot(
                $sim,
                Config(:speed; ax=axes[i]),
            )
        )
    end

    for (i, ax) ∈ enumerate(axes)
        ax.ylabel = L"y $[lx]$"
        if i == length(axes)
            ax.xlabel = L"x $[lx]$"
        else
            ax.xticklabelsvisible = false
        end
        Box(fig[i, 2]; color=:gray90)
        Label(
            fig[i, 2],
            "$(round(Int, get_reynolds_number(sims[i])))";
            rotation=pi / 2,
            tellheight=false,
        )
    end

    for i ∈ 1:length(fig.layout.rowsizes)
        rowsize!(fig.layout, i, Aspect(1, 0.25))
    end

    resize_to_layout!(fig)

    steps = 30_000
    show_every = 50
    prog = Progress(steps ÷ show_every)

    path = joinpath(animations_dir, "reynolds.mp4")
    record(
        fig,
        path,
        1:(steps÷show_every);
    ) do t
        next!(prog)
        for _ ∈ 1:show_every
            Threads.@threads for sim ∈ sim_observables
                singlethreaded_update!(sim[])
            end
        end
        for sim ∈ sim_observables
            notify(sim)
        end
    end
    return
end

function animate_wing_angles()
    fig = Figure()
    CairoMakie.activate!()

    angles = (
        0,
        10,
        20,
        30,
    )

    sims = [
        wing_scene_2d(; reynolds_number=500, angle=angle)
        for angle ∈ angles
    ]

    sim_observables = [
        Observable(sim)
        for sim ∈ sims
    ]
    axes = [
        Makie.Axis(fig[i, 1])
        for i ∈ 1:length(sims)
    ]
    for (i, sim) ∈ enumerate(sim_observables)
        @lift(
            plot(
                $sim,
                Config(:speed; ax=axes[i]),
            )
        )
    end

    for (i, ax) ∈ enumerate(axes)
        ax.ylabel = L"y $[lx]$"
        if i == length(axes)
            ax.xlabel = L"x $[lx]$"
        else
            ax.xticklabelsvisible = false
        end
        Box(fig[i, 2]; color=:gray90)
        Label(
            fig[i, 2],
            "$(round(Int, angles[i]))";
            rotation=pi / 2,
            tellheight=false,
        )
    end

    for i ∈ 1:length(fig.layout.rowsizes)
        rowsize!(fig.layout, i, Aspect(1, 0.25))
    end

    resize_to_layout!(fig)

    steps = 30_000
    show_every = 50
    prog = Progress(steps ÷ show_every)

    path = joinpath(animations_dir, "wing_angles.mp4")
    record(
        fig,
        path,
        1:(steps÷show_every);
    ) do t
        next!(prog)
        for _ ∈ 1:show_every
            Threads.@threads for sim ∈ sim_observables
                singlethreaded_update!(sim[])
            end
        end
        for sim ∈ sim_observables
            notify(sim)
        end
    end
    return
end

# <<< animations
