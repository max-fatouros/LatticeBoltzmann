using Revise
using Profile
using BenchmarkTools

includet("simulation.jl")
includet("plots.jl")
includet("geometry.jl")

# simulation = Simulation2DQ9(
#     100_000,
# )

# add_sphere!(
#     simulation;
#     position=(50, 50),
#     radius=25,
# )

# cylinder vortices
# simulation = Simulation3DQ15(
#     500;
#     divisions=(75, 30, 30),
# )

# add_rectangle!(
#     simulation;
#     position=(15, 15, 15),
#     lengths=(2, 5, 5),
# )

simulation = Simulation3DQ15(
    1000;
    divisions=(75, 30, 30),
)

add_point_cloud(
    simulation;
    filename="fan.xyz",
    position=(15, 15, 15),
    rotation=(0, pi / 2, pi),
    side_length=10,
)
