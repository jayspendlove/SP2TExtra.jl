module SP2TExtra

using SP2T, Combinatorics, StatsBase, TiffImages, MAT, ImageCore, Statistics
using JLD2, CUDA, TOML, Dates
using Random, Logging
using XMLDict

export binframes, bintracks, coarse_grained_track_guess
export readbin, getframes, extractROI, readtiff, writetiff, ImageJTIff
export getdarkcounts, calculate_optimal_iterations, final_chain_length
export credible1D, credible2D, msd, msds, tracks, localization_error, plot_tracks_on_frames
export xml2tracks
# All functions for inference and simulation framework
export DataPaths, InferenceParams, PriorParams, SavingParams, CameraParams, SPADInferenceSpec
export load_spad_inference_spec, load_camera_params, validate_spad_inference_spec, validate_camera_params
export prepare_spad_inference_run, load_darkcounts, infer_spad_batch, execute_spad_inference, continue_spad_inference
export get_save_dir, save_all_inference_parameters, inference_parameters_config_dict, copy_inference_extra_artifacts
export float_type_name
export SimulationParams, SimulationSavingParams, SPADSimulationSpec
export load_spad_simulation_spec, validate_spad_simulation_spec, prepare_spad_simulation_run
export load_simulation_darkcounts, get_simulation_save_dir, save_all_simulation_parameters
export simulation_parameters_config_dict, copy_simulation_input_artifacts, execute_spad_simulation
export save_simulation_outputs, load_required_jld2, validate_loaded_inputs, get_unique_datadir
export PolyDecayAnnealing

include("annealing_schedules.jl")
include("histcounts.jl")
include("binframes.jl")
include("import.jl")
include("preprocess.jl")
include("postprocess.jl")
include("trackmate.jl")
include("tiff.jl")
include("spad_inference.jl")
include("spad_simulation.jl")

end
