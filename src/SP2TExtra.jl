module SP2TExtra

using SP2T, Combinatorics, StatsBase, TiffImages, MAT, ImageCore, Statistics
using XMLDict

export binframes, bintracks
export readbin, getframes, extractROI, readtiff, writetiff, ImageJTIff
export getdarkcounts
export credible1D, credible2D, msd, tracks, localization_error
export xml2tracks

include("histcounts.jl")
include("binframes.jl")
include("import.jl")
include("preprocess.jl")
include("postprocess.jl")
include("trackmate.jl")
include("tiff.jl")

end
