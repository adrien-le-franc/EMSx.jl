# developed with Julia 1.1.1
#
# utility functions for EMSx


# data loading 

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

function save_simulations(path_to_jld::String, site_id::String, simulations::Array{Simulation})
	file = Dict()
	try file = load(path_to_jld)
	catch error
	end
	file[site_id] = simulations
	save(path_to_jld, file)
end

function save_time(path_to_jld, elapsed::Float64)
	file = load(path_to_jld)
	file["time"] = elapsed
	save(path_to_jld, file)
end

# generic functions for simulation - methods may have to be implemented for specific models in models.jl

function load_train_data(site::Site, model::AbstractModel, paths::Paths)
	DataFrame()
end

function update_period!(period::Period, model::AbstractModel, data::DataFrame)
end

function update_battery!(model::AbstractModel, battery::Battery)
end

function cost(model::AbstractModel, t::Int64, state::Array{Float64,1}, control::Array{Float64,1},
	noise::Array{Float64,1})
	control = control*model.cost_parameters["pmax"]*0.25
	energy_demand = (control + noise)[1]
	return (model.cost_parameters["buy_price"][t]*max(0.,energy_demand) 
		- model.cost_parameters["sell_price"][t]*max(0.,-energy_demand))
end

function dynamics(model::AbstractModel, time::Int64, state::Array{Float64,1}, 
	control::Array{Float64,1}, noise::Array{Float64,1}) 
	normalize = model.dynamics_parameters["pmax"]*0.25/model.dynamics_parameters["cmax"]
	return state + (model.dynamics_parameters["charge_efficiency"]*max.(0.,control) 
		- max.(0.,-control)/model.dynamics_parameters["discharge_efficiency"])*normalize
end

function initiate_state(model::AbstractModel)
	return [0.0]
end

function state_of_charge(model::AbstractModel, state::Array{Float64})
	return state[1]
end
