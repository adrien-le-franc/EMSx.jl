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
    train_noises::Dict{String, DataFrame})

    model.cost_parameters["buy_price"] =  Array(period.data[:price_buy_00])
    model.cost_parameters["sell_price"] = Array(period.data[:price_sell_00])
    model.noises = train_noises_of_period(model, period, train_noises)

end

function update_battery!(model::AbstractModel, battery::Battery)

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

online_law(sdp::SDP, df::DataFrame, t::Int64) = RandomVariable(sdp.noises, t)

# SDPOF 
# Online law based on online Forecast

mutable struct SDPOF <: SdpModel

    states::Grid
    controls::Grid
    noises::Union{Noises, Nothing}
    cost_parameters::Dict{String,Any}
    dynamics_parameters::Dict{String,Any}
    horizon::Int64

end

initiate_SDPOF(args::Dict{String,Any}) = SDPOF(Grid(0:args["dx"]:1, enumerate=true), 
    Grid(-1:args["du"]:1), nothing, args["cost_parameters"], args["dynamics_parameters"],
    args["horizon"])

function online_law(sdpof::SDPOF, data::DataFrame, t::Int64)
    forecast = [data[:load_00][t] - data[:pv_00][t]] / 1000
    return RandomVariable(reshape(forecast, 1, 1), [1.])
end

# SDPOO
# Online law based on Observed noise realizations

mutable struct SDPOO <: SdpModel

    states::Grid
    controls::Grid
    noises::Union{Noises, Nothing}
    cost_parameters::Dict{String,Any}
    dynamics_parameters::Dict{String,Any}
    horizon::Int64

end

initiate_SDPOO(args::Dict{String,Any}) = SDPOO(Grid(0:args["dx"]:1, enumerate=true), 
    Grid(-1:args["du"]:1), nothing, args["cost_parameters"], args["dynamics_parameters"], 
    args["horizon"])

function online_law(sdpoo::SDPOO, data::DataFrame, t::Int64)
    observed = [data[:actual_consumption][t] - data[:actual_pv][t]] / 1000
    return RandomVariable(reshape(observed, 1, 1), [1.])
    
end

# MPC

function initiate_MPC(args::Dict{String,Any})

    MPC(nothing, Dict(), Dict(), args["horizon"])

end

function set_online_law!(mpc, data::DataFrame)

    forecasts = zeros(mpc.horizon, 96)
    buy_prices = zeros(mpc.horizon, 96)
    sell_prices = zeros(mpc.horizon, 96)

    for (t, df) in enumerate(eachrow(data))
        for k in 0:95

            quater_ahead = string(k)
            if k < 10
                quater_ahead = "0"*quater_ahead
            end
            forecasts[t, k+1] = (df[Symbol("load_$(quater_ahead)")] 
                - df[Symbol("pv_$(quater_ahead)")]) / 1000
            buy_prices[t, k+1] = df[Symbol("price_buy_$(quater_ahead)")]
            sell_prices[t, k+1] = df[Symbol("price_sell_$(quater_ahead)")]
            
        end
    end

    mpc.forecasts = forecasts
    mpc.cost_parameters = Dict("buy_prices"=>buy_prices, "sell_prices"=>sell_prices)

end
