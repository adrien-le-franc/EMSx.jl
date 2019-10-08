# developed with Julia 1.1.1
#
# EMS simulation with a SDP controller
# Offline computing of value functions
#
# SDP is computed with a package available at 
# https://github.com/adrien-le-franc/StoOpt.jl


using EMSx
using StoOpt


include("function.jl")
include("calibrate.jl")
include("../arguments.jl")


args = parse_commandline()


mutable struct Sdp <: EMSx.AbstractController
   model::StoOpt.SDP 
end


dx = 0.1
du = 0.1
horizon = 672

site_pointer = Ref(EMSx.Site("", EMSx.Battery(0., 0., 0., 0.), "", ""))
price_pointer = Ref(EMSx.Price("", [0.], [0.]))

function offline_cost(t::Int64, state::Array{Float64,1}, control::Array{Float64,1}, 
	noise::Array{Float64,1})
	control = control[1]*site_pointer.x.battery.power*0.25
    imported_energy = control + noise[1]
    return (price_pointer.x.buy[t]*max(0.,imported_energy) - 
    	price_pointer.x.sell[t]*max(0.,-imported_energy))
end

function offline_dynamics(t::Int64, state::Array{Float64,1}, control::Array{Float64,1}, 
	noise::Array{Float64,1})
	scale_factor = site_pointer.x.battery.power*0.25/site_pointer.x.battery.capacity
    soc = state + (site_pointer.x.battery.charge_efficiency*max.(0.,control) - 
    	max.(0.,-control)/site_pointer.x.battery.discharge_efficiency)*scale_factor
    return soc
end

sdp = StoOpt.SDP(Grid(0:dx:1, enumerate=true),
	Grid(-1:du:1), 
    nothing,
    offline_cost,
    offline_dynamics,
    horizon)

const controller = Sdp(sdp)

function update_site!(controller::Sdp, site::EMSx.Site)
	site_pointer.x = site
	controller.model.noises = data_frames_to_noises(site.path_to_data_csv)
end

function update_price!(controller::Sdp, price::EMSx.Price)
	price_pointer.x = price
end

function compute_value_functions(sdp::Sdp)
	return StoOpt.compute_value_functions(sdp.model)
end


calibrate_sites(controller, 
	joinpath(args["save"], "sdp"),
	args["price"],
	args["metadata"],
	args["train"])