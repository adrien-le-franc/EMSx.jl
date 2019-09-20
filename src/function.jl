# developed with Julia 1.1.1
#
# simulation script for micro grid control


function load_sites(path_to_metadata_csv::String, path_to_data_folder::String)

    sites = Site[]
    metadata = CSV.read(path_to_metadata_csv)
    number_of_sites = size(metadata, 1)

    for row in 1:number_of_sites
        site = Site(metadata, row, path_to_data_folder)
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

	prices = Dict()

	if !isdir(path_to_prices)
		name = split(split(path_to_prices, "/")[end], ".")[1]
		prices[name] = load_prices_csv(path_to_prices)
	else
		for file in readdir(path_to_prices)
			name = split(split(path_to_prices, "/")[end], ".")[1]
			prices[name] = load_prices_csv(file)
		end
	end

	return prices

end

function stage_cost(price::DataFrame, t::Int64, control::Array{Float64,1}, net_energy_demand::Arra{Float64,1})

	control = control*battery.power*0.25
	imported_energy = (control + net_energy_demand)[1]
	timestamp = scenario.data[t, :timestamp]
	prices = scenario.model.prices
	return (buy(timestamp, prices)*max(0.,imported_energy) ### buy/sell price -> adapter aux tarifs ...
		- sell(timestamp, prices)*max(0.,-imported_energy))

end

function stage_dynamics(state::Array{Float64,1}, control::Array{Float64,1}, battery::Battery)

	scale_factor = battery.power*0.25/battery.capacity

	soc = state + (battery.charge_efficiency*max.(0.,control) 
		- max.(0.,-control)/battery.discharge_efficiency)*scale_factor

	soc = max(0., min(1., soc[1])) ## MPC ?

	return [soc]

end

### hackable functions

function compute_control(controller::AbstractController, information::Float64, t::Int64)

	return [0.] 

end
