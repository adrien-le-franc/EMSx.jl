module EMSx

using ProgressMeter, ArgParse
using Dates, CSV, DataFrames, JLD
using Clustering
using StoOpt 

include("struct.jl")

export Paths, Site, Battery, Period, Scenario, Simulation

include("utils.jl")

export load_sites, load_data, save_simulations, save_time

include("arguments.jl")

export parse_commandline, check_arguments

include("simulate.jl") 

export simulate_site

include("models.jl")

export initiate_model

end 
