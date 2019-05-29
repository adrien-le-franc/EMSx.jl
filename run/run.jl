# developed with Julia 1.1.1
#
# simulation script for micro grid control


using EMSx

function main()

	args = parse_commandline()
	check_arguments(args)

	sites = load_sites(args["metadata"])
	model = initiate_model(args["%COMMAND%"], args[args["%COMMAND%"]])
	paths = Paths(args["train"], args["test"], args["save"])

	elapsed = 0.0

	for site in sites

		elapsed += @elapsed simulate_site(site, model, paths) 

	end

	save_time(paths.save, elapsed)

end


main()