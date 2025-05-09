
include("simulation.jl")

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

function add_cylinder!(
    simulation::Simulation;
    position,
    radius,
)
    for index ∈ CartesianIndices(simulation.object_mask)
        r = Tuple(index) .- position
        r_norm = norm(r[1:2])
        if r_norm < radius
            simulation.object_mask[index] = true
        end
    end
end

function add_rectangle!(
    simultion::Simulation;
    position,
    lengths,
)
    for index ∈ CartesianIndices(simulation.object_mask)
        r = Tuple(index) .- position
        if all(abs.(r) .< lengths)
            simulation.object_mask[index] = true
        end
    end
end
