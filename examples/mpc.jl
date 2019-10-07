# developed with Julia 1.1.1
#
# EMS simulation with a MPC controller
# the online computing of optimal controls is written in LP form
#
# this example can be run with any JuMP compatible LP solver
# e.g replace CPLEX with Clp:
# using Clp
# mpc = Model(with_optimizer(Clp.Optimizer, LogLevel=0))


using EMSx
using JuMP, CPLEX

include("arguments.jl")


args = parse_commandline()


mutable struct Mpc <: EMSx.AbstractController
	model::Model
	horizon::Int64
end


mpc = Model(with_optimizer(CPLEX.Optimizer, CPX_PARAM_SCRIND=0))

horizon = 96

@variable(mpc, 0 <= u_c[1:horizon])
@variable(mpc, 0 <= u_d[1:horizon])
@variable(mpc, 0 <= x[1:horizon+1])
@variable(mpc, 0 <= z[1:horizon])
@variable(mpc, w[1:horizon])
@variable(mpc, x0)
@variable(mpc, cmax)
@variable(mpc, pmax)

@expression(mpc, u,  u_c - u_d)

@constraint(mpc, u_c .<= pmax*0.25)
@constraint(mpc, u_d .<= pmax*0.25)
@constraint(mpc, x .<= cmax)
@constraint(mpc, u.+w .<= z)
@constraint(mpc, x[1] == x0)
@constraint(mpc, dynamics, diff(x) .== u_c .- u_d)

const controller = Mpc(mpc, horizon)

function EMSx.compute_control(mpc::Mpc, information::EMSx.Information)

	fix(mpc.model[:x0], information.soc*information.battery.capacity)
	fix(mpc.model[:cmax], information.battery.capacity)
	fix(mpc.model[:pmax], information.battery.power)
	fix.(mpc.model[:w], information.forecast_load - information.forecast_pv)
	set_coefficient.(mpc.model[:dynamics], mpc.model[:u_c], 
		-information.battery.charge_efficiency)
	set_coefficient.(mpc.model[:dynamics], mpc.model[:u_d], 
		1/information.battery.discharge_efficiency)

	# set prices, padding out of test period prices with zero values
	price = information.price
	price_window = information.t:min(information.t+mpc.horizon-1, size(price.buy, 1))
	if length(price_window) != mpc.horizon
		padding = mpc.horizon - length(price_window)
		price = EMSx.Price(price.name, vcat(price.buy[price_window], zeros(padding)), 
			vcat(price.sell[price_window], zeros(padding)))
	else
		price = EMSx.Price(price.name, price.buy[price_window], price.sell[price_window])
	end

	@objective(mpc.model, Min, 
		sum(price.buy.*mpc.model[:z]-price.sell.*(mpc.model[:z]-mpc.model[:u]-mpc.model[:w])))

	optimize!(mpc.model)

    return value(mpc.model[:u][1]) / (information.battery.power*0.25)

end

EMSx.simulate_sites(controller, 
	joinpath(args["save"], "mpc.jld"), 
	args["price"], 
	args["metadata"], 
	args["test"])