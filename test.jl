using Profile
using BenchmarkTools

include("simulation.jl")
include("plots.jl")
include("geometry.jl")

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

add_sphere!(
    simulation;
    position=(15, 15, 15),
    radius=10,
)

update!(simulation)
