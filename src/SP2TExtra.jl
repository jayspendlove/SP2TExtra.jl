module SP2TExtra

using GLMakie, SP2T, ColorSchemes, Combinatorics, StatsBase
# Write your package code here.

export readbin, getframes, extractROI

export getdarkcounts

export ntracks, findMAP, findML

export viewframes, visualize

include("import.jl")
include("preprocess.jl")
include("previsualize.jl")
include("postprocess.jl")
include("postvisualize.jl")

end
