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
    100;
    divisions=(100, 50, 50),
)

add_sphere!(
    simulation;
    position=(30, 25, 25),
    radius=15,
)
