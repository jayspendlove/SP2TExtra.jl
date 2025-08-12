function parsedetection!(x::AbstractArray{<:Real,2}, particle::XMLDict.XMLDictElement, batchsize::Integer)
    for detection in particle["detection"]
        trange = tryparse(Int, detection[:t]) * batchsize .+ (1:batchsize)
        for (dim, coord) in enumerate([:x, :y, :z])
            x[trange, dim] .= tryparse(Float64, detection[coord])
        end
    end
    return x
end

function parseparticle!(x::AbstractArray{<:Real,3}, dict::XMLDict.XMLDictElement, batchsize::Integer)
    if dict["particle"] isa Vector
        for (m, detection) in enumerate(dict["particle"])
            parsedetection!(view(x, :, :, m), detection, batchsize)
        end
    else
        parsedetection!(view(x, :, :, 1), dict["particle"], batchsize)
    end
    return x
end

function xml2tracks(xml::String; batchsize::Integer=1, nframes::Integer)
    xmlcontent = parse_xml(String(read(xml)))
    ntracks = tryparse(Int, xmlcontent[:nTracks])
    tracks = fill!(Array{Float64}(undef, nframes, 3, ntracks), NaN)
    parseparticle!(tracks, xmlcontent, batchsize)
end

function xml2tracks(xmls::AbstractVector{String}; batchsizes::AbstractVector{<:Integer}, nframes::Integer)
    tracks = Vector{Array{Float64,3}}()
    for (xml, batchsize) in zip(xmls, batchsizes)
        push!(tracks, xml2tracks(xml; batchsize=batchsize, nframes=nframes))
    end
    tracks
end