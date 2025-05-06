using StaticArrays
using LinearAlgebra
using ProgressMeter

struct Simulation
    velocity_distribution::Array{Float64,3}
    equilibrium_distribution::Array{Float64,3}
    mass_densities::Array{Float64,2}
    momentum_densities::Array{Float64,3}
    directions::SVector{9,SVector{2,Int8}}
    weights::SVector{9,Float64}
    lattice_speed_squared::Float64
    characteristic_time::Float64
    time_steps::Int
    delta_t::Float64
    object_mask::Array{Bool,2}
end

function Simulation(
    time_steps;
    divisions=(400, 100),
)
    initial_velocity_distribution = ones(
        Float64,
        divisions...,
        9,
    )

    random_velocity_distribution = 1e-2 * randn(
        Float64,
        divisions...,
        9,
    )

    equilibrium_distribution = zeros(
        Float64,
        divisions...,
        9,
    )

    velocity_distribution = initial_velocity_distribution + random_velocity_distribution

    velocity_distribution[:, :, 2] .= 2

    mass_densities = zeros(
        Float64,
        divisions...,
    )
    momentum_densities = zeros(
        Float64,
        divisions...,
        2,
    )

    directions = [
        [0, 0],
        [1, 0],
        [0, 1],
        [-1, 0],
        [0, -1],
        [1, 1],
        [-1, 1],
        [-1, -1],
        [1, -1],
    ]

    # directions = [
    #     [0,0],
    #     [0,1],
    #     [-1,0],
    #     [0,-1],
    #     [1,0],
    #     [-1, 1],
    #     [-1, -1],
    #     [1, -1],
    #     [1,1],
    # ]

    weights = [
        4 / 9,
        1 / 9,
        1 / 9,
        1 / 9,
        1 / 9,
        1 / 36,
        1 / 36,
        1 / 36,
        1 / 36,
    ]

    # delta_t = 5e-3
    delta_t = 1

    # TODO: compute this properly later
    delta_x = 1 / divisions[1]
    # lattice_speed_squared = (1/3) * (delta_x^2 / delta_t^2)
    lattice_speed_squared = 1

    characteristic_time = 0.6

    object_mask = zeros(
        Bool,
        divisions...,
    )

    # object_mask[1, 1:end] .= true
    # object_mask[end, 1:end] .= true
    # object_mask[1:end, 1] .= true
    # object_mask[1:end, end] .= true

    return Simulation(
        velocity_distribution,
        equilibrium_distribution,
        mass_densities,
        momentum_densities,
        directions,
        weights,
        lattice_speed_squared,
        characteristic_time,
        time_steps,
        delta_t,
        object_mask,
    )
end

function compute_momentum_densities!(simulation::Simulation)
    for i ∈ axes(simulation.velocity_distribution, 2)
        for j ∈ axes(simulation.velocity_distribution, 1)
            simulation.momentum_densities[j, i, :] = (
                sum(
                simulation.directions
                .* simulation.velocity_distribution[j, i, :],
            )
            )
        end
    end
    return
end

function compute_mass_densities!(simulation::Simulation)
    #tried
    # - @views
    simulation.mass_densities .=
        dropdims(sum(simulation.velocity_distribution; dims=3); dims=3)
    return
end

function vector_matrix_dot_product(
    vector::SVector{2,Int8},
    matrix::Array{Float64,3},
)
    result = similar(matrix[:, :, 1])
    result .= 0
    for i ∈ 1:length(vector)
        result += matrix[:, :, i] * vector[i]
    end
    return result
end

function compute_equilibrium_distribution!(simulation::Simulation)
    u = simulation.momentum_densities ./ simulation.mass_densities
    for i ∈ axes(simulation.equilibrium_distribution, 3)
        uv = vector_matrix_dot_product(
            simulation.directions[i],
            u,
        )

        #! format: off
        simulation.equilibrium_distribution[:,:,i] = (
            simulation.weights[i]
            * simulation.mass_densities
            .* (
                1
                .+ (
                    (3/simulation.lattice_speed_squared)
                    * uv
                )
                + (
                    (9/(2 * simulation.lattice_speed_squared^2))
                    * uv.^2
                )
                - (
                    (3/(2 * simulation.lattice_speed_squared))
                    * sum(u[:,:,i].^2 for i in axes(u, 3))
                )
            )
        )
        #! format: on
    end
    return
end

function opt_compute_equilibrium_distribution!(simulation::Simulation)
    u = simulation.momentum_densities ./ simulation.mass_densities
    for i ∈ axes(simulation.equilibrium_distribution, 3)
        uv = vector_matrix_dot_product(
            simulation.directions[i],
            u,
        )

        #! format: off
        # Tried
        # - @views
        simulation.equilibrium_distribution[:,:,i] = @views (
            simulation.weights[i]
            * simulation.mass_densities
            .* (
                1
                .+ (
                    (3/simulation.lattice_speed_squared)
                    * uv
                )
                + (
                    (9/(2 * simulation.lattice_speed_squared^2))
                    * uv.^2
                )
                - (
                    (3/(2 * simulation.lattice_speed_squared))
                    * sum(u[:,:,i].^2 for i in axes(u, 3))
                )
            )
        )
        #! format: on
    end
    return
end

function collide!(simulation::Simulation)
    #! format: off
    simulation.velocity_distribution .= (
        simulation.velocity_distribution
        + (simulation.delta_t / simulation.characteristic_time)
        * (simulation.equilibrium_distribution - simulation.velocity_distribution)
    )
    #! format: on

    return
end

function stream!(simulation::Simulation)
    for i ∈ axes(simulation.velocity_distribution, 3)
        simulation.velocity_distribution[:, :, i] = circshift(
            simulation.velocity_distribution[:, :, i],
            simulation.directions[i],
        )
    end
    return
end

function update!(simulation::Simulation)
    stream!(simulation)

    # https://github.com/pmocz/latticeboltzmann-python/blob/main/latticeboltzmann.py
    boundary_points = simulation.velocity_distribution[simulation.object_mask, :]
    boundary_points = boundary_points[:, [1, 4, 5, 2, 3, 8, 9, 6, 7]]

    compute_mass_densities!(simulation)
    compute_momentum_densities!(simulation)

    compute_equilibrium_distribution!(simulation)

    collide!(simulation)

    simulation.velocity_distribution[simulation.object_mask, :] = boundary_points
    simulation.momentum_densities[simulation.object_mask, :] .= 0

    return
end

function run!(
    simulation::Simulation;
    prog=nothing,
)
    prog = something(
        prog,
        Progress(simulation.time_steps),
    )
    simulations::Vector{Simulation} = []

    for (i, _) ∈ enumerate(1:simulation.time_steps)
        next!(prog)
        update!(simulation)
        if i % 100 == 0
            push!(simulations, deepcopy(simulation))
        end
    end
    return simulations
end

function add_sphere!(
    simulation::Simulation;
    position,
    radius,
)
    cartesian_position = CartesianIndex(position...)
    for index ∈ CartesianIndices(simulation.object_mask)
        r = index - cartesian_position
        r_norm = norm(Tuple(r))
        if r_norm < radius
            simulation.object_mask[index] = true
        end
    end
end
