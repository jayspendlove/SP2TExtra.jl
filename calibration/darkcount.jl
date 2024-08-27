# using SP2T
using SP2TVis
using JLD2
using GLMakie
using ColorSchemes

function get_darkcounts(darkframes::AbstractArray{<:Integer,3})
    darkcounts = Array{Float64}(undef, size(darkframes, 1), size(darkframes, 2))
    sum!(darkcounts, darkframes)
    N = size(darkframes, 3)
    @. darkcounts .= -log1p(-darkcounts / N)
    return darkcounts
end

indices = readbin(
    "/home/lancexwq/Dropbox (ASU)/SinglePhotonTracking/Data/Weiqing-Nathan/programmed trajectories/07_12_2023_rw2d_sz_200nm_dt_10ms/",
);

xsize = 45
ysize = 45

DCindices = extractROI(indices, (512, 512), (198, 337, 201 * 255 + 1), (xsize, ysize, 20 * 255));

DCframes = getframes(DCindices, width=xsize, height=ysize, batchsize=1);

darkcounts = get_darkcounts(DCframes)

idx = darkcounts .== 0
@views darkcounts[idx] .+= eps()

fig = Figure()
ax = Axis(fig[1, 1], aspect=DataAspect())
heatmap!(ax, darkcounts .> 0, colormap=:bone)
fig

jldsave("../SP2T/data/programmed/ROI1/darkcounts.jld2"; darkcounts)
