# Annealing schedules usable with SP2T.runMCMC's `annealing` kwarg.
#
# This lives in SP2TExtra (a package namespace) rather than in a driver script deliberately:
# SP2T's Chain embeds the annealing object as a type parameter, so a chain saved with a
# Main-defined schedule type cannot be JLD2-loaded in any session that did not re-define that
# type in Main (the whole Chain comes back as a JLD2.Reconstructed* stub). As
# SP2TExtra.PolyDecayAnnealing it round-trips anywhere `using SP2TExtra` holds.

"""
    PolyDecayAnnealing{T}(T0, horizon, order)

Likelihood-tempering schedule: 𝑇(i) = 1 + (T0 − 1)·(1 − i/horizon)^order for i < horizon, and
exactly 1 from the horizon on.

Defined here INSTEAD of SP2T's own `PolynomialAnnealing`, whose formula `𝑇₀·(i/I − 1)^order`
(SP2T annealing.jl:38-39) is wrong: for even `order` it decays toward 0 as i → I — i.e. the
likelihood is *amplified* without bound just before the horizon — then jumps to 1; for odd
`order` the temperature is negative, inverting acceptance. Remove this once that is fixed
upstream.

SP2T applies the temperature to the per-frame Δlog-likelihood in the track update, the
brightness update, and the nonparametric emitter-count update; the motion term and all priors
are untempered. `temperature(a, i)` takes the ABSOLUTE iteration number, so on a continuation
run the schedule stays finished (𝑇 ≡ 1).
"""
struct PolyDecayAnnealing{T<:AbstractFloat} <: SP2T.Annealing{T}
    T0::T
    horizon::T
    order::Int
end

SP2T.temperature(a::PolyDecayAnnealing{T}, i::Real) where {T} =
    i >= a.horizon ? one(T) :
    one(T) + (a.T0 - one(T)) * (one(T) - T(i) / a.horizon)^a.order
