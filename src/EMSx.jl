module EMSx

using ArgParse, CSV, DataFrames
using StoOpt

include("struct.jl")
include("utils.jl")
include("simulate.jl") 

export Paths, Site, Battery, Period, Scenario
export parse_commandline, check_arguments, load_sites, load_data
export simulate_site, simulate_period, simulate_scenario

end
