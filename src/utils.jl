# developed with Julia 1.0.3
#
# simulation script for micro grid control


function parse_commandline()

	s = ArgParseSettings()

    @add_arg_table s begin

    	## REQUIRED ##
        
        "--save"
        	help = "folder to save results"
        	arg_type = String
        	required = true 

        "--model"
        	help = "simulation model name - expect to find struct in models.jl"
        	arg_type = String
        	required = true

        ## paths ##

        "--metadata"
        	help = "metadata.csv - site and battery parameters"     
        	arg_type = String
        	default = "/home/EMSx.jl/data/metadata.csv"

        "--train"
        	help = "train data folder"
        	arg_type = String
        	default = "/home/EMSx.jl/data/train"

        "--test"
        	help = "test data folder"
        	arg_type = String
        	default = "/home/EMSx.jl/data/test"
     
    end

    return parse_args(s)
    
end

function check_arguments(args::Dict{String,Any})
	
end

function load_sites(path_to_csv::String)

	sites = Site[]
	data = CSV.read(path_to_csv)
	number_of_sites = size(data, 1)

	for row in 1:number_of_sites

		site = Site(data, row)
		push!(sites, site)

	end

	return sites

end

function load_data(site_id::String, path_to_fodler::String)
	path = path_to_fodler*"/$(site_id).csv"
	data = CSV.read(path)
end

