module SP2TExtra

using GLMakie, SP2T, Combinatorics, StatsBase, TiffImages, MAT, ImageCore
using XMLDict

export binframes, bintracks
export readbin, getframes, extractROI, readtiff, writetiff, ImageJTIff
export getdarkcounts
export ntracks, credible1D, credible2D
export viewframes
export xml2tracks

include("histcounts.jl")
include("binframes.jl")
include("import.jl")
include("preprocess.jl")
include("previsualize.jl")
include("postprocess.jl")
include("trackmate.jl")
include("tiff.jl")

end
