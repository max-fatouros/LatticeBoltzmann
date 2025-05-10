using Revise
using Profile
using BenchmarkTools

includet("simulation.jl")
includet("plots.jl")
includet("geometry.jl")

# simulation = Simulation{2, 9}(
#     100_000,
# )

# add_sphere!(
#     simulation;
#     position=(50, 50),
#     radius=25,
# )

simulation = Simulation3DQ15(
    500;
    divisions=(75, 30, 30),
)

# add_sphere!(
#     simulation;
#     position=(15, 15, 15),
#     radius=10,
# )

add_rectangle!(
    simulation;
    position=(15, 15, 15),
    lengths=(2, 5, 5),
)

update!(simulation)
