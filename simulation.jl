using StaticArrays
using LinearAlgebra
using ProgressMeter

# abstract type Simulation end
# abstract type Simulation2D <: Simulation end
# abstract type Simulation3D <: Simulation end

# Requires two static conditionals
# https://discourse.julialang.org/t/is-importing-module-is-allowed-inside-static/28975/2
@static if Sys.isapple()
    import AppleAccelerate
end
@static if Sys.isapple()
    AppleAccelerate.@replaceBase(^, /)
end

struct Simulation{A,B,C}
    velocity_distribution::Array{Float64,B}
    velocity_distribution_buffer::Array{Float64,B}
    equilibrium_distribution::Array{Float64,B}
    mass_densities::Array{Float64,A}
    momentum_densities::Array{Float64,B}
    directions::SVector{C,SVector{A,Int8}}
    weights::SVector{C,Float64}
    lattice_speed_squared::Float64
    characteristic_time::Float64
    time_steps::Int
    delta_t::Float64
    object_mask::Array{Bool,A}
end

function Simulation{dimensions,directions}() where {dimensions,directions}
    return Simulation{
        dimensions,
        dimensions + 1,
        directions,
    }
end

const Simulation2D{directions} = Simulation{2,3,directions}
const Simulation2DQ9 = Simulation2D{9}

const Simulation3D{directions} = Simulation{3,4,directions}
const Simulation3DQ15 = Simulation3D{15}

function Simulation2DQ9(
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

    # bouncy upper and lower walls
    # object_mask[1:end, 1] .= true
    # object_mask[1:end, end] .= true

    return Simulation{2,9}()(
        velocity_distribution,
        similar(velocity_distribution),
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

function Simulation3DQ15(
    time_steps;
    divisions=(200, 100, 100),
)
    initial_velocity_distribution = ones(
        Float64,
        divisions...,
        15,
    )

    random_velocity_distribution = 1e-2 * randn(
        Float64,
        divisions...,
        15,
    )

    equilibrium_distribution = zeros(
        Float64,
        divisions...,
        15,
    )

    velocity_distribution = initial_velocity_distribution + random_velocity_distribution

    mass_densities = zeros(
        Float64,
        divisions...,
    )
    momentum_densities = zeros(
        Float64,
        divisions...,
        3,
    )

    directions = [
        [0, 0, 0],
        [1, 0, 0],
        [-1, 0, 0],
        [0, 1, 0],
        [0, -1, 0],
        [0, 0, 1],
        [0, 0, -1],
        [1, 1, 1],
        [1, 1, -1],
        [1, -1, 1],
        [1, -1, -1],
        [-1, 1, 1],
        [-1, 1, -1],
        [-1, -1, 1],
        [-1, -1, -1],
    ]

    # Weights from:
    # https://doi.org/10.1016/j.aej.2015.07.015
    weights = [
        2 / 9,
        1 / 9,
        1 / 9,
        1 / 9,
        1 / 9,
        1 / 9,
        1 / 9,
        1 / 72,
        1 / 72,
        1 / 72,
        1 / 72,
        1 / 72,
        1 / 72,
        1 / 72,
        1 / 72,
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

    # bouncy upper and lower walls
    # object_mask[:, :, 1] .= true
    # object_mask[:, :, end] .= true
    # object_mask[:, 1, :] .= true
    # object_mask[:, end, :] .= true

    return Simulation{3,15}()(
        velocity_distribution,
        similar(velocity_distribution),
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

function get_speeds(simulation::Simulation2D)
    velocities = (
        simulation.momentum_densities
        ./
        simulation.mass_densities
    )

    speeds = dropdims(
        sqrt.(sum(velocities .^ 2; dims=3));
        dims=3,
    )
    return speeds
end

function get_speeds(simulation::Simulation3D)
    velocities = (
        simulation.momentum_densities
        ./
        simulation.mass_densities
    )

    speeds = dropdims(
        sqrt.(sum(velocities .^ 2; dims=4));
        dims=4,
    )
    return speeds
end

function get_velocities_in_objects(simulation::Simulation2DQ9)
    # https://github.com/pmocz/latticeboltzmann-python/blob/main/latticeboltzmann.py
    velocities_in_objects = simulation.velocity_distribution[simulation.object_mask, :]
    velocities_in_objects = velocities_in_objects[:, [1, 4, 5, 2, 3, 8, 9, 6, 7]]
    return velocities_in_objects
end

function get_velocities_in_objects(simulation::Simulation3DQ15)
    # https://github.com/pmocz/latticeboltzmann-python/blob/main/latticeboltzmann.py
    #!format: off
    velocities_in_objects = simulation.velocity_distribution[simulation.object_mask, :]
    velocities_in_objects = (
        velocities_in_objects[
            :,
            [
                1,
                3,
                2,
                5,
                4,
                7,
                6,
                15,
                14,
                13,
                12,
                11,
                10,
                9,
                8
            ]
        ]
    )
    #!format: on
    return velocities_in_objects
end

function set_zou_he_boundaries!(simulation::Simulation2DQ9)
    # https://www.youtube.com/watch?v=JFWqCQHg-Hs&t=1032s
    # Zou He boundary condition
    simulation.velocity_distribution[end, :, [4, 7, 8]] .= (
        simulation.velocity_distribution[end-1, :, [4, 7, 8]]
    )
    simulation.velocity_distribution[1, :, [2, 6, 9]] = (
        simulation.velocity_distribution[2, :, [2, 6, 9]]
    )
    return
end

function set_zou_he_boundaries!(simulation::Simulation3DQ15)
    # https://www.youtube.com/watch?v=JFWqCQHg-Hs&t=1032s
    # Zou He boundary condition
    #!format: off
    simulation.velocity_distribution[
        end,
        :,
        :,
        [3, 12, 13, 14, 15],
    ] .= simulation.velocity_distribution[
        end-1,
        :,
        :,
        [3, 12, 13, 14, 15],
    ]
    simulation.velocity_distribution[
        1,
        :,
        :,
        [2, 8, 9, 10, 11],
    ] = simulation.velocity_distribution[
        2,
        :,
        :,
        [2, 8, 9, 10, 11],
    ]
    #!format: on
    return
end

@views function compute_momentum_densities!(simulation::Simulation2D)
    @inbounds for i ∈ axes(simulation.velocity_distribution, 2)
        for j ∈ axes(simulation.velocity_distribution, 1)
            #! format: off
            simulation.momentum_densities[j, i, :] = (
                sum(
                    simulation.directions
                    .* simulation.velocity_distribution[j, i, :],
                )
            )
            #! format: on
        end
    end
    return
end

@views function compute_momentum_densities!(simulation::Simulation3D)
    @inbounds for i ∈ axes(simulation.velocity_distribution, 3)
        for j ∈ axes(simulation.velocity_distribution, 2)
            for k ∈ axes(simulation.velocity_distribution, 1)
                #! format: off
                simulation.momentum_densities[k, j, i, :] = (
                    sum(
                        simulation.directions
                        .* simulation.velocity_distribution[k, j, i, :],
                    )
                )
                #! format: on
            end
        end
    end
    return
end

function compute_mass_densities!(simulation::Simulation2D)
    #tried
    # - @views
    simulation.mass_densities .=
        dropdims(sum(simulation.velocity_distribution; dims=3); dims=3)
    return
end

function compute_mass_densities!(simulation::Simulation3D)
    #tried
    # - @views
    simulation.mass_densities .=
        dropdims(sum(simulation.velocity_distribution; dims=4); dims=4)
    return
end

@views function compute_equilibrium_distribution!(simulation::Simulation2D)
    u = simulation.momentum_densities ./ simulation.mass_densities

    uu = @. u[:, :, 1]^2 + u[:, :, 2]^2

    c1 = (3 / simulation.lattice_speed_squared)
    c2 = (9 / (2 * simulation.lattice_speed_squared^2))
    c3 = (3 / (2 * simulation.lattice_speed_squared))

    @inbounds for i ∈ axes(simulation.equilibrium_distribution, 3)
        uv = @. (
            simulation.directions[i][1] * u[:, :, 1]
            +
            simulation.directions[i][2] * u[:, :, 2]
        )

        #! format: off
        # Tried
        # - @views

        @. simulation.equilibrium_distribution[:,:,i] = (
            simulation.weights[i]
            * simulation.mass_densities
            * (
                1
                + (c1 * uv)
                + (c2 * uv.^2)
                - (c3 * uu)
            )
        )
        #! format: on
    end
    return
end

@views function compute_equilibrium_distribution!(simulation::Simulation3D)
    u = simulation.momentum_densities ./ simulation.mass_densities

    # uu = sum(u .^ 2; dims=3)[:, :, 1]
    uu = @. u[:, :, :, 1]^2 + u[:, :, :, 2]^2 + u[:, :, :, 3]^2

    c1 = (3 / simulation.lattice_speed_squared)
    c2 = (9 / (2 * simulation.lattice_speed_squared^2))
    c3 = (3 / (2 * simulation.lattice_speed_squared))

    @inbounds for i ∈ axes(simulation.equilibrium_distribution, 4)
        #! format: off
        uv = @. (
            simulation.directions[i][1] * u[:, :, :, 1]
            + simulation.directions[i][2] * u[:, :, :, 2]
            + simulation.directions[i][3] * u[:, :, :, 3]
        )

        # Tried
        # - @views

        @. simulation.equilibrium_distribution[:,:,:,i] = (
            simulation.weights[i]
            * simulation.mass_densities
            * (
                1
                + (c1 * uv)
                + (c2 * uv.^2)
                - (c3 * uu)
            )
        )
        #! format: on
    end
    return
end

function collide!(simulation::Simulation)
    #! format: off
    @. simulation.velocity_distribution = (
        simulation.velocity_distribution
        + (simulation.delta_t / simulation.characteristic_time)
        * (simulation.equilibrium_distribution - simulation.velocity_distribution)
    )
    #! format: on

    return
end

function stream!(simulation::Simulation2D)
    simulation.velocity_distribution_buffer .= simulation.velocity_distribution

    @inbounds for i ∈ axes(simulation.velocity_distribution, 3)
        dx, dy = simulation.directions[i]
        nx, ny = size(simulation.velocity_distribution)[1:2]

        for j ∈ 1:ny, k ∈ 1:nx
            dest_x = mod1(k + dx, nx)
            dest_y = mod1(j + dy, ny)
            simulation.velocity_distribution[dest_x, dest_y, i] = (
                simulation.velocity_distribution_buffer[k, j, i]
            )
        end
    end
    return
end

function stream!(simulation::Simulation3D)
    simulation.velocity_distribution_buffer .= simulation.velocity_distribution

    @inbounds Threads.@threads for i ∈ axes(simulation.velocity_distribution, 4)
        dx, dy, dz = simulation.directions[i]
        nx, ny, nz = size(simulation.velocity_distribution)[1:3]

        for j ∈ 1:nz, k ∈ 1:ny, m ∈ 1:nx
            dest_x = mod1(m + dx, nx)
            dest_y = mod1(k + dy, ny)
            dest_z = mod1(j + dz, nz)
            simulation.velocity_distribution[dest_x, dest_y, dest_z, i] = (
                simulation.velocity_distribution_buffer[m, k, j, i]
            )
        end
    end
    return
end

function update!(simulation::Simulation2D)
    set_zou_he_boundaries!(simulation)

    simulation.velocity_distribution[2, :, 2] .= 2

    velocities_in_objects = get_velocities_in_objects(simulation)

    compute_mass_densities!(simulation)
    compute_momentum_densities!(simulation)

    compute_equilibrium_distribution!(simulation)

    collide!(simulation)

    simulation.velocity_distribution[simulation.object_mask, :] = velocities_in_objects
    simulation.momentum_densities[simulation.object_mask, :] .= 0

    stream!(simulation)

    return
end

function update!(simulation::Simulation3D)
    set_zou_he_boundaries!(simulation)

    simulation.velocity_distribution[5, :, :, 2] .= 2

    velocities_in_objects = get_velocities_in_objects(simulation)

    compute_mass_densities!(simulation)
    compute_momentum_densities!(simulation)

    compute_equilibrium_distribution!(simulation)

    collide!(simulation)

    simulation.velocity_distribution[simulation.object_mask, :] = velocities_in_objects
    simulation.momentum_densities[simulation.object_mask, :] .= 0

    stream!(simulation)

    return
end

function compute_momentum_densities!(
    simulation::Simulation2D,
    chunk_start::Int,
    chunk_end::Int,
)
    @inbounds for i ∈ chunk_start:chunk_end
        for j ∈ axes(simulation.velocity_distribution, 1)
            #! format: off
            @views simulation.momentum_densities[j, i, :] = (
                sum(
                    simulation.directions
                    .* simulation.velocity_distribution[j, i, :],
                )
            )
            #! format: on
        end
    end
    return
end

function compute_momentum_densities!(
    simulation::Simulation3D,
    chunk_start::Int,
    chunk_end::Int,
)
    @inbounds for i ∈ chunk_start:chunk_end
        for j ∈ axes(simulation.velocity_distribution, 2)
            for k ∈ axes(simulation.velocity_distribution, 1)
                #! format: off
                @views simulation.momentum_densities[k, j, i, :] = (
                    sum(
                        simulation.directions
                        .* simulation.velocity_distribution[k, j, i, :],
                    )
                )
                #! format: on
            end
        end
    end
    return
end

function compute_mass_densities!(simulation::Simulation2D, chunk_start::Int, chunk_end::Int)
    #tried
    # - @views
    @views simulation.mass_densities[:, chunk_start:chunk_end] .=
        dropdims(
            sum(simulation.velocity_distribution[:, chunk_start:chunk_end, :]; dims=3);
            dims=3,
        )
    return
end

function compute_mass_densities!(simulation::Simulation3D, chunk_start::Int, chunk_end::Int)
    #tried
    # - @views
    @views simulation.mass_densities[:, :, chunk_start:chunk_end] .=
        dropdims(
            sum(simulation.velocity_distribution[:, :, chunk_start:chunk_end, :]; dims=4);
            dims=4,
        )
    return
end

@views function compute_equilibrium_distribution!(
    simulation::Simulation2D,
    chunk_start::Int,
    chunk_end::Int,
)
    u =
        simulation.momentum_densities[:, chunk_start:chunk_end, :] ./
        simulation.mass_densities[:, chunk_start:chunk_end]

    uu = @. u[:, :, 1]^2 + u[:, :, 2]^2

    c1 = (3 / simulation.lattice_speed_squared)
    c2 = (9 / (2 * simulation.lattice_speed_squared^2))
    c3 = (3 / (2 * simulation.lattice_speed_squared))

    @inbounds for i ∈ axes(simulation.equilibrium_distribution, 3)
        #! format: off
        uv = @. (
            simulation.directions[i][1] * u[:, :, 1]
            + simulation.directions[i][2] * u[:, :, 2]
        )

        # Tried
        # - @views

        @. simulation.equilibrium_distribution[:,chunk_start:chunk_end,i] = (
            simulation.weights[i]
            * simulation.mass_densities[:, chunk_start:chunk_end]
            * (
                1
                + (c1 * uv)
                + (c2 * uv.^2)
                - (c3 * uu)
            )
        )
        #! format: on
    end
    return
end

@views function compute_equilibrium_distribution!(
    simulation::Simulation3D,
    chunk_start::Int,
    chunk_end::Int,
)
    u =
        simulation.momentum_densities[:, :, chunk_start:chunk_end, :] ./
        simulation.mass_densities[:, :, chunk_start:chunk_end]

    uu = @. u[:, :, :, 1]^2 + u[:, :, :, 2]^2 + u[:, :, :, 3]^2

    c1 = (3 / simulation.lattice_speed_squared)
    c2 = (9 / (2 * simulation.lattice_speed_squared^2))
    c3 = (3 / (2 * simulation.lattice_speed_squared))

    @inbounds for i ∈ axes(simulation.equilibrium_distribution, 4)
        uv = @. (
            simulation.directions[i][1] * u[:, :, :, 1]
            + simulation.directions[i][2] * u[:, :, :, 2]
            + simulation.directions[i][3] * u[:, :, :, 3]
        )

        #! format: off
        # Tried
        # - @views

        @. simulation.equilibrium_distribution[:, :, chunk_start:chunk_end,i] = (
            simulation.weights[i]
            * simulation.mass_densities[:, :, chunk_start:chunk_end]
            * (
                1
                + (c1 * uv)
                + (c2 * uv.^2)
                - (c3 * uu)
            )
        )
        #! format: on
    end
    return
end

@views function collide!(simulation::Simulation2D, chunk_start::Int, chunk_end::Int)
    #! format: off
    @. simulation.velocity_distribution[:, chunk_start:chunk_end, :] = (
        simulation.velocity_distribution[:, chunk_start:chunk_end, :]
        + (simulation.delta_t / simulation.characteristic_time)
        * (
            simulation.equilibrium_distribution[:, chunk_start:chunk_end, :]
            - simulation.velocity_distribution[:, chunk_start:chunk_end, :])
    )
    #! format: on

    return
end
@views function collide!(simulation::Simulation3D, chunk_start::Int, chunk_end::Int)
    #! format: off
    @. simulation.velocity_distribution[:, :, chunk_start:chunk_end, :] = (
        simulation.velocity_distribution[:, :, chunk_start:chunk_end, :]
        + (simulation.delta_t / simulation.characteristic_time)
        * (
            simulation.equilibrium_distribution[:, :, chunk_start:chunk_end, :]
            - simulation.velocity_distribution[:, :, chunk_start:chunk_end, :])
    )
    #! format: on

    return
end

function multithreaded_update!(simulation::Simulation2D)
    set_zou_he_boundaries!(simulation)

    simulation.velocity_distribution[2, :, 2] .= 2

    velocities_in_objects = get_velocities_in_objects(simulation)

    threads = Threads.nthreads()

    dimension_size = size(simulation.velocity_distribution)[2]
    chunksize = div(dimension_size, threads, RoundUp)

    Threads.@threads for thread_index ∈ 1:threads
        chunk_start = ((thread_index - 1) * chunksize) + 1
        chunk_end = min(
            ((thread_index) * chunksize),
            dimension_size,
        )

        compute_mass_densities!(simulation, chunk_start, chunk_end)
        compute_momentum_densities!(simulation, chunk_start, chunk_end)
        compute_equilibrium_distribution!(simulation, chunk_start, chunk_end)

        collide!(simulation, chunk_start, chunk_end)
    end

    simulation.velocity_distribution[simulation.object_mask, :] = velocities_in_objects
    simulation.momentum_densities[simulation.object_mask, :] .= 0

    stream!(simulation)

    return
end

function multithreaded_update!(simulation::Simulation3D)
    set_zou_he_boundaries!(simulation)

    simulation.velocity_distribution[5, :, :, 2] .= 4

    velocities_in_objects = get_velocities_in_objects(simulation)

    threads = Threads.nthreads()

    dimension_size = size(simulation.velocity_distribution)[3]
    chunksize = div(dimension_size, threads, RoundUp)

    Threads.@threads for thread_index ∈ 1:threads
        chunk_start = ((thread_index - 1) * chunksize) + 1
        chunk_end = min(
            ((thread_index) * chunksize),
            dimension_size,
        )

        # https://github.com/pmocz/latticeboltzmann-python/blob/main/latticeboltzmann.py
        compute_mass_densities!(simulation, chunk_start, chunk_end)
        compute_momentum_densities!(simulation, chunk_start, chunk_end)
        compute_equilibrium_distribution!(simulation, chunk_start, chunk_end)

        collide!(simulation, chunk_start, chunk_end)
    end

    simulation.velocity_distribution[simulation.object_mask, :] = velocities_in_objects
    simulation.momentum_densities[simulation.object_mask, :] .= 0

    stream!(simulation)

    return
end

function run!(
    simulation::Simulation;
    prog=nothing,
    save_every=100,
)
    prog = something(
        prog,
        Progress(simulation.time_steps),
    )
    simulations::Vector{Simulation} = []

    if Threads.nthreads == 1
        step! = update!
    else
        step! = multithreaded_update!
    end

    for (i, _) ∈ enumerate(1:simulation.time_steps)
        next!(prog)
        step!(simulation)
        if i % save_every == 0
            push!(simulations, deepcopy(simulation))
        end
    end
    return simulations
end
