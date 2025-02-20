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

function parsestring(str::AbstractString)
    value = split(str, "=")[2]
    if occursin("\\u", value)
        return Char(parse(UInt32, value[3:6], base=16)) * value[7:end]
    else
        return value
    end
end

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

function readtiff(path::String; targettype::Type{T}=UInt16) where {T<:Integer}
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
    return convert(Array{targettype,3}, readouts), metadata
end