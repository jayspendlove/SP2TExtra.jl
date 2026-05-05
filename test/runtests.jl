using SP2TExtra
using Test
using JLD2
using TOML

# @testset "XML tests" begin
#     gttracks = [0.15367499430949305 0.22010250918040386 0.0;
#         0.3161351020914415 0.27006612153286086 0.0;
#         0.2711288587786091 0.27340129071031466 0.0;
#         0.2703490014548096 0.2945822935280891 0.0;
#         0.30439380732843224 0.3992083130600652 0.0;
#         0.30925668022438907 0.4331489344514949 0.0;
#         0.23547467805007016 0.45027805553041783 0.0;
#         0.2625778731233346 0.5101664492168924 0.0;
#         0.18825167441294663 0.4513309081261772 0.0;
#         0.2716093990068874 0.529427986757348 0.0;
#         0.3154063193003772 0.614647224629777 0.0;
#         0.33022318733972866 0.4094173064084635 0.0;
#         0.30588299411579484 0.4438255315805149 0.0;
#         0.26892598888856545 0.4464031867929209 0.0;
#         0.35138360313662426 0.4423236660738443 0.0;
#         0.3863323462070774 0.34835328919284425 0.0;
#         0.407679507824874 0.3068153660528501 0.0;
#         0.37691638407786715 0.2587751980232748 0.0;
#         0.3079657004069656 0.23887797333907246 0.0;
#         0.44513955403705946 0.29784996879972314 0.0;
#         0.354213834410956 0.24915317053513877 0.0;
#         0.38883342690732947 0.25525323046170495 0.0;
#         0.3835967456696548 0.29643673264425047 0.0;
#         0.4606706600583911 0.3146070755425922 0.0;
#         0.4992902758199351 0.5318347298915443 0.0;
#         0.5718895296147325 0.3986045417262149 0.0;
#         0.6457022521443803 0.4281646139001585 0.0;
#         0.685187887834596 0.28938489274827994 0.0;
#         0.7060370721393979 0.17069668011566905 0.0;
#         0.669630541491682 0.21899871222352615 0.0;
#         0.7032447453147959 0.27189352036659087 0.0;
#         0.7360280328825375 0.2501445757922171 0.0;
#         0.7251632119133569 0.23299726272920693 0.0;
#         0.7047287916318168 0.2099248946689253 0.0]
#     @test isapprox(xml2tracks("./testtracks.xml", nframes=34, batchsize=1), gttracks)
# end

@testset "SPAD inference config tests" begin
    mktempdir() do tmpdir
        frames_path = joinpath(tmpdir, "frames.jld2")
        tracks_path = joinpath(tmpdir, "tracks.jld2")
        darkcounts_path = joinpath(tmpdir, "darkcounts.jld2")
        camera_path = joinpath(tmpdir, "camera.toml")
        inference_path = joinpath(tmpdir, "inference.toml")

        jldsave(frames_path; frames = ones(UInt8, 4, 4, 3))
        jldsave(tracks_path; tracks = zeros(Float64, 3, 2, 1))
        jldsave(darkcounts_path; darkcounts = fill(0.25, 4, 4))

        write(camera_path, """
[camera]
numerical_aperture = 1.49
refractive_index = 1.52
wavelength = 0.571
pixel_size = 0.1
period = 5e-5
darkcounts = "darkcounts.jld2"
detector_size = 4
""")

        write(inference_path, """
FloatType = "Float64"
frames_path = "frames.jld2"
camera_params_path = "camera.toml"

[inference]
n_iters = 10
size_limit = 5
parametric = true
max_n_tracks = 1
batchsizes = [1, 3]

[priors]
msd_prior = [2.0, 1e-5]
diffusion_coeff_guess = 0.1
brightness_prior = [1.0, 1.0]
brightness_guess = 1000.0
brightness_proposal = [10.0, 1.0]
track_prior_scale = 10.0
track_perturbation_size = 0.1
track_logonprob = -10.0
tracks_1bit_guess_path = "tracks.jld2"

[saving]
chain_output_dir = "results"
save_name = "tmp"
also_save = []
save_unique = true
""")

        spec = load_spad_inference_spec(inference_path)
        prepared = prepare_spad_inference_run(inference_path)
        all_parameters_path = save_all_inference_parameters(tmpdir, spec)

        @test spec.float_type === Float64
        @test prepared.spec.float_type === Float64
        @test eltype(prepared.darkcounts) === Float64
        @test size(prepared.frames_1bit) == (4, 4, 3)
        @test size(prepared.tracks_1bit) == (3, 2, 1)
        @test basename(all_parameters_path) == "all_inference_parameters.toml"

        saved_cfg = TOML.parsefile(all_parameters_path)
        saved_text = read(all_parameters_path, String)
        @test saved_cfg["frames_path"] == frames_path
        @test saved_cfg["camera_params_path"] == camera_path
        @test saved_cfg["priors"]["tracks_1bit_guess_path"] == tracks_path
        @test saved_cfg["saving"]["chain_output_dir"] == joinpath(tmpdir, "results")
        @test saved_cfg["camera"]["darkcounts"] == darkcounts_path
        @test saved_cfg["camera"]["pixel_size"] == 0.1
        @test occursin("pixel_size = 0.1", saved_text)
        @test !occursin("0.10000000149011612", saved_text)

        continued_spec = load_spad_inference_spec(all_parameters_path)
        continued_path = SP2TExtra.save_continued_inference_parameters(tmpdir, continued_spec, 7, false)
        continued_cfg = TOML.parsefile(continued_path)
        @test continued_path == all_parameters_path
        @test continued_cfg["inference"]["n_iters"] == 17
        @test continued_cfg["inference"]["parametric"] == false
        @test continued_cfg["frames_path"] == frames_path
        @test continued_cfg["camera"]["darkcounts"] == darkcounts_path
    end
end

@testset "SPAD simulation config tests" begin
    mktempdir() do tmpdir
        darkcounts_path = joinpath(tmpdir, "darkcounts.jld2")
        tracks_path = joinpath(tmpdir, "input_tracks.jld2")
        simulation_path = joinpath(tmpdir, "sim.toml")

        tracks = Float32[
            0.10 0.15
            0.11 0.15
            0.12 0.16
            0.12 0.16
        ]
        tracks = reshape(tracks, 4, 2, 1)

        jldsave(darkcounts_path; darkcounts = fill(0.05f0, 4, 4))
        jldsave(tracks_path; tracks = tracks)

        write(simulation_path, """
FloatType = "Float32"

[camera]
numerical_aperture = 1.45
refractive_index = 1.515
wavelength = 0.665
pixel_size = 0.133
period = 1e-5
darkcounts = "darkcounts.jld2"
detector_size = 4

[simulation]
n_frames = 4
dimensions = 2
diffusion_coefficient = 0.1
n_particles = 1
brightness_per_sec = 1000.0
n_realizations = 2
shift = false
init_width = 0
random_seed = false
throw_out_of_bounds = true
tracks_path = "input_tracks.jld2"

[saving]
save_location = "outputs"
save_unique = false
save_name = "tiny"

[custom]
label = "original"
""")

        overrides = (custom = (label = "overridden", added = 4),)
        spec = load_spad_simulation_spec(simulation_path; overrides = overrides)
        prepared = prepare_spad_simulation_run(simulation_path; overrides = overrides)
        result = execute_spad_simulation(simulation_path; overrides = overrides)

        @test spec.float_type === Float32
        @test prepared.spec.float_type === Float32
        @test eltype(prepared.darkcounts) === Float32
        @test eltype(prepared.tracks) === Float32
        @test size(prepared.tracks) == (4, 2, 1)
        @test result.spec.simulation.n_realizations == 2
        @test isfile(result.frames_path)
        @test isfile(joinpath(result.save_dir, "frames_2.jld2"))
        @test result.frames_path == joinpath(result.save_dir, "frames_1.jld2")
        @test result.frames_paths == [joinpath(result.save_dir, "frames_1.jld2"), joinpath(result.save_dir, "frames_2.jld2")]
        @test isfile(result.tracks_path)
        @test isfile(result.all_simulation_parameters_path)
        @test result.camera_params_path == result.all_simulation_parameters_path
        @test basename(result.all_simulation_parameters_path) == "all_simulation_parameters.toml"
        @test !isfile(joinpath(result.save_dir, "camera_params.toml"))
        @test !isfile(joinpath(result.save_dir, "effective_spad_simulation.toml"))
        @test !isfile(joinpath(result.save_dir, basename(simulation_path)))
        @test !isfile(joinpath(result.save_dir, basename(tracks_path)))
        @test isfile(joinpath(result.save_dir, "darkcounts.jld2"))

        saved_cfg = TOML.parsefile(result.all_simulation_parameters_path)
        @test saved_cfg["camera"]["darkcounts"] == darkcounts_path
        @test saved_cfg["simulation"]["tracks_path"] == tracks_path
        @test saved_cfg["saving"]["save_location"] == joinpath(tmpdir, "outputs")
        @test saved_cfg["custom"]["label"] == "overridden"
        @test saved_cfg["custom"]["added"] == 4
        @test !haskey(saved_cfg, "generated_outputs")
    end
end

# @testset "MSD tests" begin
#     x = randn(10, 5, 3)
#     @test isapprox(msd(x), sum(diff(x, dims=1) .^ 2) / (3 * (10 - 1)))
# end
