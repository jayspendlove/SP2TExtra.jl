module SP2TExtra

using GLMakie, SP2T, ColorSchemes, Combinatorics, StatsBase
# Write your package code here.

export readbin, getframes, extractROI

export viewframes, visualize

include("import.jl")
include("data_viewer.jl")
include("visualize.jl")

end
