# developed with Julia 1.0.3
#
# functions to simulate micro grid control


function load_sites(path_to_csv::String)

	sites = Site[]
	header = Dict()

	open(path_to_csv, "r") do file
		for (i, line) in enumerate(eachline(file))

			line = split(line, ",")

			if i == 1
				header = Dict(name=>index for (index, name) in enumerate(line))
			else
				site = Site(line, header)
				push!(sites, site)
			end

		end
	end

	return sites

end