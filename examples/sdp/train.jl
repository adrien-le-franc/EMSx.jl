# developed with Julia 1.1.1
#
# EMS simulation with a SDP controller
# Offline computing of value functions
#
# SDP is computed with a package available at 
# https://github.com/adrien-le-franc/StoOpt.jl


using EMSx
using StoOpt

using DataFrames
using ProgressMeter
using CSV

include("utils.jl")
include("../arguments.jl")


args = parse_commandline()


mutable struct Sdp <: EMSx.AbstractController
   model::StoOpt.SDP 
end


dx = 0.1
du = 0.1
horizon = 672

battery_pointer = Ref(EMSx.Battery(0., 0., 0., 0.))
price_pointer = Ref(EMSx.Price("", [0.], [0.]))

function offline_cost(t::Int64, state::Array{Float64,1}, control::Array{Float64,1}, 
	noise::Array{Float64,1})
	control = control[1]*battery_pointer.x.power*0.25
    imported_energy = control + noise[1]
    return (price_pointer.x.buy[t]*max(0.,imported_energy) - 
    	price_pointer.x.sell[t]*max(0.,-imported_energy))
end

function offline_dynamics(t::Int64, state::Array{Float64,1}, control::Array{Float64,1}, 
	noise::Array{Float64,1})
	scale_factor = battery_pointer.x.power*0.25/battery_pointer.x.capacity
    soc = state + (battery_pointer.x.charge_efficiency*max.(0.,control) - 
    	max.(0.,-control)/battery_pointer.x.discharge_efficiency)*scale_factor
    return soc
end

sdp = StoOpt.SDP(Grid(0:dx:1, enumerate=true),
	Grid(-1:du:1), 
    nothing,
    offline_cost,
    offline_dynamics,
    horizon)

const controller = Sdp(sdp)

function compute_value_functions(sdp::Sdp)
	return StoOpt.compute_value_functions(sdp.model)
end




function data_frame_to_noise(offline_law::Dict{String,DataFrame})

	w_week_day = hcat(offline_law["week_day"][:value]...)'
	pw_week_day = hcat(offline_law["week_day"][:probability]...)'
	w_week_end = hcat(offline_law["week_end"][:value]...)'
	pw_week_end = hcat(offline_law["week_end"][:probability]...)'

	# one-week-long stochastic process
	w = vcat([w_week_day for i in 1:5]..., [w_week_end for i in 1:2]...)
	pw = vcat([pw_week_day for i in 1:5]..., [pw_week_end for i in 1:2]...)

	return StoOpt.Noises(w, pw)

end




function calibrate_sites(controller::EMSx.AbstractController, 
	path_to_save_folder::String, 
	path_to_price_folder::String, 
	path_to_metadata_csv_file::String, 
	path_to_train_data_folder::String)
	
	prices = EMSx.load_prices(path_to_price_folder)
	model_ids = [split(name, ".")[1]*".jld" for name in readdir(path_to_train_data_folder)]
	sites = EMSx.load_sites(path_to_metadata_csv_file, path_to_train_data_folder, 
		[joinpath(path_to_save_folder, id) for id in model_ids])
	elapsed = 0.0

	@showprogress for site in sites
		
		elapsed += @elapsed site_value_functions = calibrate_site(controller, site, prices)
		
	end

	println("Terminating model calibration in $(elapsed) seconds")

	return nothing

end

function calibrate_site(controller::EMSx.AbstractController, site::EMSx.Site, 
	prices::Array{EMSx.Price})

	train_data = CSV.read(site.path_to_data_csv)
	battery_pointer.x = site.battery

	#calibrate_forecast_model()
	#calibrate_offline_law()

	offline_law = compute_offline_law(train_data)
	controller.model.noises = data_frame_to_noise(offline_law) ##### generic ? ... StoOpt
	value_functions = Dict{String, Any}()
	timer = Float64[]

	for price in prices

		price_pointer.x = price
		timing = @elapsed value_functions[price.name] = compute_value_functions(controller)
		push!(timer, timing)

	end

	save(site.path_to_save_jld_file, Dict("value_functions"=>value_functions, "time"=>timer))

	return nothing

end


calibrate_sites(controller, 
	joinpath(args["save"], "sdp"),
	args["price"],
	args["metadata"],
	args["train"])