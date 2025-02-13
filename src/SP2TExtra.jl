module SP2TExtra

using GLMakie, SP2T, ColorSchemes, Combinatorics, StatsBase, TiffImages, MAT
using XMLDict

export binframes
export readbin, getframes, extractROI, readtiff
export getdarkcounts
export ntracks, credible1D, credible2D
export viewframes, visualize
export xml2tracks

include("histcounts.jl")
include("binframes.jl")
include("import.jl")
include("preprocess.jl")
include("previsualize.jl")
include("postprocess.jl")
include("postvisualize.jl")
include("trackmate.jl")

end
