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