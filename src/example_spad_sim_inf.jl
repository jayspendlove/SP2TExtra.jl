using SP2TExtra

const DEFAULT_TOML_PATH = joinpath(@__DIR__, "dev_inference", "inf_params_exp.toml")
const DEFAULT_SIMULATION_TOML_PATH = joinpath(@__DIR__, "dev_inference", "sim_params.toml")

const SMOKE_TEST_OVERRIDES = (
    inference = (
        n_iters = 50_000,
        batchsizes = [1, 5, 10],
    ),
    saving = (
        save_name = "exp_data_smoke_test",
        save_unique = true,
    ),
)

const SIMULATION_SMOKE_TEST_OVERRIDES = (
    simulation = (
        n_frames = 10,
        brightness_per_sec = 10_000.0,
        random_seed = 26,
    ),
    saving = (
        save_name = "sim_data_smoke_test",
        save_unique = true,
    ),
)

function run_from_toml(toml_path::AbstractString = DEFAULT_TOML_PATH)
    result = execute_spad_inference(toml_path)
    println("Saved results in: ", result.save_dir)
    return result
end

function run_with_overrides(
    toml_path::AbstractString = DEFAULT_TOML_PATH;
    overrides = SMOKE_TEST_OVERRIDES,
)
    result = execute_spad_inference(toml_path; overrides = overrides)
    println("Saved overridden results in: ", result.save_dir)
    return result
end

function run_simulation_from_toml(toml_path::AbstractString = DEFAULT_SIMULATION_TOML_PATH)
    result = execute_spad_simulation(toml_path)
    println("Saved simulation results in: ", result.save_dir)
    return result
end

function run_simulation_with_overrides(
    toml_path::AbstractString = DEFAULT_SIMULATION_TOML_PATH;
    overrides = SIMULATION_SMOKE_TEST_OVERRIDES,
)
    result = execute_spad_simulation(toml_path; overrides = overrides)
    println("Saved overridden simulation results in: ", result.save_dir)
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_from_toml()
end
