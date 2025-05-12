using Revise
using BenchmarkTools

includet("simulation.jl")
includet("plots.jl")
includet("geometry.jl")
includet("workflows.jl")
println()

# make_direction_plots()

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
