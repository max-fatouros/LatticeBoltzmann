using ProgressMeter
using Images
using TiffImages

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

function read_point_cloud(filename)
    point_cloud = []
    a = open(filename) do f
        for line ∈ readlines(f)
            words = split(line)
            xyz = [
                parse(Float64, word)
                for word ∈ words
            ]
            push!(point_cloud, xyz)
        end
    end
    return transpose(hcat(point_cloud...))
end

function rotation_matrix(angle)
    # https://en.wikipedia.org/wiki/Rotation_matrix#General_3D_rotations
    #!format: off
    return [
        cos(angle) -sin(angle)
        sin(angle) cos(angle)
    ]
    #!format: on

    return x_matrix * y_matrix * z_matrix
end

function rotation_matrix(x_angle, y_angle, z_angle)
    # https://en.wikipedia.org/wiki/Rotation_matrix#General_3D_rotations
    #!format: off
    x_matrix = [
        1 0            0
        0 cos(x_angle) -sin(x_angle)
        0 sin(x_angle) cos(x_angle)
    ]

    y_matrix = [
        cos(y_angle)  0 sin(y_angle)
        0             1 0
        -sin(y_angle) 0 cos(y_angle)

    ]
    z_matrix = [
        cos(z_angle) -sin(z_angle) 0
        sin(z_angle) cos(z_angle)  0
        0            0             1
    ]
    #!format: on

    return x_matrix * y_matrix * z_matrix
end

function add_point_cloud(
    simulation,
    filename;
    position=nothing,
    rotation=nothing,
    side_length=10,
)
    point_cloud = nothing
    if occursin(".xyz", filename)
        point_cloud = read_point_cloud(filename)
    elseif occursin(".tiff", filename)
        point_cloud = tiff_to_point_cloud(filename)
    end

    # normalize
    max_point_cloud = maximum(point_cloud; dims=1)
    min_point_cloud = minimum(point_cloud; dims=1)
    max_point_cloud_length = maximum(abs.(max_point_cloud - min_point_cloud))
    point_cloud = (side_length / max_point_cloud_length) * point_cloud

    if !isnothing(rotation)
        # rotate
        point_cloud *= rotation_matrix(rotation...)
    end

    if !isnothing(position)
        # shift
        point_cloud_means = mean(point_cloud; dims=1)
        point_cloud .-= point_cloud_means
        point_cloud .+= collect(position)'
    end

    # discretize
    discretized_point_cloud = round.(Int, point_cloud)
    discretized_point_cloud = unique(discretized_point_cloud; dims=1)

    for i ∈ axes(discretized_point_cloud, 1)
        cartesian_index = CartesianIndex(
            Tuple(
                discretized_point_cloud[i, :],
            ),
        )
        simulation.object_mask[cartesian_index] = true
    end

    return
end

function tiff_to_point_cloud(filename)
    img = TiffImages.load(filename)

    img_gray = Gray.(img)

    # img_bool = round.(Bool, img_gray)
    img_gray[img_gray.<0.9] .= 0
    img_gray[img_gray.>=0.9] .= 1
    img_bool = Bool.(img_gray)
    img_bool = .!img_bool

    points = []
    for index ∈ CartesianIndices(img_bool)
        if img_bool[index]
            push!(points, collect(Tuple(index)))
        end
    end

    points = transpose(hcat(points...))
    points = points / maximum(points)
    return points
end

function add_source!(
    simulation::Simulation,
    ranges,
    dimension,
    speed,
)
    dimensions = length(ranges)
    source = Source{dimensions}(
        ranges,
        dimension,
        speed,
    )
    return push!(simulation.sources, source)
end
