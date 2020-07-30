module EMSx

using ProgressMeter 
using Distributed
using Dates, TimeZones, CSV, DataFrames, CodecZlib, Mmap
using JLD
using HTTP

const DIR = dirname(@__DIR__)

include("struct.jl")

include("database_interface/download_data.jl")
include("database_interface/split_data.jl")
include("database_interface/simulation_interface.jl")

include("parallel_progress.jl")
include("parallel.jl")

include("function.jl")
include("simulate.jl") 

end 
