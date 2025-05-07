using Profile
using BenchmarkTools

include("simulation.jl")
include("plots.jl")

simulation = Simulation(
    100,
)

add_sphere!(
    simulation;
    position=(50, 50),
    radius=25,
)
