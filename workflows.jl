include("simulation.jl")
include("plots.jl")

output_dir = "report/media"
mkpath(output_dir)

function single_sphere_scene()
    simulation = SimulationD2Q9(
        1000,
        # 100_000,
    )
    add_sphere!(
        simulation;
        position=(50, 50),
        radius=25,
    )
    return animate_speeds!(simulation)
end

function make_direction_plots()
    with_theme(
        Theme(;
            fontsize=20,
            markersize=20,
        ),
    ) do
        f = plot_directions(SimulationD2Q9(100; divisions=(10, 10)))
        display(f)
        path = joinpath(output_dir, "directions_d2q9.png")
        save(path, f)

        f = plot_directions(SimulationD3Q15(100; divisions=(10, 10, 10)))
        display(f)
        path = joinpath(output_dir, "directions_d3q15.png")
        return save(path, f)
    end
end
