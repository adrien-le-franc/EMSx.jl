# developed with Julia 1.3.0
#
# EMS simulation with a MPC controller
# the online computing of optimal controls is written in LP form
#
# this example can be run with any JuMP compatible LP solver
# e.g replace CPLEX with Clp


using EMSx
using JuMP, CPLEX

using MathOptInterface
const MOI = MathOptInterface

include("arguments.jl")


args = parse_commandline()


mutable struct Mpc <: EMSx.AbstractController
	model::Model
	horizon::Int64
	Mpc() = new()
end


const controller = Mpc()

function EMSx.initialize_site_controller(controller::Mpc, site::EMSx.Site)
	
	controller = Mpc()

	model = Model(with_optimizer(CPLEX.Optimizer))
    MOI.set(model, MOI.RawParameter("CPX_PARAM_SCRIND"), 0)

	horizon = 96
	battery = site.battery

	@variable(model, 0 <= u_c[1:horizon])
	@variable(model, 0 <= u_d[1:horizon])
	@variable(model, 0 <= x[1:horizon+1])
	@variable(model, 0 <= z[1:horizon])
	@variable(model, w[1:horizon])
	@variable(model, x0)

	@expression(model, u,  u_c - u_d)

	@constraint(model, u_c .<= battery.power*0.25)
	@constraint(model, u_d .<= battery.power*0.25)
	@constraint(model, x .<= battery.capacity)
	@constraint(model, u.+w .<= z)
	@constraint(model, x[1] == x0)
	@constraint(model, dynamics, diff(x) .== u_c*battery.charge_efficiency .- 
		u_d/battery.discharge_efficiency)

	controller.model = model
	controller.horizon = horizon

	return controller

end

function EMSx.update_price!(controller::Mpc, price::EMSx.Price)
	return nothing
end

function EMSx.compute_control(controller::Mpc, information::EMSx.Information)

	fix(controller.model[:x0], information.soc*information.battery.capacity)
	fix.(controller.model[:w], information.forecast_load - information.forecast_pv)

	# set prices, padding out of test period prices with zero values
	price = information.price
	price_window = information.t:min(information.t+controller.horizon-1, size(price.buy, 1))
	if length(price_window) != controller.horizon
		padding = controller.horizon - length(price_window)
		price = EMSx.Price(price.name, vcat(price.buy[price_window], zeros(padding)), 
			vcat(price.sell[price_window], zeros(padding)))
	else
		price = EMSx.Price(price.name, price.buy[price_window], price.sell[price_window])
	end

	@objective(controller.model, Min, 
		sum(price.buy.*controller.model[:z]-
			price.sell.*(controller.model[:z]-controller.model[:u]-controller.model[:w])))

	optimize!(controller.model)

    return value(controller.model[:u][1]) / (information.battery.power*0.25)

end

EMSx.simulate_sites(controller, 
	joinpath(args["save"], "mpc"), 
	args["price"], 
	args["metadata"], 
	args["test"])