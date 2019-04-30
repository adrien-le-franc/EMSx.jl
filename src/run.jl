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

        "--method"
        	help = "simulation method name - expect to findscript methods/method.jl"
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

function main()

	args = parse_commandline()
	check_arguments(args)

	sites = load_sites(args["metadata"])

	for site in sites

		simulate_site(site, args)

	end

end


main()