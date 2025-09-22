function getdarkcounts(darkframes::AbstractArray{<:Integer,3}; batchsize::Integer=1)
    darkcounts = Array{Float64}(undef, size(darkframes, 1), size(darkframes, 2))
    sum!(darkcounts, darkframes)
    N = size(darkframes, 3) * batchsize
    @. darkcounts .= -log1p(-darkcounts / N)
    return darkcounts
end

# function getframes() end