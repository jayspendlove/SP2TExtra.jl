function getdarkcounts(darkframes::AbstractArray{<:Integer,3})
    width, height, nframes = size(darkframes)
    darkcounts = Array{Float64}(undef, width, height)
    sum!(darkcounts, darkframes)
    @. darkcounts .= -log1p(-darkcounts / nframes)
    return darkcounts
end