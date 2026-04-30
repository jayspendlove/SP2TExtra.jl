Base.@kwdef struct SimulationParams{T<:AbstractFloat}
    n_frames::Int
    dimensions::Int
    diffusion_coefficient::T
    n_particles::Int
    brightness_per_sec::T
    n_realizations::Int = 1
    shift::Union{Bool,Vector{T}} = false
    init_width::T = T(10)
    init_bounds_pixels::Union{Nothing,NTuple{4,T}} = nothing
    random_seed::Union{Nothing,Int} = nothing
    throw_out_of_bounds::Bool = true
    tracks_path::Union{Nothing,String} = nothing
end

Base.@kwdef struct SimulationSavingParams
    save_location::String
    save_name::String
    save_unique::Bool = true
end

Base.@kwdef struct SPADSimulationSpec{T<:AbstractFloat}
    float_type::Type{T}
    toml_path::String
    toml_dir::String
    config::Dict{String,Any} = Dict{String,Any}()
    camera::CameraParams{T}
    simulation::SimulationParams{T}
    saving::SimulationSavingParams
end

function as_tuple4(::Type{T}, x, key::AbstractString) where {T<:AbstractFloat}
    length(x) == 4 || error("Expected `$key` to have exactly four values.")
    return (T(x[1]), T(x[2]), T(x[3]), T(x[4]))
end

function parse_optional_seed(x)
    x === false && return nothing
    x === nothing && return nothing
    return Int(x)
end

function parse_shift(::Type{T}, x) where {T<:AbstractFloat}
    x isa Bool && return x
    x isa AbstractVector || error("`simulation.shift` must be either a Bool or a length-2 vector in detector pixels.")
    length(x) == 2 || error("`simulation.shift` vector must have length 2.")
    return T.(collect(x))
end

function parse_simulation_params(::Type{T}, cfg::AbstractDict, toml_dir::AbstractString) where {T<:AbstractFloat}
    init_bounds_pixels = get(cfg, "init_bounds_pixels", nothing)
    tracks_path = get(cfg, "tracks_path", nothing)
    tracks_path = tracks_path === false ? nothing : tracks_path

    return SimulationParams{T}(
        n_frames = Int(get_required(cfg, "n_frames")),
        dimensions = Int(get(cfg, "dimensions", 2)),
        diffusion_coefficient = T(get_required(cfg, "diffusion_coefficient")),
        n_particles = Int(get_required(cfg, "n_particles")),
        brightness_per_sec = T(get_required(cfg, "brightness_per_sec")),
        n_realizations = Int(get(cfg, "n_realizations", 1)),
        shift = parse_shift(T, get(cfg, "shift", false)),
        init_width = T(get(cfg, "init_width", 10)),
        init_bounds_pixels = isnothing(init_bounds_pixels) ? nothing : as_tuple4(T, init_bounds_pixels, "simulation.init_bounds_pixels"),
        random_seed = parse_optional_seed(get(cfg, "random_seed", nothing)),
        throw_out_of_bounds = Bool(get(cfg, "throw_out_of_bounds", true)),
        tracks_path = isnothing(tracks_path) ? nothing : resolve_path(String(tracks_path), toml_dir),
    )
end

function parse_simulation_saving_params(cfg::AbstractDict, toml_dir::AbstractString)
    return SimulationSavingParams(
        save_location = resolve_path(String(get_required(cfg, "save_location")), toml_dir),
        save_name = String(get_required(cfg, "save_name")),
        save_unique = Bool(get(cfg, "save_unique", true)),
    )
end

function load_spad_simulation_spec(toml_path::AbstractString; overrides = NamedTuple())
    toml_path = abspath(toml_path)
    toml_dir = dirname(toml_path)

    raw_cfg = TOML.parsefile(toml_path)
    merged_cfg = deep_merge(Dict{String,Any}(raw_cfg), to_dict(overrides))
    float_type = parse_float_type(merged_cfg)

    return SPADSimulationSpec{float_type}(
        float_type = float_type,
        toml_path = toml_path,
        toml_dir = toml_dir,
        config = deepcopy(merged_cfg),
        camera = parse_camera_params(float_type, get_required(merged_cfg, "camera")),
        simulation = parse_simulation_params(float_type, get_required(merged_cfg, "simulation"), toml_dir),
        saving = parse_simulation_saving_params(get_required(merged_cfg, "saving"), toml_dir),
    )
end

function validate_spad_simulation_spec(spec::SPADSimulationSpec)
    spec.float_type <: AbstractFloat || error("`FloatType` must be an AbstractFloat subtype.")

    validate_file_exists(spec.toml_path, "toml_path")
    validate_camera_params(spec.camera, spec.toml_path)

    validate_positive(spec.simulation.n_frames, "simulation.n_frames")
    # spec.simulation.dimensions == 2 || error("`simulation.dimensions` must be 2 for the current SPAD simulation workflow.")
    validate_nonnegative(spec.simulation.diffusion_coefficient, "simulation.diffusion_coefficient")
    validate_positive(spec.simulation.brightness_per_sec, "simulation.brightness_per_sec")
    validate_positive(spec.simulation.n_realizations, "simulation.n_realizations")
    validate_positive(spec.simulation.n_particles, "simulation.n_particles")
    spec.simulation.init_width >= zero(spec.float_type) || error("`simulation.init_width` must be nonnegative.")

    if !isnothing(spec.simulation.init_bounds_pixels)
        xmin, xmax, ymin, ymax = spec.simulation.init_bounds_pixels
        xmax >= xmin || error("`simulation.init_bounds_pixels` requires xmax >= xmin.")
        ymax >= ymin || error("`simulation.init_bounds_pixels` requires ymax >= ymin.")
    end

    if spec.simulation.shift isa AbstractVector
        length(spec.simulation.shift) == 2 || error("`simulation.shift` vector must have length 2.")
    end

    if !isnothing(spec.simulation.tracks_path)
        validate_file_exists(spec.simulation.tracks_path, "simulation.tracks_path")
        validate_jld2_key(spec.simulation.tracks_path, "tracks")
    end

    return spec
end

function load_simulation_darkcounts(::Type{T}, camera::CameraParams{T}, toml_dir::AbstractString) where {T<:AbstractFloat}
    if camera.darkcounts isa Number
        fill_val = camera.darkcounts * camera.period * camera.pixel_size^2
        return fill(T(fill_val), camera.detector_size, camera.detector_size)
    end

    darkcounts_path = resolve_path(camera.darkcounts, toml_dir)
    return T.(load_required_jld2(darkcounts_path, "darkcounts"))
end

function validate_simulation_darkcounts(darkcounts, camera::CameraParams)
    size(darkcounts) == (camera.detector_size, camera.detector_size) ||
        error("`darkcounts` size $(size(darkcounts)) must match detector size ($(camera.detector_size), $(camera.detector_size)).")
    return darkcounts
end

function build_simulation_psf(::Type{T}, camera::CameraParams{T}) where {T<:AbstractFloat}
    return CircularGaussian{T}(
        numerical_aperture = camera.numerical_aperture,
        refractive_index = camera.refractive_index,
        emission_wavelength = camera.wavelength,
        pixel_size = camera.pixel_size,
    )
end

function build_simulation_detector(::Type{T}, camera::CameraParams{T}, darkcounts, simulation::SimulationParams{T}) where {T<:AbstractFloat}
    readouts = zeros(UInt16, size(darkcounts)..., simulation.n_frames)
    cutoffs = (T(0), T(Inf))

    return SPAD{T}(
        period = camera.period,
        pixel_size = camera.pixel_size,
        darkcounts = copy(darkcounts),
        cutoffs = cutoffs,
        readouts = readouts,
    )
end

function initialize_tracks(::Type{T}, simulation::SimulationParams{T}, camera::CameraParams{T}, rng::AbstractRNG) where {T<:AbstractFloat}
    tracks = Array{T}(undef, simulation.n_frames, simulation.dimensions, simulation.n_particles)

    if !isnothing(simulation.init_bounds_pixels)
        xmin, xmax, ymin, ymax = simulation.init_bounds_pixels
        bounds = ((xmin, xmax), (ymin, ymax))
        for i in 1:simulation.n_particles
            for d in 1:simulation.dimensions
                lo, hi = bounds[d]
                tracks[1, d, i] = (lo + rand(rng, T) * (hi - lo)) * camera.pixel_size
            end
        end
    else
        @views rand!(rng, tracks[1, :, :]) .*= simulation.init_width * camera.pixel_size
        offset = (camera.detector_size - simulation.init_width) * camera.pixel_size / T(2)
        tracks[1, :, :] .+= offset
    end

    return tracks
end

function initialize_tracks(::Type{T}, simulation::SimulationParams{T}, camera::CameraParams{T}) where {T<:AbstractFloat}
    initialize_tracks(T, simulation, camera, Random.default_rng())
end

function simulate_tracks!(rng::AbstractRNG, tracks::Array{T,3}, nominal_msd::T) where {T<:AbstractFloat}
    @views Random.randn!(rng, tracks[2:end, :, :])
    @views tracks[2:end, :, :] .*= √nominal_msd
    cumsum!(tracks, tracks, dims = 1)
    return tracks
end

function simulate_tracks(::Type{T}, simulation::SimulationParams{T}, camera::CameraParams{T}, rng::AbstractRNG) where {T<:AbstractFloat}
    tracks = initialize_tracks(T, simulation, camera, rng)
    nominal_msd = T(2) * simulation.diffusion_coefficient * camera.period
    simulate_tracks!(rng, tracks, nominal_msd)
    return tracks, nominal_msd
end

function simulate_tracks(::Type{T}, simulation::SimulationParams{T}, camera::CameraParams{T}) where {T<:AbstractFloat}
    simulate_tracks(T, simulation, camera, Random.default_rng())
end

function load_input_tracks(::Type{T}, simulation::SimulationParams{T}) where {T<:AbstractFloat}
    tracks = T.(load_required_jld2(simulation.tracks_path, "tracks"))
    return tracks
end

function shift_tracks_into_fov!(tracks, simulation::SimulationParams{T}, camera::CameraParams{T}) where {T<:AbstractFloat}
    buffer = T(2) * camera.pixel_size
    for i in 1:size(tracks, 3)
        shifted = false
        for d in 1:size(tracks, 2)
            minval = minimum(tracks[:, d, i])
            maxval = maximum(tracks[:, d, i])
            upper_bound = camera.detector_size * camera.pixel_size

            if minval < zero(T)
                tracks[:, d, i] .+= (-minval + buffer)
                shifted = true
            elseif maxval > upper_bound
                tracks[:, d, i] .-= (maxval - upper_bound + buffer)
                shifted = true
            end
        end
        shifted && println("Shifted particle $i")
    end
    return tracks
end

function apply_explicit_shift!(tracks, shift::AbstractVector{T}, camera::CameraParams{T}) where {T<:AbstractFloat}
    tracks .+= reshape(shift .* camera.pixel_size, 1, :, 1)
    return tracks
end

function validate_tracks_for_simulation(tracks, simulation::SimulationParams{T}, camera::CameraParams{T}) where {T<:AbstractFloat}
    ndims(tracks) == 3 || error("`tracks` must be a 3D array with dimensions (time, xy, particle).")
    size(tracks, 1) == simulation.n_frames ||
        error("Track frame count $(size(tracks, 1)) must match `simulation.n_frames` $(simulation.n_frames).")
    size(tracks, 2) == simulation.dimensions ||
        error("Track spatial dimension $(size(tracks, 2)) must match `simulation.dimensions` $(simulation.dimensions).")
    size(tracks, 3) == simulation.n_particles ||
        error("Track particle count $(size(tracks, 3)) must match `simulation.n_particles` $(simulation.n_particles).")

    upper_bound = camera.detector_size * camera.pixel_size
    for i in 1:size(tracks, 3), d in 1:size(tracks, 2)
        minval = minimum(tracks[:, d, i])
        maxval = maximum(tracks[:, d, i])
        if minval < zero(T) || maxval > upper_bound
            if simulation.throw_out_of_bounds
                error("Track $i is out of bounds in dimension $d. Check simulation settings or input tracks.")
            else
                println("WARNING: Track $i is out of bounds in dimension $d.")
            end
        end
    end

    return tracks
end

function prepare_simulation_tracks(::Type{T}, spec::SPADSimulationSpec{T}, rng::AbstractRNG) where {T<:AbstractFloat}
    tracks, nominal_msd = if isnothing(spec.simulation.tracks_path)
        simulate_tracks(T, spec.simulation, spec.camera, rng)
    else
        (load_input_tracks(T, spec.simulation), T(2) * spec.simulation.diffusion_coefficient * spec.camera.period)
    end

    if spec.simulation.shift === true
        shift_tracks_into_fov!(tracks, spec.simulation, spec.camera)
    elseif spec.simulation.shift isa AbstractVector
        apply_explicit_shift!(tracks, spec.simulation.shift, spec.camera)
    end

    validate_tracks_for_simulation(tracks, spec.simulation, spec.camera)
    return tracks, nominal_msd
end

function prepare_spad_simulation_run(toml_path::AbstractString = "sim_params.toml"; overrides = NamedTuple())
    spec = validate_spad_simulation_spec(load_spad_simulation_spec(toml_path; overrides = overrides))

    rng = isnothing(spec.simulation.random_seed) ? Random.default_rng() : MersenneTwister(spec.simulation.random_seed)

    darkcounts = validate_simulation_darkcounts(
        load_simulation_darkcounts(spec.float_type, spec.camera, spec.toml_dir),
        spec.camera,
    )
    detector = build_simulation_detector(spec.float_type, spec.camera, darkcounts, spec.simulation)
    psf = build_simulation_psf(spec.float_type, spec.camera)
    tracks, nominal_msd = prepare_simulation_tracks(spec.float_type, spec, rng)
    brightness = spec.simulation.brightness_per_sec * spec.camera.period * psf.A

    return (
        spec = spec,
        darkcounts = darkcounts,
        detector = detector,
        psf = psf,
        tracks = tracks,
        nominal_msd = nominal_msd,
        brightness = brightness,
    )
end

function get_simulation_save_dir(spec::SPADSimulationSpec)
    dir_name = "sim_$(spec.saving.save_name)"
    return spec.saving.save_unique ? get_unique_datadir(spec.saving.save_location, dir_name) : joinpath(spec.saving.save_location, dir_name)
end

function simulation_frame_filename(i::Int, n_realizations::Int)
    return n_realizations == 1 ? "frames.jld2" : "frames_$(i).jld2"
end

function simulation_frame_paths(save_dir::AbstractString, n_realizations::Int)
    return [joinpath(save_dir, simulation_frame_filename(i, n_realizations)) for i in 1:n_realizations]
end

function simulation_parameters_config_dict(
    spec::SPADSimulationSpec,
    path_updates::AbstractDict{<:Tuple{AbstractString,AbstractString},Any} = Dict{Tuple{String,String},Any}(),
)
    cfg = deepcopy(spec.config)
    for ((section, key), value) in path_updates
        set_config_value!(cfg, section, key, value)
    end
    return toml_ready_value(cfg)
end

function save_all_simulation_parameters(
    save_dir::AbstractString,
    spec::SPADSimulationSpec,
    path_updates::AbstractDict{<:Tuple{AbstractString,AbstractString},Any} = Dict{Tuple{String,String},Any}(),
)
    path = joinpath(save_dir, "all_simulation_parameters.toml")
    open(path, "w") do io
        TOML.print(io, simulation_parameters_config_dict(spec, path_updates))
    end
    return path
end

function save_simulation_outputs(save_dir::AbstractString, prepared, means)
    tracks_path = joinpath(save_dir, "groundtruth.jld2")
    frame_paths = simulation_frame_paths(save_dir, prepared.spec.simulation.n_realizations)

    if !isnothing(prepared.spec.simulation.random_seed)
        Random.seed!(prepared.spec.simulation.random_seed)
    end

    for i in 1:prepared.spec.simulation.n_realizations
        detector = i == 1 ? prepared.detector : build_simulation_detector(prepared.spec.float_type, prepared.spec.camera, prepared.darkcounts, prepared.spec.simulation)
        SP2T.simulate_readouts!(detector, means)
        jldsave(frame_paths[i]; frames = detector.readouts)
    end

    jldsave(
        tracks_path;
        tracks = prepared.tracks,
        msd = prepared.nominal_msd,
        brightness = prepared.brightness,
        float_type = float_type_name(prepared.spec.float_type),
    )

    return (tracks_path = tracks_path, frames_path = frame_paths[1], frames_paths = frame_paths)
end

function copy_if_needed(source_path::AbstractString, target_path::AbstractString; force::Bool = false)
    if normpath(abspath(source_path)) != normpath(abspath(target_path))
        cp(source_path, target_path, force = force)
    end
    return target_path
end

function copy_simulation_input_artifacts(save_dir::AbstractString, spec::SPADSimulationSpec)
    path_updates = Dict{Tuple{String,String},Any}()
    path_updates[("saving", "save_location")] = spec.saving.save_location

    if spec.camera.darkcounts isa AbstractString
        source_path = resolve_path(spec.camera.darkcounts, spec.toml_dir)
        target_name = basename(source_path)
        copy_if_needed(source_path, joinpath(save_dir, target_name), force = !spec.saving.save_unique)
        path_updates[("camera", "darkcounts")] = abspath(source_path)
    end

    if !isnothing(spec.simulation.tracks_path)
        path_updates[("simulation", "tracks_path")] = abspath(spec.simulation.tracks_path)
    end

    return path_updates
end

function execute_spad_simulation(toml_path::AbstractString = "sim_params.toml"; overrides = NamedTuple())
    prepared = prepare_spad_simulation_run(toml_path; overrides = overrides)
    spec = prepared.spec

    save_dir = get_simulation_save_dir(spec)
    println("Saving in $save_dir")
    mkpath(save_dir)

    means = SP2T.getincident(prepared.tracks, prepared.brightness, prepared.detector.darkcounts, prepared.detector.pxbounds, prepared.psf)
    output_paths = save_simulation_outputs(save_dir, prepared, means)
    path_updates = copy_simulation_input_artifacts(save_dir, spec)
    all_parameters_path = save_all_simulation_parameters(save_dir, spec, path_updates)

    return (
        save_dir = save_dir,
        spec = spec,
        detector = prepared.detector,
        psf = prepared.psf,
        tracks = prepared.tracks,
        nominal_msd = prepared.nominal_msd,
        brightness = prepared.brightness,
        frames_path = output_paths.frames_path,
        frames_paths = output_paths.frames_paths,
        tracks_path = output_paths.tracks_path,
        all_simulation_parameters_path = all_parameters_path,
        camera_params_path = all_parameters_path,
    )
end
