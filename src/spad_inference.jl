#TODO: change inf_params.toml to accept 2 or 3 long tuple for tracks prior?
Base.@kwdef struct DataPaths
    frames_path::String
    camera_params_path::String
end

Base.@kwdef struct InferenceParams
    n_iters::Int
    size_limit::Int
    parametric::Bool
    max_n_tracks::Int
    batchsizes::Vector{Int} = [1]
end

Base.@kwdef struct PriorParams{T<:AbstractFloat}
    msd_prior::NTuple{2,T}
    diffusion_coeff_guess::T
    brightness_prior::NTuple{2,T}
    brightness_guess::T
    brightness_proposal::NTuple{2,T}
    track_prior_scale::T
    track_logonprob::T
    tracks_1bit_guess_path::String
end

Base.@kwdef struct SavingParams
    chain_output_dir::String
    save_name::String
    also_save::Vector{String} = String[]
    save_unique::Bool = true
end

Base.@kwdef struct CameraParams{T<:AbstractFloat}
    numerical_aperture::T
    refractive_index::T
    wavelength::T
    pixel_size::T
    period::T
    detector_size::Int
    darkcounts::Union{T,String}
end

Base.@kwdef struct SPADInferenceSpec{T<:AbstractFloat}
    float_type::Type{T}
    toml_path::String
    toml_dir::String
    config::Dict{String,Any} = Dict{String,Any}()
    data::DataPaths
    inference::InferenceParams
    priors::PriorParams{T}
    saving::SavingParams
end

const SUPPORTED_SPAD_FLOAT_TYPES = Dict(
    "Float32" => Float32,
    "Float64" => Float64,
)

resolve_path(path::AbstractString, base_dir::AbstractString) =
    isabspath(path) ? normpath(path) : normpath(joinpath(base_dir, path))

function get_unique_datadir(base_path::AbstractString, dir_name::AbstractString)
    target_path = joinpath(base_path, "$(today())_$(dir_name)")

    if !ispath(target_path)
        return target_path
    end

    id = 1
    while ispath("$(target_path)_$(id)")
        id += 1
    end

    return "$(target_path)_$(id)"
end

to_dict(x) = x
to_dict(x::NamedTuple) = Dict{String, Any}(string(k) => to_dict(v) for (k, v) in pairs(x))
to_dict(x::AbstractDict) = Dict{String, Any}(string(k) => to_dict(v) for (k, v) in pairs(x))
to_dict(x::AbstractVector) = [to_dict(v) for v in x]

function deep_merge(base::Dict{String,Any}, override::Dict{String,Any})
    merged = deepcopy(base)
    for (k, v) in override
        if haskey(merged, k) && merged[k] isa AbstractDict && v isa AbstractDict
            merged[k] = deep_merge(Dict{String,Any}(merged[k]), Dict{String,Any}(v))
        else
            merged[k] = v
        end
    end
    return merged
end

get_required(d::AbstractDict, key::AbstractString) =
    haskey(d, key) ? d[key] : error("Missing required key: $key")

function as_tuple2(::Type{T}, x, key::AbstractString) where {T<:AbstractFloat}
    length(x) == 2 || error("Expected `$key` to have exactly two values.")
    return (T(x[1]), T(x[2]))
end

function parse_float_type(cfg::AbstractDict)
    raw_value = string(get(cfg, "FloatType", "Float32"))
    haskey(SUPPORTED_SPAD_FLOAT_TYPES, raw_value) ||
        error("Unsupported FloatType `$raw_value`. Supported values: $(join(sort!(collect(keys(SUPPORTED_SPAD_FLOAT_TYPES))))), \", \")).")
    return SUPPORTED_SPAD_FLOAT_TYPES[raw_value]
end

float_type_name(::Type{T}) where {T<:AbstractFloat} = string(T)

join_config_key(prefix::AbstractString, key::AbstractString) =
    isempty(prefix) ? key : "$prefix.$key"

function toml_ready_value(value, key_path::AbstractString = "")
    if value isa Type && value <: AbstractFloat
        return float_type_name(value)
    elseif value isa AbstractFloat
        return value isa Float32 ? parse(Float64, string(value)) : value
    elseif value isa AbstractDict
        return Dict{String,Any}(
            string(k) => toml_ready_value(v, join_config_key(key_path, string(k)))
            for (k, v) in value
        )
    elseif value isa NamedTuple
        return Dict{String,Any}(
            string(k) => toml_ready_value(v, join_config_key(key_path, string(k)))
            for (k, v) in pairs(value)
        )
    elseif value isa Tuple || value isa AbstractVector
        return [toml_ready_value(v, key_path) for v in value]
    elseif value === nothing
        key_label = isempty(key_path) ? "a value" : "`$key_path`"
        error("Cannot save $key_label as `nothing` in TOML. Use `false` or omit the key instead.")
    else
        return value
    end
end

function set_config_value!(cfg::Dict{String,Any}, key_path::Tuple, value)
    isempty(key_path) && error("Cannot set a TOML value with an empty key path.")
    table = cfg

    for raw_key in key_path[1:end-1]
        key = String(raw_key)
        next_table = get!(table, key, Dict{String,Any}())
        if !(next_table isa AbstractDict)
            error("Cannot set `$(join(string.(key_path), "."))` because `$key` is not a TOML table.")
        end

        if !(next_table isa Dict{String,Any})
            next_table = Dict{String,Any}(string(k) => v for (k, v) in next_table)
            table[key] = next_table
        end

        table = next_table
    end

    table[String(last(key_path))] = value
    return cfg
end

set_config_value!(cfg::Dict{String,Any}, section::AbstractString, key::AbstractString, value) =
    set_config_value!(cfg, (section, key), value)

function parse_data_paths(cfg::AbstractDict, toml_dir::AbstractString)
    return DataPaths(
        frames_path = resolve_path(String(get_required(cfg, "frames_path")), toml_dir),
        camera_params_path = resolve_path(String(get_required(cfg, "camera_params_path")), toml_dir),
    )
end

function parse_inference_params(cfg::AbstractDict)
    batchsizes = Int.(collect(get(cfg, "batchsizes", [1])))
    return InferenceParams(
        n_iters = Int(get_required(cfg, "n_iters")),
        size_limit = Int(get_required(cfg, "size_limit")),
        parametric = Bool(get_required(cfg, "parametric")),
        max_n_tracks = Int(get_required(cfg, "max_n_tracks")),
        batchsizes = batchsizes,
    )
end

function parse_prior_params(::Type{T}, cfg::AbstractDict, toml_dir::AbstractString) where {T<:AbstractFloat}
    return PriorParams{T}(
        msd_prior = as_tuple2(T, get_required(cfg, "msd_prior"), "priors.msd_prior"),
        diffusion_coeff_guess = T(get_required(cfg, "diffusion_coeff_guess")),
        brightness_prior = as_tuple2(T, get_required(cfg, "brightness_prior"), "priors.brightness_prior"),
        brightness_guess = T(get_required(cfg, "brightness_guess")),
        brightness_proposal = as_tuple2(T, get_required(cfg, "brightness_proposal"), "priors.brightness_proposal"),
        track_prior_scale = T(get_required(cfg, "track_prior_scale")),
        track_logonprob = T(get_required(cfg, "track_logonprob")),
        tracks_1bit_guess_path = resolve_path(String(get_required(cfg, "tracks_1bit_guess_path")), toml_dir),
    )
end

function parse_saving_params(cfg::AbstractDict, toml_dir::AbstractString)
    return SavingParams(
        chain_output_dir = resolve_path(String(get_required(cfg, "chain_output_dir")), toml_dir),
        save_name = String(get_required(cfg, "save_name")),
        also_save = String.(collect(get(cfg, "also_save", String[]))),
        save_unique = Bool(get(cfg, "save_unique", true)),
    )
end

function parse_camera_params(::Type{T}, camera_cfg::AbstractDict) where {T<:AbstractFloat}
    darkcounts = get_required(camera_cfg, "darkcounts")
    darkcounts_value = darkcounts isa Number ? T(darkcounts) : String(darkcounts)

    return CameraParams{T}(
        numerical_aperture = T(get_required(camera_cfg, "numerical_aperture")),
        refractive_index = T(get_required(camera_cfg, "refractive_index")),
        wavelength = T(get_required(camera_cfg, "wavelength")),
        pixel_size = T(get_required(camera_cfg, "pixel_size")),
        period = T(get_required(camera_cfg, "period")),
        detector_size = Int(get_required(camera_cfg, "detector_size")),
        darkcounts = darkcounts_value,
    )
end

function load_spad_inference_spec(toml_path::AbstractString; overrides = NamedTuple())
    toml_path = abspath(toml_path)
    toml_dir = dirname(toml_path)

    raw_cfg = TOML.parsefile(toml_path)
    merged_cfg = deep_merge(Dict{String,Any}(raw_cfg), to_dict(overrides))

    float_type = parse_float_type(merged_cfg)

    return SPADInferenceSpec{float_type}(
        float_type = float_type,
        toml_path = toml_path,
        toml_dir = toml_dir,
        config = deepcopy(merged_cfg),
        data = parse_data_paths(merged_cfg, toml_dir),
        inference = parse_inference_params(get_required(merged_cfg, "inference")),
        priors = parse_prior_params(float_type, get_required(merged_cfg, "priors"), toml_dir),
        saving = parse_saving_params(get_required(merged_cfg, "saving"), toml_dir),
    )
end

function load_camera_params(camera_params_path::AbstractString, float_type::Type{T} = Float32) where {T<:AbstractFloat}
    camera_toml = TOML.parsefile(camera_params_path)
    camera_section = get_required(camera_toml, "camera")
    return parse_camera_params(float_type, camera_section)
end

load_camera_params(spec::SPADInferenceSpec) = load_camera_params(spec.data.camera_params_path, spec.float_type)

function validate_positive(value, label::AbstractString)
    value > 0 || error("`$label` must be positive, got $value.")
end

function validate_nonnegative(value, label::AbstractString)
    value >= 0 || error("`$label` must be nonnegative, got $value.")
end

function validate_finite(value, label::AbstractString)
    isfinite(value) || error("`$label` must be finite, got $value.")
end

function validate_file_exists(path::AbstractString, label::AbstractString)
    isfile(path) || error("Expected `$label` at `$path`, but the file does not exist.")
end

function validate_jld2_key(path::AbstractString, key::AbstractString)
    jldopen(path, "r") do file
        haskey(file, key) || error("Expected JLD2 file `$path` to contain key `$key`.")
    end
end

function load_required_jld2(path::AbstractString, key::AbstractString)
    validate_jld2_key(path, key)
    return load(path, key)
end

function validate_spad_inference_spec(spec::SPADInferenceSpec)
    spec.float_type <: AbstractFloat || error("`FloatType` must be an AbstractFloat subtype.")

    validate_file_exists(spec.toml_path, "toml_path")
    validate_file_exists(spec.data.frames_path, "frames_path")
    validate_file_exists(spec.data.camera_params_path, "camera_params_path")
    validate_file_exists(spec.priors.tracks_1bit_guess_path, "tracks_1bit_guess_path")

    validate_positive(spec.inference.n_iters, "inference.n_iters")
    validate_positive(spec.inference.size_limit, "inference.size_limit")
    validate_positive(spec.inference.max_n_tracks, "inference.max_n_tracks")
    isempty(spec.inference.batchsizes) && error("`inference.batchsizes` must contain at least one batchsize.")
    all(>(0), spec.inference.batchsizes) || error("All `inference.batchsizes` values must be positive.")

    validate_nonnegative(spec.priors.diffusion_coeff_guess, "priors.diffusion_coeff_guess")
    validate_positive(spec.priors.brightness_guess, "priors.brightness_guess")
    validate_positive(spec.priors.track_prior_scale, "priors.track_prior_scale")
    validate_finite(spec.priors.track_logonprob, "priors.track_logonprob")
    validate_positive(spec.priors.msd_prior[1], "priors.msd_prior[1]")
    validate_positive(spec.priors.msd_prior[2], "priors.msd_prior[2]")
    validate_positive(spec.priors.brightness_prior[1], "priors.brightness_prior[1]")
    validate_positive(spec.priors.brightness_prior[2], "priors.brightness_prior[2]")
    validate_positive(spec.priors.brightness_proposal[1], "priors.brightness_proposal[1]")
    validate_positive(spec.priors.brightness_proposal[2], "priors.brightness_proposal[2]")

    validate_jld2_key(spec.data.frames_path, "frames")
    validate_jld2_key(spec.priors.tracks_1bit_guess_path, "tracks")

    return spec
end

function validate_camera_params(camera::CameraParams, camera_params_path::AbstractString = "")
    validate_positive(camera.numerical_aperture, "camera.numerical_aperture")
    validate_positive(camera.refractive_index, "camera.refractive_index")
    validate_positive(camera.wavelength, "camera.wavelength")
    validate_positive(camera.pixel_size, "camera.pixel_size")
    validate_positive(camera.period, "camera.period")
    validate_positive(camera.detector_size, "camera.detector_size")

    if camera.darkcounts isa Number
        validate_nonnegative(camera.darkcounts, "camera.darkcounts")
    else
        camera_path = isempty(camera_params_path) ? camera.darkcounts : resolve_path(camera.darkcounts, dirname(camera_params_path))
        validate_file_exists(camera_path, "camera.darkcounts")
        validate_jld2_key(camera_path, "darkcounts")
    end

    return camera
end

function validate_loaded_inputs(frames_1bit, tracks_1bit, darkcounts, camera::CameraParams)
    ndims(frames_1bit) == 3 || error("`frames` must be a 3D array with dimensions (x, y, time).")
    size(frames_1bit, 1) == camera.detector_size ||
        error("`frames` first dimension ($(size(frames_1bit, 1))) must match `camera.detector_size` ($(camera.detector_size)).")
    size(frames_1bit, 2) == camera.detector_size ||
        error("`frames` second dimension ($(size(frames_1bit, 2))) must match `camera.detector_size` ($(camera.detector_size)).")
    size(frames_1bit, 3) > 0 || error("`frames` must contain at least one frame.")

    ndims(tracks_1bit) == 3 || error("`tracks` must be a 3D array with dimensions (time, xy, particle).")
    size(tracks_1bit, 1) == size(frames_1bit, 3) ||
        error("`tracks` time dimension ($(size(tracks_1bit, 1))) must match the frame count ($(size(frames_1bit, 3))).")
    size(tracks_1bit, 2) == 2 || size(tracks_1bit, 2) == 3 ||
        error("`tracks` second dimension must be 2 or 3 for x/y coordinates, got $(size(tracks_1bit, 2)).")
    size(tracks_1bit, 3) > 0 || error("`tracks` must contain at least one particle.")

    size(darkcounts) == (camera.detector_size, camera.detector_size) ||
        error("`darkcounts` size $(size(darkcounts)) must match (`camera.detector_size`, `camera.detector_size`) = ($(camera.detector_size), $(camera.detector_size)).")

    return nothing
end

function load_darkcounts(::Type{T}, camera::CameraParams, camera_toml_dir::AbstractString) where {T<:AbstractFloat}
    if camera.darkcounts isa Number
        fill_val = camera.darkcounts * camera.period * camera.pixel_size^2
        return fill(T(fill_val), camera.detector_size, camera.detector_size)
    end

    darkcounts_path = resolve_path(camera.darkcounts, camera_toml_dir)
    return T.(load_required_jld2(darkcounts_path, "darkcounts"))
end

function prepare_spad_inference_run(toml_path::AbstractString = "inf_params.toml"; overrides = NamedTuple())
    spec = validate_spad_inference_spec(load_spad_inference_spec(toml_path; overrides = overrides))
    camera = validate_camera_params(load_camera_params(spec), spec.data.camera_params_path)
    camera_toml_dir = dirname(spec.data.camera_params_path)

    frames_1bit = load_required_jld2(spec.data.frames_path, "frames")
    tracks_1bit = load_required_jld2(spec.priors.tracks_1bit_guess_path, "tracks")
    size(tracks_1bit, 1) == size(frames_1bit, 3) || error("Incompatible dimensions between `frames_1bit` ($(size(frames_1bit))) and `tracks_1bit` ($(size(tracks_1bit))).")
    darkcounts = load_darkcounts(spec.float_type, camera, camera_toml_dir)

    validate_loaded_inputs(frames_1bit, tracks_1bit, darkcounts, camera)

    return (
        spec = spec,
        camera = camera,
        frames_1bit = frames_1bit,
        tracks_1bit = tracks_1bit,
        darkcounts = darkcounts,
    )
end

function build_psf(::Type{T}, camera::CameraParams, tracks_guess) where {T<:AbstractFloat}
    ndims_tracks = size(tracks_guess, 2)
    if ndims_tracks == 2
        return CircularGaussian{T}(
            numerical_aperture = T(camera.numerical_aperture),
            refractive_index = T(camera.refractive_index),
            emission_wavelength = T(camera.wavelength),
            pixel_size = T(camera.pixel_size),
        )
    elseif ndims_tracks == 3
        return CircularGaussianLorentzian{T}(
            numerical_aperture = T(camera.numerical_aperture),
            refractive_index = T(camera.refractive_index),
            emission_wavelength = T(camera.wavelength),
            pixel_size = T(camera.pixel_size),
        )
    end

    error("`tracks` second dimension must be 2 or 3, got $(ndims_tracks).")
end

function build_detector(::Type{T}, camera::CameraParams, darkcounts, frames, batchsize::Int) where {T<:AbstractFloat}
    return SPAD{T}(
        period = T(camera.period),
        pixel_size = T(camera.pixel_size),
        darkcounts = CuArray(darkcounts),
        cutoffs = (T(0), T(Inf)),
        readouts = frames,
        batchsize = batchsize,
    )
end

function build_msd(::Type{T}, camera::CameraParams, priors::PriorParams, batchsize::Int) where {T<:AbstractFloat}
    return MeanSquaredDisplacement{T}(
        guess = T(2 * priors.diffusion_coeff_guess * camera.period * batchsize),
        priorparams = map(T, priors.msd_prior),
    )
end

function build_brightness(::Type{T}, camera::CameraParams, priors::PriorParams, psf) where {T<:AbstractFloat}
    # `addincident!` divides by psf.A, so this mirrors the simulation brightness scaling.
    return Brightness{T}(
        guess = T(priors.brightness_guess * camera.period * psf.A),
        priorparams = map(T, priors.brightness_prior),
        proposalparams = map(T, priors.brightness_proposal),
    )
end

function build_tracks(::Type{T}, camera::CameraParams, priors::PriorParams, detector, msd, tracks_guess, batchsize::Int, inference::InferenceParams) where {T<:AbstractFloat}
    binned_tracks = T.(bintracks(tracks_guess, batchsize)) #guess for this batchsize
    ndims_tracks = size(binned_tracks, 2)
    prior_center = if ndims_tracks == 2
        T.(collect(detector.framecenter))
    elseif ndims_tracks == 3
        T[T.(collect(detector.framecenter))..., zero(T)]
    else
        error("`tracks` second dimension must be 2 or 3, got $(ndims_tracks).")
    end
    prior_scale = fill(T(camera.pixel_size * priors.track_prior_scale), ndims_tracks)

    return Tracks{T}(
        guess = CuArray(binned_tracks),
        prior = DNormal{T}(
            CuArray(prior_center),
            CuArray(prior_scale),
        ),
        max_ntracks = inference.max_n_tracks,
        scaling = sqrt(msd.value),
        logonprob = T(priors.track_logonprob),
    )
end

function get_save_dir(spec::SPADInferenceSpec)
    dir_name = "spad_inf_$(spec.saving.save_name)"
    return spec.saving.save_unique ? get_unique_datadir(spec.saving.chain_output_dir, dir_name) : joinpath(spec.saving.chain_output_dir, dir_name)
end

function camera_parameters_config_dict(spec::SPADInferenceSpec)
    camera_toml = TOML.parsefile(spec.data.camera_params_path)
    camera_cfg = deepcopy(get_required(camera_toml, "camera"))

    if haskey(camera_cfg, "darkcounts") && !(camera_cfg["darkcounts"] isa Number)
        camera_cfg["darkcounts"] = resolve_path(String(camera_cfg["darkcounts"]), dirname(spec.data.camera_params_path))
    end

    return camera_cfg
end

function inference_extra_artifact_paths(spec::SPADInferenceSpec)
    frames_dir = dirname(spec.data.frames_path)
    return [resolve_path(extra_file, frames_dir) for extra_file in spec.saving.also_save]
end

function inference_parameter_path_updates(spec::SPADInferenceSpec)
    path_updates = Dict{Tuple,Any}()
    path_updates[("frames_path",)] = spec.data.frames_path
    path_updates[("camera_params_path",)] = spec.data.camera_params_path
    path_updates[("saving", "chain_output_dir")] = spec.saving.chain_output_dir

    priors_cfg = get(spec.config, "priors", Dict{String,Any}())
    if priors_cfg isa AbstractDict
        path_updates[("priors", "tracks_1bit_guess_path")] = spec.priors.tracks_1bit_guess_path
    end

    saving_cfg = get(spec.config, "saving", Dict{String,Any}())
    if saving_cfg isa AbstractDict && haskey(saving_cfg, "also_save")
        path_updates[("saving", "also_save")] = inference_extra_artifact_paths(spec)
    end

    return path_updates
end

function inference_parameters_config_dict(
    spec::SPADInferenceSpec,
    path_updates::AbstractDict = inference_parameter_path_updates(spec),
)
    cfg = deepcopy(spec.config)
    set_config_value!(cfg, ("camera",), camera_parameters_config_dict(spec))

    for (key_path, value) in path_updates
        set_config_value!(cfg, key_path, value)
    end

    return toml_ready_value(cfg)
end

function save_all_inference_parameters(save_dir::AbstractString, spec::SPADInferenceSpec)
    path = joinpath(save_dir, "all_inference_parameters.toml")
    open(path, "w") do io
        TOML.print(io, inference_parameters_config_dict(spec))
    end
    return path
end

function copy_inference_extra_artifacts(save_dir::AbstractString, spec::SPADInferenceSpec)
    for extra_path in inference_extra_artifact_paths(spec)
        cp(extra_path, joinpath(save_dir, basename(extra_path)), force = !spec.saving.save_unique)
    end
end

function infer_spad_batch(
    spec::SPADInferenceSpec,
    camera::CameraParams,
    frames_1bit,
    tracks_1bit,
    darkcounts,
    batchsize::Int;
    save_dir::AbstractString,
)
    @info "Running inference" batchsize = batchsize float_type = float_type_name(spec.float_type)

    float_type = spec.float_type
    frames = CuArray(binframes(frames_1bit, batchsize))
    detector = build_detector(float_type, camera, darkcounts, frames, batchsize)
    msd = build_msd(float_type, camera, spec.priors, batchsize)
    psf = build_psf(float_type, camera, tracks_1bit)
    brightness = build_brightness(float_type, camera, spec.priors, psf)
    tracks = build_tracks(float_type, camera, spec.priors, detector, msd, tracks_1bit, batchsize, spec.inference)

    chain = runMCMC(
        tracks = tracks,
        msd = msd,
        brightness = brightness,
        detector = detector,
        psf = psf,
        niters = spec.inference.n_iters,
        sizelimit = spec.inference.size_limit,
        parametric = spec.inference.parametric,
    )

    chain_path = joinpath(save_dir, "chain_$(batchsize).jld2")
    jldsave(chain_path; chain = chain, tracks = tracks, msd = msd, brightness = brightness, detector = detector, psf = psf)

    return (
        batchsize = batchsize,
        chain = chain,
        chain_path = chain_path,
        tracks = tracks,
        msd = msd,
        brightness = brightness,
        detector = detector,
        psf = psf,
    )
end

function execute_spad_inference(toml_path::AbstractString = "inf_params.toml"; overrides = NamedTuple())
    prepared = prepare_spad_inference_run(toml_path; overrides = overrides)
    spec = prepared.spec
    camera = prepared.camera

    @info "Loaded validated input data" frames_path = spec.data.frames_path n_input_frames = size(prepared.frames_1bit, 3) float_type = float_type_name(spec.float_type)

    save_dir = get_save_dir(spec)
    println("Saving in $save_dir")
    mkpath(save_dir)

    all_parameters_path = save_all_inference_parameters(save_dir, spec)
    copy_inference_extra_artifacts(save_dir, spec)

    results = Vector{Any}(undef, length(spec.inference.batchsizes))
    for (i, batchsize) in enumerate(spec.inference.batchsizes)
        results[i] = infer_spad_batch(
            spec,
            camera,
            prepared.frames_1bit,
            prepared.tracks_1bit,
            prepared.darkcounts,
            batchsize;
            save_dir = save_dir,
        )
    end

    return (
        save_dir = save_dir,
        spec = spec,
        camera = camera,
        results = results,
        all_inference_parameters_path = all_parameters_path,
        effective_config_path = all_parameters_path,
    )
end
