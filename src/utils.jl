# developed with Julia 1.0.3
#
# simulation script for micro grid control


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
	path = path_to_fodler*"$(site_id).csv"
	data = CSV.read(path)
end

