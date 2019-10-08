# developed with Julia 1.1.1
#
# functions to calibrate EMS control models


using EMSx

using JLD
using ProgressMeter


function calibrate_sites(controller::EMSx.AbstractController, 
	path_to_save_folder::String, 
	path_to_price_folder::String, 
	path_to_metadata_csv_file::String, 
	path_to_train_data_folder::String)
	
	prices = EMSx.load_prices(path_to_price_folder)
	site_ids = [split(name, ".")[1]*".jld" for name in readdir(path_to_train_data_folder)]
	sites = EMSx.load_sites(path_to_metadata_csv_file, 
		path_to_train_data_folder, 
		[joinpath(path_to_save_folder, id) for id in site_ids])

	elapsed = 0.0

	@showprogress for site in sites
		
		elapsed += @elapsed site_value_functions = calibrate_site(controller, site, prices)
		
	end

	println("Terminating model calibration in $(elapsed) seconds")

	return nothing

end

function update_site!(controller::EMSx.AbstractController, site::EMSx.Site)
	"""
	hackable function to update site dependent data and parameters
	during model calibration
	"""
	return nothing
end

function update_price!(controller::EMSx.AbstractController, site::EMSx.Price)
	"""
	hackable function to update price dependent data and parameters
	during model calibration
	"""
	return nothing
end

function compute_value_functions(controller::EMSx.AbstractController)
	"""hackable function to compute value functions"""
	return nothing
end

function calibrate_site(controller::EMSx.AbstractController, site::EMSx.Site, 
	prices::Array{EMSx.Price})

	update_site!(controller, site)
	
	value_functions = Dict{String, Any}()
	timer = Float64[]

	for price in prices

		update_price!(controller, price)

		timing = @elapsed value_functions[price.name] = compute_value_functions(controller)
		push!(timer, timing)

	end

	save(site.path_to_save_jld_file, Dict("value_functions"=>value_functions, "time"=>timer))

	return nothing

end 