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
    xcounts = zeros(Int, N, length(xrange) - 1)
    ycounts = zeros(Int, N, length(yrange) - 1)
    for s in S
        @views for (n, r) in enumerate(eachslice(s.tracks, dims=1))
            histcounts!(xcounts[n, :], r[1, :], xrange ./ factor)
            histcounts!(ycounts[n, :], r[2, :], yrange ./ factor)
        end
    end
    xcounts, ycounts
end

function uncertainty2D(S::AbstractVector{<:Sample}, xrange::AbstractRange, yrange::AbstractRange; factor::Real=1)
    N = size(S[1].tracks, 1)
    counts = zeros(Int, N, length(xrange) - 1, length(xrange) - 1)
    for s in S
        @views for (n, r) in enumerate(eachslice(s.tracks, dims=1))
            histcounts!(counts[n, :, :], r[1, :], r[2, :], xrange ./ factor, yrange ./ factor)
        end
    end
    counts
end