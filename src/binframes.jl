function sumbin!(binned::AbstractArray{T,3}, tobin::AbstractArray{T,3}, batchsize::Integer) where {T<:Real}
    @views for i in axes(binned, 3)
        sum!(
            binned[:, :, i],
            tobin[:, :, (i-1)*batchsize+1:i*batchsize],
        )
    end
    return binned
end

function binframes(frames1bit::AbstractArray{<:Integer,3}, batchsize::Integer)
    binned = similar(
        frames1bit,
        size(frames1bit, 1),
        size(frames1bit, 2),
        size(frames1bit, 3) ÷ batchsize,
    )
    sumbin!(binned, frames1bit, batchsize)
    return binned
end

function meanbin!(binned::AbstractArray{T,3}, tobin::AbstractArray{T,3}, batchsize::Integer) where {T<:AbstractFloat}
    @views for i in axes(binned, 3)
        mean!(
            binned[:, :, i],
            tobin[:, :, (i-1)*batchsize+1:i*batchsize],
            weights(ones(T, size(tobin, 1))),
            dims=1,
        )
    end
    return binned
end

function bintracks(tracks1bit::AbstractArray{<:Integer,3}, batchsize::Integer)
    binned = similar(
        tracks1bit,
        size(tracks1bit, 1),
        size(tracks1bit, 2),
        size(tracks1bit, 3) ÷ batchsize,
    )
    meanbin!(binned, tracks1bit, batchsize)
    return binned
end