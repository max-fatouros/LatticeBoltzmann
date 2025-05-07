using BenchmarkTools

include("simulation.jl")
include("plots.jl")
include("geometry.jl")
println()

function single_sphere_scene()
    simulation = Simulation2DQ9(
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

simulation = Simulation2DQ9(
    1000,
    # 100_000,
)
add_sphere!(
    simulation;
    position=(50, 50),
    radius=25,
)
animate_speeds_live!(simulation)

# simulation = Simulation{2}(
#     # 1000,
#     100_000,
# )

# add_sphere!(
#     simulation;
#     position=(40, 60),
#     radius=10,
# )
# add_sphere!(
#     simulation;
#     position=(60, 40),
#     radius=10,
# )

# simulations = run!(simulation)
# animate_speeds_with_slider(
#     simulations
# )
# #
# animate_speeds_live(simulation)
