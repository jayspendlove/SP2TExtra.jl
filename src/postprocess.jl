function credible1D(S::AbstractVector{<:Sample}, i::Integer, xedges::AbstractRange, yedges::AbstractRange; factor::Real=1, xshift::Real=0, yshift::Real=0)
    N = size(S[1].tracks, 1)
    xcounts = zeros(Float64, N, length(xedges) - 1)
    ycounts = zeros(Float64, N, length(yedges) - 1)
    ntracks = length(S)
    for s in S
        @views for (n, x) in enumerate(eachslice(s.tracks, dims=1))
            histcounts!(xcounts[n, :], (x[1, i:i] .+ xshift) .* factor, xedges)
            histcounts!(ycounts[n, :], (x[2, i:i] .+ yshift) .* factor, yedges)
        end
    end
    xcounts ./= ntracks
    ycounts ./= ntracks
    xcounts, ycounts
end

function credible1D(S::AbstractVector{<:Sample}, xedges::AbstractRange, yedges::AbstractRange; factor::Real=1, xshift::Real=0, yshift::Real=0)
    N = size(S[1].tracks, 1)
    xcounts = zeros(Float64, N, length(xedges) - 1)
    ycounts = zeros(Float64, N, length(yedges) - 1)
    ntracks = 0
    for s in S
        ntracks += size(s.tracks, 3)
        @views for (n, x) in enumerate(eachslice(s.tracks, dims=1))
            histcounts!(xcounts[n, :], (x[1, :] .+ xshift) .* factor, xedges)
            histcounts!(ycounts[n, :], (x[2, :] .+ yshift) .* factor, yedges)
        end
    end
    xcounts ./= ntracks
    ycounts ./= ntracks
    xcounts, ycounts
end

function credible2D(S::AbstractVector{<:Sample}, i::Integer, xedges::AbstractRange, yedges::AbstractRange; factor::Real=1, xshift::Real=0, yshift::Real=0)
    N = size(S[1].tracks, 1)
    counts = zeros(Float64, length(xedges) - 1, length(yedges) - 1, N)
    ntracks = length(S)
    @views for s in S
        for (n, x) in enumerate(eachslice(s.tracks, dims=1))
            histcounts!(counts[:, :, n], (x[2, i:i] .+ yshift) .* factor, (x[1, i:i] .+ xshift) .* factor, yedges, xedges)
        end
    end
    counts ./= ntracks
end

function credible2D(S::AbstractVector{<:Sample}, xedges::AbstractRange, yedges::AbstractRange; factor::Real=1, xshift::Real=0, yshift::Real=0)
    N = size(S[1].tracks, 1)
    counts = zeros(Float64, length(xedges) - 1, length(yedges) - 1, N)
    ntracks = 0
    @views for s in S
        ntracks += size(s.tracks, 3)
        for (n, x) in enumerate(eachslice(s.tracks, dims=1))
            histcounts!(counts[:, :, n], (x[2, :] .+ yshift) .* factor, (x[1, :] .+ xshift) .* factor, yedges, xedges)
        end
    end
    counts ./= ntracks
end

function _msds!(msds::AbstractVector{T}, tracks::AbstractArray{T,3}) where {T<:Real}
    copyto!(msds, sum(diff(tracks, dims=1) .^ 2, dims=(1, 2)) ./ (size(tracks, 1) - 1))
    return msds
end
function _msds(tracks::AbstractArray{T,3}) where {T<:Real}
    msds = similar(tracks, size(tracks, 3))
    _msds!(msds, tracks)
    return msds
end
function msds(tracks::AbstractArray{T,3}, delay::Integer) where {T<:Real}
    if delay == 1
        return _msds(tracks)
    else
        m = fill!(similar(tracks, size(tracks, 3)), 0)
        for start in 1:size(tracks, 1)-delay
            t = @view tracks[start:delay:end, :, :]
            m .+= _msds(t)
        end
        return m ./ (size(tracks, 1) - delay)
    end
end
function msds(tracks::AbstractArray{T,3}) where {T<:Real}
    m = similar(tracks, size(tracks, 1) - 1, size(tracks, 3))
    for delay in 1:size(tracks, 1)-1
        m[delay, :] = msds(tracks, delay)
    end
    return m
end
msds(chain::Chain; burn_in::Integer=0) = msds(tracks(chain; burn_in=burn_in))

msd(tracks::AbstractArray{<:Real,3}) = mean(msds(tracks, 1))
msd(chain::Chain; burn_in::Integer=0) = mean(msds(chain; burn_in=burn_in))

function tracks(chain::Chain{T}; burn_in::Integer=0) where {T<:Real}
    N = sum(chain.emittercounts[burn_in+1:end])
    t = chain.samples[1].tracks
    x = Array{T}(undef, size(t, 1), size(t, 2), N)
    i = 1
    for s in chain.samples[burn_in+1:end]
        n = size(s.tracks, 3)
        copyto!(view(x, :, :, i:i+n-1), s.tracks)
        i += n
    end
    return x
end

#! Only works when one particle is present
function localization_error(chain::Chain{T}; burn_in::Integer=0) where {T<:Real}
    x = tracks(chain; burn_in=burn_in)
    mean(sqrt.(sum(var(x, dims=3), dims=2))) / 2
end