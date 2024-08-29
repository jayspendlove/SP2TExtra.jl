function readparticle!(x::AbstractArray{<:Real,2}, particle::XMLDict.XMLDictElement, B::Integer, H::Integer)
    for detection in particle["detection"]
        trange = tryparse(Int, detection[:t]) * B .+ (1:B)
        x[trange, 1] .= tryparse(Float64, detection[:x]) + 0.5
        x[trange, 2] .= H - 0.5 - tryparse(Float64, detection[:y])
    end
end

function readparticles!(x::AbstractArray{<:Real,3}, dict::XMLDict.XMLDictElement, B::Integer, H::Integer)
    if dict["particle"] isa Vector
        for (m, particle) in enumerate(dict["particle"])
            readparticle!(view(x, :, :, m), particle, B, H)
        end
    else
        readparticle!(view(x, :, :, 1), dict["particle"], B, H)
    end
end

function xml2tracks(xml::String; batchsize::Integer, nframes::Integer, height::Integer, pxsize::Real)
    xmlcontent = parse_xml(String(read(xml)))
    ntracks = tryparse(Int, xmlcontent[:nTracks])
    tracks = Array{Float64}(undef, nframes, 3, ntracks)
    fill!(tracks, NaN)
    tracks[:, 3, :] .= 0
    readparticles!(tracks, xmlcontent, batchsize, height)
    tracks .*= pxsize
end

function xml2tracks(xmls::AbstractVector{String}; batchsizes::AbstractVector{<:Integer}, nframes::Integer, height::Integer, pxsize::Real)
    tracks = Vector{Array{Float64,3}}()
    for (xml, batchsize) in zip(xmls, batchsizes)
        push!(tracks, xml2tracks(xml; batchsize=batchsize, nframes=nframes, height=height, pxsize=pxsize))
    end
    tracks
end