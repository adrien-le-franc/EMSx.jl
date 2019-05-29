# developed with Julia 1.1.1
#
# models and functions for simulation with EMSx


function initiate_model(model_name::String, args::Dict{String,Any})

    cost_parameters = Dict("buy_price"=>zeros(args["horizon"]), 
            "sell_price"=>zeros(args["horizon"]), "pmax"=>0.)

    if model_name == "SDP" 

        dynamics_parameters = Dict("charge_efficiency"=>0., "discharge_efficiency"=>0.,
            "pmax"=>0., "cmax"=>0.)

        model = SDP(Grid(0:args["dx"]:1, enumerate=true), Grid(-1:args["du"]:1), nothing, 
            cost_parameters, dynamics_parameters, args["horizon"])    

    else

        error("Model $(model_name) is not implemented")

    end

    return model

end

# SDP

is_week_end(date::Dates.Date) = Dates.dayofweek(date) in [6, 7]
is_summer(date::Dates.Date) = Dates.month(date) in [5, 6, 7, 8, 9]

function load_train_data(site::Site, sdp::SDP, paths::Paths; k=10)

    data = load_data(site.id, paths.train_data) 
    train_data = Dict("week_end_summer"=>Dict(), "week_end_winter"=>Dict(),
        "week_day_summer"=>Dict(), "week_day_winter"=>Dict())

    for df in eachrow(data)

        timestamp = df[:timestamp]
        day, timing = split(timestamp, " ")

        date = Dates.DateTime(day*"T"*timing) - Dates.Minute(15)
        day = Dates.Date(date)
        timing = Dates.Time(timing)

        net_energy_demand = (df[:actual_consumption] - df[:actual_pv]) / 1000

        if is_week_end(day) && is_summer(day)
            if !(timing in keys(train_data["week_end_summer"]))
                train_data["week_end_summer"][timing] = [net_energy_demand]
            else
                push!(train_data["week_end_summer"][timing], net_energy_demand)
            end
        elseif is_week_end(day)
            if !(timing in keys(train_data["week_end_winter"]))
                train_data["week_end_winter"][timing] = [net_energy_demand]
            else
                push!(train_data["week_end_winter"][timing], net_energy_demand)
            end
        elseif !is_week_end(day) && is_summer(day)
            if !(timing in keys(train_data["week_day_summer"]))
                train_data["week_day_summer"][timing] = [net_energy_demand]
            else
                push!(train_data["week_day_summer"][timing], net_energy_demand)
            end
        else
            if !(timing in keys(train_data["week_day_winter"]))
                train_data["week_day_winter"][timing] = [net_energy_demand]
            else
                push!(train_data["week_day_winter"][timing], net_energy_demand)
            end
        end

    end

    output = Dict("week_end_summer"=>DataFrame(), "week_end_winter"=>DataFrame(),
        "week_day_summer"=>DataFrame(), "week_day_winter"=>DataFrame())

    for (key, value) in train_data

        df = DataFrame(timestamp=Dates.Time[], noise=Array{Float64,1}[],
            probability=Array{Float64,1}[])

        for timestamp in Dates.Time(0, 0, 0):Dates.Minute(15):Dates.Time(23, 45, 0)

            energy_demand = reshape(value[timestamp], (1, :))
            n_data = length(energy_demand)
            k_means = kmeans(energy_demand, k)
            noise = reshape(k_means.centers, :)
            probability = reshape(k_means.counts, :) / n_data
            push!(df, [timestamp, noise, probability])

        end

        output[key] = df

    end

   return output

end

function update_period!(period::Period, sdp::SDP, train_data::Dict{String, DataFrame})

    sdp.cost_parameters["buy_price"] =  Array(period.data[:price_buy_00])
    sdp.cost_parameters["sell_price"] = Array(period.data[:price_sell_00])

    horizon = size(period.data, 1)
    noise = Float64[]
    probability = Float64[]

    for timestamp in period.data[:timestamp]

        day, timing = split(timestamp, " ")
        date = Dates.DateTime(day*"T"*timing)
        day = Dates.Date(date)
        timing = Dates.Time(timing)

        if is_summer(day)
            season = "summer"
        else
            season = "winter"
        end
        if is_week_end(day)
            weekday = "week_end"
        else
            weekday = "week_day"
        end

        df = train_data[weekday*"_"*season]
        df = df[df.timestamp .== timing, :]

        push!(noise, df[1, :noise]...)
        push!(probability, df[1, :probability]...)

    end

    noise = collect(reshape(noise, :, horizon)')
    probability = collect(reshape(probability, :, horizon)')
    sdp.noises = Noise(noise, probability)

end

function update_battery!(sdp::SDP, battery::Battery)

    sdp.cost_parameters["pmax"] = battery.power
    sdp.dynamics_parameters["charge_efficiency"] = battery.charge_efficiency
    sdp.dynamics_parameters["discharge_efficiency"] = battery.discharge_efficiency
    sdp.dynamics_parameters["pmax"] = battery.power
    sdp.dynamics_parameters["cmax"] = battery.capacity

end