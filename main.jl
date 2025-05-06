using BenchmarkTools

include("simulation.jl")
include("plots.jl")
println()

simulation = Simulation(
    100,
)

add_sphere!(
    simulation;
    position=(50, 50),
    radius=25,
)

simulations = run!(simulation)
# animate_speeds_live(
#     simulation,
#     100_000,
# )

# for i in CartesianIndices(simulation.grid[1,1,:,:])
#     @show i
# end

# @info size(simulation.grid)
