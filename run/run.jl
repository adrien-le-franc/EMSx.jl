# developed with Julia 1.1.1
#
# simulation script for micro grid control


using EMSx

function main()

	args = parse_commandline()

	#check_arguments(args)

	sites = EMSx.load_sites(args["metadata"], args["test"], args["save"])
	prices = EMSx.load_prices(args["prices"])



	model = EMSx.DummyController() #initiate_model(args["%COMMAND%"], args[args["%COMMAND%"]])

	#paths = Paths(args["train"], args["test"], args["save"])

	elapsed = 0.0

	for site in sites
		
		elapsed += @elapsed simulate_site(model, site, prices) 

	end

	save_time(args["save"], elapsed)

end


main()