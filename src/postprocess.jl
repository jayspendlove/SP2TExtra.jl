function ntracks(chain::Chain; burn_in::Real=0)
    n = 0
    for i = burn_in+1:length(chain.samples)
        n += size(chain.samples[i].tracks, 3)
    end
    n
end

function credible1D(S::AbstractVector{<:Sample}, i::Integer, xrange::AbstractRange, yrange::AbstractRange; factor::Real=1, xshift::Real=0, yshift::Real=0)
    N = size(S[1].tracks, 1)
    xcounts = zeros(Float64, N, length(xrange) - 1)
    ycounts = zeros(Float64, N, length(yrange) - 1)
    ntracks = length(S)
    for s in S
        @views for (n, x) in enumerate(eachslice(s.tracks, dims=1))
            histcounts!(xcounts[n, :], (x[1, i:i] .+ xshift) .* factor, xrange)
            histcounts!(ycounts[n, :], (x[2, i:i] .+ yshift) .* factor, yrange)
        end
    end
    xcounts ./= ntracks
    ycounts ./= ntracks
    xcounts, ycounts
end

function credible1D(S::AbstractVector{<:Sample}, xrange::AbstractRange, yrange::AbstractRange; factor::Real=1, xshift::Real=0, yshift::Real=0)
    N = size(S[1].tracks, 1)
    xcounts = zeros(Float64, N, length(xrange) - 1)
    ycounts = zeros(Float64, N, length(yrange) - 1)
    ntracks = 0
    for s in S
        ntracks += size(s.tracks, 3)
        @views for (n, x) in enumerate(eachslice(s.tracks, dims=1))
            histcounts!(xcounts[n, :], (x[1, :] .+ xshift) .* factor, xrange)
            histcounts!(ycounts[n, :], (x[2, :] .+ yshift) .* factor, yrange)
        end
    end
    xcounts ./= ntracks
    ycounts ./= ntracks
    xcounts, ycounts
end

function credible2D(S::AbstractVector{<:Sample}, i::Integer, xrange::AbstractRange, yrange::AbstractRange; factor::Real=1, xshift::Real=0, yshift::Real=0)
    N = size(S[1].tracks, 1)
    counts = zeros(Float64, N, length(xrange) - 1, length(xrange) - 1)
    ntracks = length(S)
    for s in S
        @views for (n, x) in enumerate(eachslice(s.tracks, dims=1))
            histcounts!(counts[n, :, :], (x[1, i:i] .+ xshift) .* factor, (x[2, i:i] .+ yshift .* factor), xrange, yrange)
        end
    end
    counts ./= ntracks
end

function credible2D(S::AbstractVector{<:Sample}, xrange::AbstractRange, yrange::AbstractRange; factor::Real=1, xshift::Real=0, yshift::Real=0)
    N = size(S[1].tracks, 1)
    counts = zeros(Float64, N, length(xrange) - 1, length(xrange) - 1)
    ntracks = 0
    for s in S
        ntracks += size(s.tracks, 3)
        @views for (n, x) in enumerate(eachslice(s.tracks, dims=1))
            histcounts!(counts[n, :, :], (x[1, :] .+ xshift) .* factor, (x[2, :] .+ yshift) .* factor, xrange, yrange)
        end
    end
    counts ./= ntracks
end