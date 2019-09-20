# developed with Julia 1.1.1
#
# functions to simulate EMS 


function simulate_site(model::AbstractModel, site::Site, 
	prices::Dict{String, DataFrame})

	test_data = CSV.read(site.path_to_data_csv)


	#train_noises = load_train_data!(model, site, paths)

	periods = unique(test_data[:period_id])
	
	simulations = Simulation[]

	@showprogress for period_id in periods

		test_data_period = test_data[test_data.period_id .== period_id, :]

		### ?

		period = Period(string(period_id), test_data_period, site, Simulation[])



		#update_period!(model, period, train_noises)

		simulate_period!(model, period, prices)

		append!(simulations, period.simulations)

	end

	save_simulations(paths.save, site.id, simulations)

	return nothing 

end

function simulate_period!(model::AbstractModel, period::Period, prices::Dict{String, DataFrame})

	battery = period.site.battery

	#update_battery!(model, battery)

	for (price_name, price) in prices

		#scenario = Scenario(period.site.id, period.id, battery, period.data, model, paths)

		simulation = simulate_scenario(model, period, price_name, price)
		push!(period.simulations, simulation)

	end

	"""
	for battery in period.site.batteries

		update_battery!(model, battery)
		scenario = Scenario(period.site.id, period.id, battery, period.data, model, paths)
		simulation = simulate_scenario(scenario)
		push!(period.simulations, simulation)

	end
	"""

	return nothing

end

"""
function simulate_scenario(scenario::Scenario)

	value_functions = offline_step(scenario)
	simulation = online_step(scenario, value_functions)

	return simulation

end

function offline_step(scenario::Scenario)

	model = scenario.model

	if ! (typeof(model) <: DynamicProgrammingModel)
		return nothing
	else
		return StoOpt.compute_value_functions(model, cost, dynamics)
	end

end
"""

function simulate_scenario(model::AbstractModel, period::Period, price_name::String, 
	price::DataFrame) 

	state = initiate_state(model)
	horizon = size(period.data, 1) ## change ?? -> 8 days for week + history
	id = Id(period.site.id, period.id, price_name, typeof(model))

	simulation = Simulation(Result(zeros(horizon), zeros(horizon)), id)

	result = Result(horizon)

	for t in 1:horizon ## change ?? -> 8 days for week + history

		#noise = online_information!(scenario.model, scenario.data, state, t)
		information = 0. #f(...? state ? data ? ...)
		control = compute_control(model, information, t)


		#control = StoOpt.compute_control(scenario.model, cost, dynamics, t, state, noise, 
		#	value_functions)


		stage_cost, state = apply_control(period, t, state, control, price)
		result.cost[t] = stage_cost
		result.soc[t] = state_of_charge(scenario.model, state)

	end

	return simulation

end

function apply_control(period::Period, t::Int64, state::Array{Float64,1}, 
	control::Array{Float64,1}, price::DataFrame)

	load = period.data[:actual_consumption][t] 
	pv = period.data[:actual_pv][t] 
	net_energy_demand = [load-pv]

	stage_cost = stage_cost(price, t, control, net_energy_demand)
	new_state = stage_dynamics(period.site.battery, state, control)

	return stage_cost, new_state

end