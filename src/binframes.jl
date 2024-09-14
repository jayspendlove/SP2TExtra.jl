function binframes!(binned::AbstractArray{<:Integer,3}, frames1bit::AbstractArray{<:Integer,3}, batchsize::Integer)
    @views for i in axes(binned, 3)
        sum!(
            binned[:, :, i],
            frames1bit[:, :, (i-1)*batchsize+1:i*batchsize],
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
    binframes!(binned, frames1bit, batchsize)
    return binned
end