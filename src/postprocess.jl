function ntracks(chain::Chain; burn_in::Real=0)
    n = 0
    for i = burn_in+1:length(chain.samples)
        n += size(chain.samples[i].tracks, 3)
    end
    n
end

findMAP(chain::Chain; burn_in::Real=0) =
    @views findmax([s.log𝒫 for s in chain.samples[burn_in+1:end]])

findML(chain::Chain; burn_in::Real=0) =
    @views findmax([s.logℒ for s in chain.samples[burn_in+1:end]])

function uncertainty1D(S::AbstractVector{<:Sample}, xrange::AbstractRange, yrange::AbstractRange; factor::Real=1)
    N = size(S[1].tracks, 1)
    xcounts = zeros(Float64, N, length(xrange) - 1)
    ycounts = zeros(Float64, N, length(yrange) - 1)
    ntracks = 0
    for s in S
        ntracks += size(s.tracks, 3)
        @views for (n, x) in enumerate(eachslice(s.tracks, dims=1))
            histcounts!(xcounts[n, :], x[1, :], xrange ./ factor)
            histcounts!(ycounts[n, :], x[2, :], yrange ./ factor)
        end
    end
    xcounts ./= ntracks
    ycounts ./= ntracks
    xcounts, ycounts
end

function uncertainty2D(S::AbstractVector{<:Sample}, xrange::AbstractRange, yrange::AbstractRange; factor::Real=1)
    N = size(S[1].tracks, 1)
    counts = zeros(Float64, N, length(xrange) - 1, length(xrange) - 1)
    ntracks = 0
    for s in S
        ntracks += size(s.tracks, 3)
        @views for (n, x) in enumerate(eachslice(s.tracks, dims=1))
            histcounts!(counts[n, :, :], x[1, :], x[2, :], xrange ./ factor, yrange ./ factor)
        end
    end
    counts ./= ntracks
end