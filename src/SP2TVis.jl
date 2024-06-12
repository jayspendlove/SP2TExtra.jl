module SP2TVis

using GLMakie, SP2T, ColorSchemes, Combinatorics
# Write your package code here.

export viewframes, visualize

include("data_viewer.jl")
include("visualize.jl")

end
