# developed with Julia 1.1.1
#
# models and functions for simulation with EMSx


function initiate_model(model_name::String, args::Dict{String,Any})

    args["cost_parameters"] = Dict("buy_price"=>zeros(args["horizon"]), 
            "sell_price"=>zeros(args["horizon"]), "pmax"=>0.)

    args["dynamics_parameters"] = Dict("charge_efficiency"=>0., "discharge_efficiency"=>0.,
            "pmax"=>0., "cmax"=>0.)

    if model_name == "sdp" 

        if args["online"] == "offline"
            model = initiate_SDP(args)
        elseif args["online"] == "forecast"
            model = initiate_SDPOF(args)
        elseif args["online"] == "observed"
            model = initiate_SDPOO(args)
        else
            error("SDP online law $(args["online"]) is not implemented")
        end 

    elseif model_name == "mpc"

        model = initiate_MPC(args)

    else

        error("Model $(model_name) is not implemented")

    end

    return model

end

# DynamicProgrammingModel
# Generic functions for all models

function update_period!(model::DynamicProgrammingModel, period::Period, 
    train_noise::Dict{String, DataFrame})

    model.cost_parameters["buy_price"] =  Array(period.data[:price_buy_00])
    model.cost_parameters["sell_price"] = Array(period.data[:price_sell_00])
    model.noises = train_noise_of_period(model, period, train_noise)

end

function update_battery!(model::DynamicProgrammingModel, battery::Battery)

    model.cost_parameters["pmax"] = battery.power
    model.dynamics_parameters["charge_efficiency"] = battery.charge_efficiency
    model.dynamics_parameters["discharge_efficiency"] = battery.discharge_efficiency
    model.dynamics_parameters["pmax"] = battery.power
    model.dynamics_parameters["cmax"] = battery.capacity

end

# SDP

initiate_SDP(args::Dict{String,Any}) = SDP(Grid(0:args["dx"]:1, enumerate=true), 
    Grid(-1:args["du"]:1), nothing, args["cost_parameters"], args["dynamics_parameters"], 
    args["horizon"])

# SDPOF 
# Online law based on online Forecast

mutable struct SDPOF <: SdpModel
    states::Grid
    controls::Grid
    noises::Union{Noise, Nothing}
    cost_parameters::Dict{String,Any}
    dynamics_parameters::Dict{String,Any}
    horizon::Int64
end

initiate_SDPOF(args::Dict{String,Any}) = SDPOF(Grid(0:args["dx"]:1, enumerate=true), 
    Grid(-1:args["du"]:1), nothing, args["cost_parameters"], args["dynamics_parameters"],
    args["horizon"])

function set_online_law!(sdpof::SDPOF, data::DataFrame)
    forecast = reshape((data[:load_00] - data[:pv_00]), :, 1) / 1000
    sdpof.noises = Noise(forecast, ones(sdpof.horizon, 1))
end

# SDPOO
# Online law based on Observed noise realizations

mutable struct SDPOO <: SdpModel
    states::Grid
    controls::Grid
    noises::Union{Noise, Nothing}
    cost_parameters::Dict{String,Any}
    dynamics_parameters::Dict{String,Any}
    horizon::Int64
end

initiate_SDPOO(args::Dict{String,Any}) = SDPOO(Grid(0:args["dx"]:1, enumerate=true), 
    Grid(-1:args["du"]:1), nothing, args["cost_parameters"], args["dynamics_parameters"], 
    args["horizon"])

function set_online_law!(sdpoo::SDPOO, data::DataFrame)
    observed = reshape((data[:actual_consumption] - data[:actual_pv]), :, 1) / 1000
    sdpoo.noises = Noise(observed, ones(sdpoo.horizon, 1))
end

# MPC

function initiate_MPC(args::Dict{String,Any})
end