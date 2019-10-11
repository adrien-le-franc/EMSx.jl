# developed with Julia 1.1.1
#
# functions for simulating micro grid control


function load_sites(path_to_metadata_csv::String, path_to_data_folder::String, 
	path_to_save_folder::String)

    sites = Site[]
    metadata = CSV.read(path_to_metadata_csv)
    number_of_sites = size(metadata, 1)

    for row in 1:number_of_sites
        site = Site(metadata, row, path_to_data_folder, path_to_save_folder)
        push!(sites, site)
    end

    return sites

end

function load_prices_csv(path_to_csv::String)

	prices = CSV.read(path_to_csv)
	if !(names(prices) == [:timestamp, :buy, :sell] && size(prices, 1) == 672)
		error("price DataFrame at $(path_to_csv) is not in expected shape")
	end
	prices[:timestamp] = Dates.Time.(prices[:timestamp])
	return prices

end

function load_prices(path_to_prices::String)

	prices = Price[]

	if !isdir(path_to_prices)
		name = split(split(path_to_prices, "/")[end], ".")[1]
		data_frame = load_prices_csv(path_to_prices)
		push!(prices, Price(name, data_frame[:buy], data_frame[:sell]))
	else
		for file in readdir(path_to_prices)
			name = split(split(path_to_prices, "/")[end], ".")[1]
			data_frame = load_prices_csv(joinpath(path_to_prices, file))
			push!(prices, Price(name, data_frame[:buy], data_frame[:sell]))	
		end
	end

	return prices

end

function compute_stage_cost(battery::Battery, price::Price, t::Int64, 
	control::Float64, net_energy_demand::Float64)

	control = control*battery.power*0.25
	imported_energy = (control + net_energy_demand)
	return (price.buy[t]*max(0.,imported_energy) 
		- price.sell[t]*max(0.,-imported_energy))

end

function compute_stage_dynamics(battery::Battery, state::Float64, control::Float64)

	scale_factor = battery.power*0.25/battery.capacity
	soc = state + (battery.charge_efficiency*max(0.,control) 
		- max(0.,-control)/battery.discharge_efficiency)*scale_factor
	soc = max(0., min(1., soc)) 
	return soc

end

function save_simulations(site::Site, simulations::Array{Simulation})
	file = Dict()
	try file = load(joinpath(site.path_to_save_folder, "score.jld"))
	catch error
	end
	file[site.id] = simulations
	save(joinpath(site.path_to_save_folder, "score.jld"), file)
end

function save_time(path_to_save_folder, elapsed::Float64)
	file = load(joinpath(path_to_save_folder, "score.jld"))
	file["time"] = elapsed
	save(joinpath(path_to_save_folder, "score.jld"), file)
end

### hackable functions

function compute_control(controller::AbstractController, information::Information)
	return 0. 
end
