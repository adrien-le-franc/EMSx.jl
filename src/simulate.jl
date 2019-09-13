# developed with Julia 1.1.1
#
# functions to simulate EMS 


function simulate_site(model::AbstractModel, site::Site, paths::Paths)

	test_data = load_data(site.id, paths.test_data)
	train_noises = load_train_data!(model, site, paths)

	periods = unique(test_data[:period_id])
	simulations = Simulation[]

	@showprogress for period_id in periods

		test_data_period = test_data[test_data.period_id .== period_id, :]
		period = Period(string(period_id), test_data_period, site, Simulation[])

		update_period!(model, period, train_noises)
		simulate_period!(model, period, paths)
		append!(simulations, period.simulations)

	end

	save_simulations(paths.save, site.id, simulations)

	return nothing 

end

function simulate_period!(model::AbstractModel, period::Period, paths::Paths)

	battery = period.site.batteries
	update_battery!(model, battery)
	scenario = Scenario(period.site.id, period.id, battery, period.data, model, paths)
	simulation = simulate_scenario(scenario)
	push!(period.simulations, simulation)

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

function online_step(scenario::Scenario, value_functions::Union{ValueFunctions,Nothing}) 

	state = initiate_state(scenario.model)
	horizon = size(scenario.data, 1)
	id = Id(scenario)
	simulation = Simulation(Result(zeros(horizon), zeros(horizon)), id)

	for t in 1:horizon

		noise = online_information!(scenario.model, scenario.data, state, t)
		control = StoOpt.compute_control(scenario.model, cost, dynamics, t, state, noise, 
			value_functions)

		stage_cost, state = apply_control(scenario, t, state, control)
		simulation.result.cost[t] = stage_cost
		simulation.result.soc[t] = state_of_charge(scenario.model, state)

	end

	return simulation

end

function apply_control(scenario::Scenario, t::Int64, state::Array{Float64,1}, 
	control::Array{Float64,1})

	load = scenario.data[:actual_consumption][t] / 1000
	pv = scenario.data[:actual_pv][t] / 1000
	net_energy_demand = [load-pv]

	stage_cost = online_cost(scenario.model, t, state, control, net_energy_demand)
	new_state = online_dynamics(scenario.model, t, state, control, net_energy_demand)

	return stage_cost, new_state

end