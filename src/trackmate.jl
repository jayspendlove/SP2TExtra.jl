# function readparticle!(x::AbstractArray{<:Real,2}, particle::XMLDict.XMLDictElement, B::Integer, H::Integer)
#     for detection in particle["detection"]
#         trange = tryparse(Int, detection[:t]) * B .+ (1:B)
#         x[trange, 1] .= tryparse(Float64, detection[:x]) + 0.5
#         x[trange, 2] .= H - 0.5 - tryparse(Float64, detection[:y])
#     end
# end

function parsedetection!(x::AbstractArray{<:Real,2}, particle::XMLDict.XMLDictElement, batchsize::Integer)
    for detection in particle["detection"]
        trange = tryparse(Int, detection[:t]) * batchsize .+ (1:batchsize)
        for (dim, coord) in enumerate([:x, :y, :z])
            x[trange, dim] .= tryparse(Float64, detection[coord])
        end
    end
end

function parseparticle!(x::AbstractArray{<:Real,3}, dict::XMLDict.XMLDictElement, batchsize::Integer)
    if dict["particle"] isa Vector
        for (m, detection) in enumerate(dict["particle"])
            parsedetection!(view(x, :, :, m), detection, batchsize)
        end
    else
        parsedetection!(view(x, :, :, 1), dict["particle"], batchsize)
    end
end

function xml2tracks(xml::String; batchsize::Integer=1, nframes::Integer, pxsize::Real=1)
    xmlcontent = parse_xml(String(read(xml)))
    ntracks = tryparse(Int, xmlcontent[:nTracks])
    tracks = fill!(Array{Float64}(undef, nframes, 3, ntracks), NaN)
    parseparticle!(tracks, xmlcontent, batchsize)
    @view tracks[:, 1:2, :] .+= 0.5
    tracks .*= pxsize
end

function xml2tracks(xmls::AbstractVector{String}; batchsizes::AbstractVector{<:Integer}, nframes::Integer, pxsize::Real=1)
    tracks = Vector{Array{Float64,3}}()
    for (xml, batchsize) in zip(xmls, batchsizes)
        push!(tracks, xml2tracks(xml; batchsize=batchsize, nframes=nframes, pxsize=pxsize))
    end
    tracks
end