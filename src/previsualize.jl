theme_dataviewer = Theme(
    Axis=(
        aspect=DataAspect(),
        bottomspinevisible=false,
        leftspinevisible=false,
        rightspinevisible=false,
        topspinevisible=false,
        xgridvisible=false,
        xticklabelsvisible=false,
        xticksvisible=false,
        ygridvisible=false,
        yticklabelsvisible=false,
        yticksvisible=false,
    ),
    Poly=(strokecolormap=:tab10, strokecolor=1, strokewidth=2),
    Heatmap=(; colormap=:bone),
)

function validaterange(s::String)
    parsed_vec = tryparse.(Int64, split(s, ','))
    return eltype(parsed_vec) == Int64 && length(parsed_vec) == 2
end

getrect(w_sl, h_sl) = @lift Rect(
    $(w_sl.interval)[1] - 0.5,
    $(h_sl.interval)[1] - 0.5,
    $(w_sl.interval)[2] - $(w_sl.interval)[1] + 1,
    $(h_sl.interval)[2] - $(h_sl.interval)[1] + 1,
)

getvertices(rect) = (@lift $(rect).origin), (@lift $(rect).origin .+ $(rect).widths)

function viewframes(
    frames::AbstractArray{<:Integer,3};
    batchsize::Union{Integer,Nothing}=nothing,
    tracks::Union{Nothing,AbstractArray}=nothing,
    pxsize::Real=1,
)
    width, height, nframes = size(frames)
    isnothing(batchsize) && (batchsize = maximum(frames))
    isnothing(tracks) && (tracks = fill(NaN, (size(frames, 3), 3, 1)))

    set_theme!(theme_dataviewer)
    fig = Figure(; size=(1000, 300))
    axes = [Axis(fig[1, 1]), Axis(fig[1, 3][1, 1]), Axis(fig[1, 3][2, 1])]

    h_sl = IntervalSlider(
        fig[1, 2],
        range=1:height,
        startvalues=(1, height),
        horizontal=false,
    )
    w_sl = IntervalSlider(fig[2, 1], range=1:width, startvalues=(1, width))
    tb = Textbox(
        fig[2, 3][1, 2],
        halign=:right,
        placeholder="start frame, end frame",
        validator=validaterange,
        width=150,
    )
    slgrid = SliderGrid(
        fig[3, :][1, 1],
        (
            label="Frame",
            range=1:nframes,
            startvalue=1,
            snap=false,
            format=x -> "$x/$nframes",
        ),
        (
            label="Contrast",
            range=1:batchsize,
            startvalue=batchsize,
            snap=false,
            format=x -> "$x/$batchsize",
        ),
    )
    button = Button(fig[3, :][1, 2], label="print")

    lowerindex = Observable(1)
    upperindex = Observable(nframes)

    on(tb.stored_string) do str
        interval = sort!(parse.(Int64, split(str, ',')))
        lowerindex[] = 1 <= interval[1] <= nframes ? interval[1] : lowerindex[]
        upperindex[] = 1 <= interval[2] <= nframes ? interval[2] : upperindex[]
    end

    sl_tags = (@lift "($($(w_sl.interval)[1]), $($(h_sl.interval)[1]))"),
    (@lift "($($(w_sl.interval)[2]-$(w_sl.interval)[1]+1), $($(h_sl.interval)[2]-$(h_sl.interval)[1]+1))")
    rangetag =
        @lift "Frame range: $(min($lowerindex,$upperindex))-$(max($lowerindex,$upperindex))"

    colorrange = @lift (0, $(slgrid.sliders[2].value))

    frameobs = []
    push!(frameobs, @lift view(frames, :, :, $(slgrid.sliders[1].value)))
    push!(frameobs, @lift view(frames, :, :, $lowerindex))
    push!(frameobs, @lift view(frames, :, :, $upperindex))

    tracks2 = tracks ./ pxsize
    trajs2D = []
    for x in eachslice(view(tracks2, :, 1:2, :), dims=3)
        push!(trajs2D, Point2f[eachslice(x, dims=1)...])
    end
    trajs2Dobs = []
    foreach(x -> push!(trajs2Dobs, @lift view(x, 1:$(slgrid.sliders[1].value))), trajs2D)

    on(button.clicks) do n
        println(
            "Bits summed:\t$batchsize\nROI:\t$(sl_tags[1][])--$(sl_tags[2][])\nFrame range:\t$(lowerindex[])--$(upperindex[])",
        )
    end

    for (i, frame) in enumerate(frameobs)
        heatmap!(axes[i], 1:width, 1:height, frame, colorrange=colorrange)
    end
    limits!.(axes, 0.5, width + 0.5, 0.5, height + 0.5)

    foreach(x -> lines!(axes[1], x), trajs2Dobs)

    rect = getrect(w_sl, h_sl)
    for ax in axes
        poly!(ax, rect, color=:blue)
    end

    verts = getvertices(rect)
    text!(axes[1], verts[1], align=(:left, :bottom), text=sl_tags[1], color=:white)
    text!(axes[1], verts[2], align=(:right, :top), text=sl_tags[2], color=:white)

    Label(fig[0, 1:2], "Frame viewer")
    Label(fig[0, 3], "Range viewer")
    Label(fig[2, 3][1, 1], rangetag, halign=:left)

    colsize!(fig.layout, 1, Relative(2 / 3))
    colsize!(fig.layout, 3, Relative(1 / 3))
    rowsize!(fig.layout, 1, Aspect(1, height / width))
    resize_to_layout!(fig)
    display(fig)
    set_theme!()
end