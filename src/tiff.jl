abstract type TiffMeta end

struct ImageJTIff <: TiffMeta end

function getbits(ifds::AbstractVector{<:TiffImages.IFD})
    bits = [ifd[TiffImages.BITSPERSAMPLE].data for ifd in ifds]
    if length(unique(bits)) > 1
        throw(DomainError("The bit depth of the frames is not consistent."))
    end
    return bits[1]
end

function getpixelsize(ifds::AbstractVector{<:TiffImages.IFD})
    pixelsizex = [ifd[TiffImages.XRESOLUTION].data for ifd in ifds]
    pixelsizey = [ifd[TiffImages.YRESOLUTION].data for ifd in ifds]
    if length(unique(pixelsizex)) > 1 || length(unique(pixelsizey)) > 1
        throw(DomainError("The pixel size of the frames is not consistent."))
    elseif pixelsizex[1] != pixelsizey[1]
        throw(DomainError("The pixel size of the frames is not isotropic."))
    end
    return float(pixelsizex[1])
end

parsestring(str::AbstractString) = unescape_string(split(str, "=")[2])

function parse_descriptions(ifd::TiffImages.IFD, keyword::String, T::DataType)
    descriptions = split(ifd[TiffImages.IMAGEDESCRIPTION].data, "\n")
    for description in descriptions
        if occursin(keyword, description)
            if T === String
                return parsestring(description)
            else
                return tryparse(T, split(description, "=")[2])
            end
        end
    end
end

getperiod(ifd::TiffImages.IFD) = parse_descriptions(ifd, "finterval", Float64)
getperiod(ifds::AbstractVector{<:TiffImages.IFD}) = getperiod(ifds[1])

getunit(ifd::TiffImages.IFD) = parse_descriptions(ifd, "unit", String)
getunit(ifds::AbstractVector{<:TiffImages.IFD}) = getunit(ifds[1])

function readtiff(path::String)
    readouts = TiffImages.load(path)
    ifd = ifds(readouts)
    bits = getbits(ifd)
    metadata = Dict(
        "period" => getperiod(ifd),
        "pixel size" => getpixelsize(ifd),
        "unit" => getunit(ifd),
    )
    readouts = convert(Array{Float64,3}, readouts)
    readouts .*= 2^bits - 1
    return convert(Array{UInt16,3}, readouts), metadata
end

function writetiff(path::String, frames::AbstractArray{UInt16,3}; px_size::Real=1, unit::AbstractString="μm", period::Real=1)
    tiff = TiffImages.DenseTaggedImage(reinterpret(Gray{N0f16}, frames))
    ifdvec = ifds(tiff)
    nframes = size(frames, 3)
    for ifd in ifdvec
        res = Rational{UInt32}(round(1 / px_size, digits=3))
        ifd[TiffImages.XRESOLUTION] = res
        ifd[TiffImages.YRESOLUTION] = res
        ifd[TiffImages.RESOLUTIONUNIT] = oneunit(UInt8)
    end
    unit == "μm" && (unit = "um")
    ifdvec[1][TiffImages.IMAGEDESCRIPTION] = "unit=$unit\nfinterval=$period"
    TiffImages.save(path, tiff)
end

# writetiff(frames::AbstractArray{UInt16,3}, path::String, ::ImageJTIff; metadata::Dict) = writetiff(frames, path, ImageJTIff(); px_size=metadata["pixel size"], unit=metadata["unit"], period=metadata["period"])
