# developed with Julia 1.0.3
#
# simulation script for micro grid control


using EMSx


function main()

	args = parse_commandline()
	check_arguments(args)

	sites = load_sites(args["metadata"])
	model = init_model(args["%COMMAND%"], args[args["%COMMAND%"]])
	paths = Paths(args["train"], args["test"], args["save"])

	for site in sites

		simulate_site(site, model, paths) 

	end

end


main()