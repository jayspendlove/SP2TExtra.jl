module SP2TExtra

using GLMakie, SP2T, ColorSchemes, Combinatorics, StatsBase
using XMLDict

export binframes
export readbin, getframes, extractROI
export getdarkcounts
export ntracks, findMAP, findML, credible1D, credible2D
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
