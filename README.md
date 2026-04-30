# SP2TExtra

This package contains visualization and importing helpers for SP2T, plus TOML-driven infrastructure for running and saving SPAD simulation and inference results.

## SPAD TOML Workflows

`spad_simulation.jl` and `spad_inference.jl` are configured with TOML files. Paths in those TOML files may be absolute or relative to the TOML file location.

Both workflows accept a top-level `FloatType`:

- `FloatType`: optional string, either `"Float32"` or `"Float64"`. Defaults to `"Float32"` if omitted.

Runtime values are converted to this type for simulation/inference, but saved parameter TOMLs preserve readable raw TOML values where possible.

## Camera Parameters

Camera parameters live in a `[camera]` table. For simulation, this table is part of the simulation TOML. For inference, `camera_params_path` should point to a TOML file that contains this table. A simulation `all_simulation_parameters.toml` is valid as a camera-parameter file because it contains `[camera]`.

Required fields:

- `numerical_aperture`: positive float.
- `refractive_index`: positive float.
- `wavelength`: positive float, emission wavelength in micrometers.
- `pixel_size`: positive float, detector pixel size in micrometers.
- `period`: positive float, frame period in seconds.
- `detector_size`: positive integer, assumes a square detector grid.
- `darkcounts`: either a nonnegative scalar or a string path to a `.jld2` file containing key `"darkcounts"`.

When `darkcounts` is a scalar, it is interpreted as expected photons per second per square micrometer, then scaled internally by `period * pixel_size^2`. Set it to `0` for no background noise.

## Simulation TOML

A simulation TOML is used by `execute_spad_simulation`.

Top-level fields:

- `FloatType`: optional, `"Float32"` or `"Float64"`.

Required tables:

- `[camera]`
- `[simulation]`
- `[saving]`

### `[simulation]`

Required fields:

- `n_frames`: positive integer, number of frames.
- `diffusion_coefficient`: nonnegative float in micrometers squared per second. Ignored for track generation if `tracks_path` is set, but still used for saved metadata such as nominal MSD.
- `n_particles`: positive integer.
- `brightness_per_sec`: positive float, photons per second.

Optional fields:

- `dimensions`: integer, defaults to `2`.
- `n_realizations`: positive integer, defaults to `1`. Saves one frame file per realization.
- `shift`: defaults to `false`. Use `true` to auto-shift tracks into the field of view, `false` to leave them unchanged, or `[dx, dy]` to apply an explicit detector-pixel shift.
- `init_width`: nonnegative float, defaults to `10`. Initial track positions are sampled from a square of this width in detector pixels. Use `0` to initialize at the center.
- `init_bounds_pixels`: optional four-value array `[xmin, xmax, ymin, ymax]` in detector pixels. If present, it replaces `init_width` for initial positions.
- `random_seed`: optional integer. Use `false` or omit it to avoid setting a simulation RNG seed.
- `throw_out_of_bounds`: boolean, defaults to `true`. If `true`, out-of-bounds tracks error; if `false`, they warn.
- `tracks_path`: optional string path to a `.jld2` file containing key `"tracks"`. Use `false` or omit it to simulate new tracks.

### `[saving]`

Required fields:

- `save_location`: output parent directory.
- `save_name`: name fragment for the output directory.

Optional fields:

- `save_unique`: boolean, defaults to `true`.

If `save_unique = true`, outputs go to:

```text
<save_location>/<date>_sim_<save_name>
```

If that directory exists, `_1`, `_2`, etc. are appended. If `save_unique = false`, outputs go to:

```text
<save_location>/sim_<save_name>
```

### Simulation Outputs

`execute_spad_simulation` saves:

- `all_simulation_parameters.toml`: merged original parameters plus overrides, with source paths expanded where appropriate.
- `frames.jld2`: simulated frames when `n_realizations = 1`, containing key `"frames"`.
- `frames_<i>.jld2`: simulated frames for realization `i` when `n_realizations > 1`, each containing key `"frames"`.
- `groundtruth.jld2`: generated or loaded tracks plus metadata, containing key `"tracks"`.

If `camera.darkcounts` is a file path, that darkcounts file is also copied into the output directory. Input `tracks_path` files are not copied; `all_simulation_parameters.toml` records their absolute source path.

## Inference TOML

An inference TOML is used by `execute_spad_inference`.

Top-level fields:

- `FloatType`: optional, `"Float32"` or `"Float64"`.
- `frames_path`: required path to a `.jld2` file containing key `"frames"`.
- `camera_params_path`: required path to a TOML file containing `[camera]`.

Required tables:

- `[inference]`
- `[priors]`
- `[saving]`

### `[inference]`

Required fields:

- `n_iters`: positive integer, number of MCMC iterations.
- `size_limit`: positive integer, maximum chain storage size.
- `parametric`: boolean. If `true`, the number of tracks remains fixed from the initial guess.
- `max_n_tracks`: positive integer. Used when `parametric = false`; otherwise effectively unused.

Optional fields:

- `batchsizes`: array of positive integers, defaults to `[1]`. Each batch size bins the input frames/tracks before inference.

### `[priors]`

Required fields:

- `msd_prior`: two-value array `[shape, rate]` for the gamma prior.
- `diffusion_coeff_guess`: nonnegative float in micrometers squared per second.
- `brightness_prior`: two-value array `[shape, rate]` for the gamma prior.
- `brightness_guess`: positive float, photons per second. Typically matches `simulation.brightness_per_sec`.
- `brightness_proposal`: two-value positive array for the brightness proposal.
- `track_prior_scale`: positive float. The track position prior scale is `camera.pixel_size * track_prior_scale`.
- `track_logonprob`: finite float.
- `tracks_1bit_guess_path`: path to a `.jld2` file containing key `"tracks"` for the initial track guess.

### `[saving]`

Required fields:

- `chain_output_dir`: output parent directory.
- `save_name`: name fragment for the output directory.

Optional fields:

- `also_save`: array of additional filenames to copy from the frames directory into the inference output directory. Defaults to `[]`. This is useful for copying the corresponding `all_simulation_parameters.toml`.
- `save_unique`: boolean, defaults to `true`.

If `save_unique = true`, outputs go to:

```text
<chain_output_dir>/<date>_spad_inf_<save_name>
```

If that directory exists, `_1`, `_2`, etc. are appended. If `save_unique = false`, outputs go to:

```text
<chain_output_dir>/spad_inf_<save_name>
```

### Inference Outputs

`execute_spad_inference` saves:

- `all_inference_parameters.toml`: merged original parameters plus overrides, with input paths expanded to absolute paths and the camera table included.
- `chain_<batchsize>.jld2`: one chain file for each configured batch size.
- Any files listed in `saving.also_save`, copied from the frames directory.

The original inference TOML, camera TOML, and initial track guess file are not copied automatically; their absolute source paths are recorded in `all_inference_parameters.toml`.

