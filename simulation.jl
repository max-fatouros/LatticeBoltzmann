using StaticArrays
using LinearAlgebra
using ProgressMeter

# Requires two static conditionals
# https://discourse.julialang.org/t/is-importing-module-is-allowed-inside-static/28975/2
@static if Sys.isapple()
    import AppleAccelerate
end
@static if Sys.isapple()
    AppleAccelerate.@replaceBase(^, /)
end

Range = Union{Int,UnitRange,Colon}

struct Source{N}
    ranges::SVector{N,Range}
    dimension::Int8
    speed::Float64
end

# to avoid making the Simulation struct mutable
mutable struct Parameters
    characteristic_time::Float64
    time_steps::Int
end

struct Simulation{A,B,C}
    velocity_distribution::Array{Float64,B}
    velocity_distribution_buffer::Array{Float64,B}
    equilibrium_distribution::Array{Float64,B}
    mass_densities::Array{Float64,A}
    momentum_densities::Array{Float64,B}
    velocities::SVector{C,SVector{A,Int8}}
    weights::SVector{C,Float64}
    lattice_speed_squared::Float64
    delta_t::Float64
    object_mask::Array{Bool,A}
    sources::Vector{Source{A}}
    parameters::Parameters
end

function Simulation{dimensions,velocities}() where {dimensions,velocities}
    return Simulation{
        dimensions,
        dimensions + 1,
        velocities,
    }
end

const SimulationD2{velocities} = Simulation{2,3,velocities}
const SimulationD2Q9 = SimulationD2{9}

const SimulationD3{velocities} = Simulation{3,4,velocities}
const SimulationD3Q15 = SimulationD3{15}

function SimulationD2Q9(
    time_steps;
    divisions=(400, 100),
)
    velocity_distribution = ones(
        Float64,
        divisions...,
        9,
    )

    equilibrium_distribution = zeros(
        Float64,
        divisions...,
        9,
    )

    mass_densities = zeros(
        Float64,
        divisions...,
    )
    momentum_densities = zeros(
        Float64,
        divisions...,
        2,
    )

    velocities = [
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

    # defined such that lattice_speed_squared == 1
    delta_t = 1
    delta_x = 1
    lattice_speed_squared = (delta_x / delta_t)^2

    characteristic_time = 1

    object_mask = zeros(
        Bool,
        divisions...,
    )

    # bouncy upper and lower walls
    # object_mask[1:end, 1] .= true
    # object_mask[1:end, end] .= true

    simulation = SimulationD2Q9(
        velocity_distribution,
        similar(velocity_distribution),
        equilibrium_distribution,
        mass_densities,
        momentum_densities,
        velocities,
        weights,
        lattice_speed_squared,
        delta_t,
        object_mask,
        [],
        Parameters(
            characteristic_time,
            time_steps,
        ),
    )

    reset!(simulation)
    return simulation
end

function SimulationD3Q15(
    time_steps;
    divisions=(200, 100, 100),
)
    velocity_distribution = ones(
        Float64,
        divisions...,
        15,
    )

    equilibrium_distribution = zeros(
        Float64,
        divisions...,
        15,
    )

    mass_densities = zeros(
        Float64,
        divisions...,
    )
    momentum_densities = zeros(
        Float64,
        divisions...,
        3,
    )

    velocities = [
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

    # defined such that lattice_speed_squared == 1
    delta_t = 1
    delta_x = 1
    lattice_speed_squared = (delta_x / delta_t)^2

    characteristic_time = 1

    object_mask = zeros(
        Bool,
        divisions...,
    )

    # bouncy upper and lower walls
    # object_mask[:, :, 1] .= true
    # object_mask[:, :, end] .= true
    # object_mask[:, 1, :] .= true
    # object_mask[:, end, :] .= true

    simulation = SimulationD3Q15(
        velocity_distribution,
        similar(velocity_distribution),
        equilibrium_distribution,
        mass_densities,
        momentum_densities,
        velocities,
        weights,
        lattice_speed_squared,
        delta_t,
        object_mask,
        [],
        Parameters(
            characteristic_time,
            time_steps,
        ),
    )

    reset!(simulation)

    return simulation
end

function reset!(simulation::SimulationD2Q9)
    initial_velocity_distribution = ones(
        Float64,
        size(simulation.mass_densities)...,
        9,
    )

    random_velocity_distribution =
        1e-2 * randn(
            Float64,
            size(simulation.mass_densities)...,
            9,
        )

    equilibrium_distribution = zeros(
        Float64,
        size(simulation.mass_densities)...,
        9,
    )

    velocity_distribution = initial_velocity_distribution + random_velocity_distribution

    mass_densities = zeros(
        Float64,
        size(simulation.mass_densities)...,
    )
    momentum_densities = zeros(
        Float64,
        size(simulation.mass_densities)...,
        2,
    )

    simulation.velocity_distribution .= velocity_distribution
    simulation.mass_densities .= mass_densities
    simulation.momentum_densities .= momentum_densities

    @info "reset $(typeof(simulation))"
    @info "threads: $(Threads.nthreads())"
    return
end

function reset!(simulation::SimulationD3Q15)
    initial_velocity_distribution = ones(
        Float64,
        size(simulation.mass_densities)...,
        15,
    )

    random_velocity_distribution =
        1e-2 * randn(
            Float64,
            size(simulation.mass_densities)...,
            15,
        )

    equilibrium_distribution = zeros(
        Float64,
        size(simulation.mass_densities)...,
        15,
    )

    velocity_distribution = initial_velocity_distribution + random_velocity_distribution

    mass_densities = zeros(
        Float64,
        size(simulation.mass_densities)...,
    )
    momentum_densities = zeros(
        Float64,
        size(simulation.mass_densities)...,
        3,
    )

    simulation.velocity_distribution .= velocity_distribution
    simulation.mass_densities .= mass_densities
    simulation.momentum_densities .= momentum_densities

    @info "reset $(typeof(simulation))"
    @info "threads: $(Threads.nthreads())"
    return
end

function get_speeed_of_sound(simulation::Simulation)
    return sqrt(simulation.lattice_speed_squared / 3)
end

function get_viscosity(simulation::Simulation)
    return (
               (simulation.parameters.characteristic_time - 0.5)
           ) * get_speeed_of_sound(simulation)^2 * simulation.delta_t
end

function get_reynolds_number(
    simulation::Simulation;
    dimension=2,
)
    if length(simulation.sources) > 1
        throw(ErrorException("Stream velocity ambiguous for multiple sources"))
    end

    if length(simulation.sources) == 0
        throw(ErrorException("Simulation must have one source to define Reynolds number"))
    end

    return (
        (
            simulation.sources[1].speed
            *
            size(simulation.mass_densities, dimension)
        )
        /
        get_viscosity(simulation)
    )
end

function set_sources!(simulation::Simulation)
    for source ∈ simulation.sources
        @. simulation.momentum_densities[source.ranges..., source.dimension] =
            source.speed * simulation.mass_densities[source.ranges...]
    end
end

function get_speeds(simulation::SimulationD2)
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

function get_speeds(simulation::SimulationD3)
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

function get_velocities_in_objects(simulation::SimulationD2Q9)
    # https://github.com/pmocz/latticeboltzmann-python/blob/main/latticeboltzmann.py
    velocities_in_objects = simulation.velocity_distribution[simulation.object_mask, :]
    velocities_in_objects = velocities_in_objects[:, [1, 4, 5, 2, 3, 8, 9, 6, 7]]
    return velocities_in_objects
end

function get_velocities_in_objects(simulation::SimulationD3Q15)
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

"""
# zero acceleration Neumann boundary conditions
- https://ntrs.nasa.gov/api/citations/20020063595/downloads/20020063595.pdf

"""
function set_no_bounce_boundaries!(simulation::Simulation) end

function set_no_bounce_boundaries!(simulation::SimulationD2Q9)
    simulation.velocity_distribution[end, :, :] .= (
        simulation.velocity_distribution[end-1, :, :]
    )
    simulation.velocity_distribution[1, :, :] = (
        simulation.velocity_distribution[2, :, :]
    )
    return
end

function set_no_bounce_boundaries!(simulation::SimulationD3Q15)
    simulation.velocity_distribution[end, :, :, :] .= (
        simulation.velocity_distribution[end-1, :, :, :]
    )
    simulation.velocity_distribution[1, :, :, :] = (
        simulation.velocity_distribution[2, :, :, :]
    )
    return
end

@views function compute_momentum_densities!(simulation::SimulationD2)
    @inbounds for i ∈ axes(simulation.velocity_distribution, 2)
        for j ∈ axes(simulation.velocity_distribution, 1)
            #! format: off
            simulation.momentum_densities[j, i, :] = (
                sum(
                    simulation.velocities
                    .* simulation.velocity_distribution[j, i, :],
                )
            )
            #! format: on
        end
    end
    return
end

@views function compute_momentum_densities!(simulation::SimulationD3)
    @inbounds for i ∈ axes(simulation.velocity_distribution, 3)
        for j ∈ axes(simulation.velocity_distribution, 2)
            for k ∈ axes(simulation.velocity_distribution, 1)
                #! format: off
                simulation.momentum_densities[k, j, i, :] = (
                    sum(
                        simulation.velocities
                        .* simulation.velocity_distribution[k, j, i, :],
                    )
                )
                #! format: on
            end
        end
    end
    return
end

function compute_mass_densities!(simulation::SimulationD2)
    #tried
    # - @views
    simulation.mass_densities .=
        dropdims(sum(simulation.velocity_distribution; dims=3); dims=3)
    return
end

function compute_mass_densities!(simulation::SimulationD3)
    #tried
    # - @views
    simulation.mass_densities .=
        dropdims(sum(simulation.velocity_distribution; dims=4); dims=4)
    return
end

@views function compute_equilibrium_distribution!(simulation::SimulationD2)
    u = simulation.momentum_densities ./ simulation.mass_densities

    uu = @. u[:, :, 1]^2 + u[:, :, 2]^2

    c1 = (3 / simulation.lattice_speed_squared)
    c2 = (9 / (2 * simulation.lattice_speed_squared^2))
    c3 = (3 / (2 * simulation.lattice_speed_squared))

    @inbounds for i ∈ axes(simulation.equilibrium_distribution, 3)
        uv = @. (
            simulation.velocities[i][1] * u[:, :, 1]
            +
            simulation.velocities[i][2] * u[:, :, 2]
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

@views function compute_equilibrium_distribution!(simulation::SimulationD3)
    u = simulation.momentum_densities ./ simulation.mass_densities

    # uu = sum(u .^ 2; dims=3)[:, :, 1]
    uu = @. u[:, :, :, 1]^2 + u[:, :, :, 2]^2 + u[:, :, :, 3]^2

    c1 = (3 / simulation.lattice_speed_squared)
    c2 = (9 / (2 * simulation.lattice_speed_squared^2))
    c3 = (3 / (2 * simulation.lattice_speed_squared))

    @inbounds for i ∈ axes(simulation.equilibrium_distribution, 4)
        #! format: off
        uv = @. (
            simulation.velocities[i][1] * u[:, :, :, 1]
            + simulation.velocities[i][2] * u[:, :, :, 2]
            + simulation.velocities[i][3] * u[:, :, :, 3]
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
        + (simulation.delta_t / simulation.parameters.characteristic_time)
        * (simulation.equilibrium_distribution - simulation.velocity_distribution)
    )
    #! format: on

    return
end

function stream!(simulation::SimulationD2)
    simulation.velocity_distribution_buffer .= simulation.velocity_distribution

    @inbounds for i ∈ axes(simulation.velocity_distribution, 3)
        dx, dy = simulation.velocities[i]
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

function stream!(simulation::SimulationD3)
    simulation.velocity_distribution_buffer .= simulation.velocity_distribution

    @inbounds Threads.@threads for i ∈ axes(simulation.velocity_distribution, 4)
        dx, dy, dz = simulation.velocities[i]
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

function singlethreaded_update!(simulation::SimulationD2)
    velocities_in_objects = get_velocities_in_objects(simulation)

    compute_mass_densities!(simulation)
    compute_momentum_densities!(simulation)
    set_sources!(simulation)

    compute_equilibrium_distribution!(simulation)

    collide!(simulation)
    set_no_bounce_boundaries!(simulation)

    simulation.velocity_distribution[simulation.object_mask, :] = velocities_in_objects
    simulation.momentum_densities[simulation.object_mask, :] .= 0

    stream!(simulation)
    return
end

function singlethreaded_update!(simulation::SimulationD3)
    velocities_in_objects = get_velocities_in_objects(simulation)

    compute_mass_densities!(simulation)
    compute_momentum_densities!(simulation)
    set_sources!(simulation)
    compute_equilibrium_distribution!(simulation)

    collide!(simulation)
    set_no_bounce_boundaries!(simulation)

    simulation.velocity_distribution[simulation.object_mask, :] = velocities_in_objects
    simulation.momentum_densities[simulation.object_mask, :] .= 0

    stream!(simulation)

    return
end

function compute_momentum_densities!(
    simulation::SimulationD2,
    chunk_start::Int,
    chunk_end::Int,
)
    @inbounds for i ∈ chunk_start:chunk_end
        for j ∈ axes(simulation.velocity_distribution, 1)
            #! format: off
            @views simulation.momentum_densities[j, i, :] = (
                sum(
                    simulation.velocities
                    .* simulation.velocity_distribution[j, i, :],
                )
            )
            #! format: on
        end
    end
    return
end

function compute_momentum_densities!(
    simulation::SimulationD3,
    chunk_start::Int,
    chunk_end::Int,
)
    @inbounds for i ∈ chunk_start:chunk_end
        for j ∈ axes(simulation.velocity_distribution, 2)
            for k ∈ axes(simulation.velocity_distribution, 1)
                #! format: off
                @views simulation.momentum_densities[k, j, i, :] = (
                    sum(
                        simulation.velocities
                        .* simulation.velocity_distribution[k, j, i, :],
                    )
                )
                #! format: on
            end
        end
    end
    return
end

function compute_mass_densities!(simulation::SimulationD2, chunk_start::Int, chunk_end::Int)
    #tried
    # - @views
    @views simulation.mass_densities[:, chunk_start:chunk_end] .=
        dropdims(
            sum(simulation.velocity_distribution[:, chunk_start:chunk_end, :]; dims=3);
            dims=3,
        )
    return
end

function compute_mass_densities!(simulation::SimulationD3, chunk_start::Int, chunk_end::Int)
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
    simulation::SimulationD2,
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
            simulation.velocities[i][1] * u[:, :, 1]
            + simulation.velocities[i][2] * u[:, :, 2]
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
    simulation::SimulationD3,
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
            simulation.velocities[i][1] * u[:, :, :, 1]
            + simulation.velocities[i][2] * u[:, :, :, 2]
            + simulation.velocities[i][3] * u[:, :, :, 3]
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

@views function collide!(simulation::SimulationD2, chunk_start::Int, chunk_end::Int)
    #! format: off
    @. simulation.velocity_distribution[:, chunk_start:chunk_end, :] = (
        simulation.velocity_distribution[:, chunk_start:chunk_end, :]
        + (simulation.delta_t / simulation.parameters.characteristic_time)
        * (
            simulation.equilibrium_distribution[:, chunk_start:chunk_end, :]
            - simulation.velocity_distribution[:, chunk_start:chunk_end, :])
    )
    #! format: on

    return
end
@views function collide!(simulation::SimulationD3, chunk_start::Int, chunk_end::Int)
    #! format: off
    @. simulation.velocity_distribution[:, :, chunk_start:chunk_end, :] = (
        simulation.velocity_distribution[:, :, chunk_start:chunk_end, :]
        + (simulation.delta_t / simulation.parameters.characteristic_time)
        * (
            simulation.equilibrium_distribution[:, :, chunk_start:chunk_end, :]
            - simulation.velocity_distribution[:, :, chunk_start:chunk_end, :])
    )
    #! format: on

    return
end

function multithreaded_update!(simulation::SimulationD2)
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
        set_sources!(simulation)
        compute_equilibrium_distribution!(simulation, chunk_start, chunk_end)

        collide!(simulation, chunk_start, chunk_end)
    end

    set_no_bounce_boundaries!(simulation)

    simulation.velocity_distribution[simulation.object_mask, :] = velocities_in_objects
    simulation.momentum_densities[simulation.object_mask, :] .= 0

    stream!(simulation)

    return
end

function multithreaded_update!(simulation::SimulationD3)
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
        set_sources!(simulation)
        compute_equilibrium_distribution!(simulation, chunk_start, chunk_end)

        collide!(simulation, chunk_start, chunk_end)
    end
    set_no_bounce_boundaries!(simulation)

    simulation.velocity_distribution[simulation.object_mask, :] = velocities_in_objects
    simulation.momentum_densities[simulation.object_mask, :] .= 0

    stream!(simulation)

    return
end

function update!(
    simulation::Simulation,
)
    if Threads.nthreads() == 1
        step! = singlethreaded_update!
    else
        step! = multithreaded_update!
    end

    step!(simulation)
    return
end

function run!(
    simulation::Simulation;
    prog=nothing,
    save_every=100,
)
    prog = something(
        prog,
        Progress(simulation.parameters.time_steps),
    )
    simulations::Vector{Simulation} = []

    for (i, _) ∈ enumerate(1:simulation.parameters.time_steps)
        next!(prog)
        update!(simulation)
        if i % save_every == 0
            push!(simulations, deepcopy(simulation))
        end
    end
    return simulations
end
