module SP2TExtra

using GLMakie, SP2T, ColorSchemes, Combinatorics, StatsBase
using NaNStatistics: histcounts, histcounts!

export readbin, getframes, extractROI

export getdarkcounts

export ntracks, findMAP, findML, uncertainty1D, uncertainty2D

export viewframes, visualize

include("import.jl")
include("preprocess.jl")
include("previsualize.jl")
include("postprocess.jl")
include("postvisualize.jl")

end
