# developed with Julia 1.1.1
#
# models and functions for simulation with EMSx


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

is_week_end(date::Dates.Date) = Dates.dayofweek(date) in [6, 7]
is_summer(date::Dates.Date) = Dates.month(date) in [5, 6, 7, 8, 9]

# plain Dynamic Programming

function load_train_data!(model::DynamicProgrammingModel, site::Site, paths::Paths; k=10)

    data_frame = load_data(site.id, paths.train_data)
    sorted_data = parse_data_frame(model, data_frame)
    noise_data_frames = data_to_noises(model, sorted_data, k)

    return noise_data_frames
    
end

function parse_data_frame(model::DynamicProgrammingModel, data::DataFrame)

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

    return train_data

end

function data_to_noises(model::DynamicProgrammingModel, data::Dict{String,Dict{Any,Any}}, 
    k::Int64)

    noise_data = Dict("week_end_summer"=>DataFrame(), "week_end_winter"=>DataFrame(),
        "week_day_summer"=>DataFrame(), "week_day_winter"=>DataFrame())

    for (key, value) in data

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

        noise_data[key] = df

    end

   return noise_data

end

function train_noises_of_period!(model::DynamicProgrammingModel, period::Period, 
    train_noises::Dict{String, DataFrame})

    horizon = size(period.data, 1)
    noises = Float64[]
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

        df = train_noises[weekday*"_"*season]
        df = df[df.timestamp .== timing, :]

        push!(noises, df[1, :noise]...)
        push!(probability, df[1, :probability]...)

    end

    noises = collect(reshape(noises, :, horizon)')
    probability = collect(reshape(probability, :, horizon)')
    return  Noises(noises, probability)

end


# Dynamic Programming with AR model


function load_train_data!(model::SdpAR, site::Site, paths::Paths)

    data_frame = load_data(site.id, paths.train_data)
    data_frame = normalize!(model, data_frame)

    sorted_data = parse_data_frame(model, data_frame)
    noise_data_frames = fit_dynamics_and_noise!(model, sorted_data, model.noise_points)

    return noise_data_frames
    
end

function parse_data_frame(model::SdpAR, data::DataFrame)

    train_data = Dict("week_end_summer"=>Dict(), "week_end_winter"=>Dict(),
        "week_day_summer"=>Dict(), "week_day_winter"=>Dict())

    for df in eachrow(data)

        timestamp = df[:timestamp]
        day, timing = split(timestamp, " ")

        date = Dates.DateTime(day*"T"*timing) - Dates.Minute(15)
        day = Dates.Date(date)
        timing = Dates.Time(timing)

        noise = df[:noise]

        noise_lags = Float64[]

        for l in 1:model.lags

            lag_stamp = Dates.DateTime(string(day)*"T"*string(timing)) - Dates.Minute(15*(l+1))
            lag_stamp = string(Date(lag_stamp))*" "*string(Time(lag_stamp))

            if lag_stamp in data[:timestamp]
                lag_df = data[data.timestamp .== lag_stamp, :]
                push!(noise_lags, lag_df[:noise][1])
            else break
            end

        end

        if length(noise_lags) != model.lags
            continue
        end

        if is_week_end(day) && is_summer(day)
            if !(timing in keys(train_data["week_end_summer"]))
                train_data["week_end_summer"][timing] = Dict("target"=>[noise], "data"=>noise_lags)
            else
                push!(train_data["week_end_summer"][timing]["target"], noise)
                append!(train_data["week_end_summer"][timing]["data"], noise_lags)
            end
        elseif is_week_end(day)
            if !(timing in keys(train_data["week_end_winter"]))
                train_data["week_end_winter"][timing] = Dict("target"=>[noise], "data"=>noise_lags)
            else
                push!(train_data["week_end_winter"][timing]["target"], noise)
                append!(train_data["week_end_winter"][timing]["data"], noise_lags)
            end
        elseif !is_week_end(day) && is_summer(day)
            if !(timing in keys(train_data["week_day_summer"]))
                train_data["week_day_summer"][timing] = Dict("target"=>[noise], "data"=>noise_lags)
            else
                push!(train_data["week_day_summer"][timing]["target"], noise)
                append!(train_data["week_day_summer"][timing]["data"], noise_lags)
            end
        else
            if !(timing in keys(train_data["week_day_winter"]))
                train_data["week_day_winter"][timing] = Dict("target"=>[noise], "data"=>noise_lags)
            else
                push!(train_data["week_day_winter"][timing]["target"], noise)
                append!(train_data["week_day_winter"][timing]["data"], noise_lags)
            end
        end

    end

    return train_data

end


function fit_dynamics_and_noise!(model::SdpAR, sorted_data::Dict{String,Dict{Any,Any}}, k::Int64)

    parameters = Dict("week_end_summer"=>DataFrame(), "week_end_winter"=>DataFrame(),
        "week_day_summer"=>DataFrame(), "week_day_winter"=>DataFrame())
    noise_data = Dict("week_end_summer"=>DataFrame(), "week_end_winter"=>DataFrame(),
        "week_day_summer"=>DataFrame(), "week_day_winter"=>DataFrame())

    for key in keys(parameters)

        df_ar = DataFrame(timestamp=Dates.Time[], weights=Array{Float64,1}[])
        df_noise = DataFrame(timestamp=Dates.Time[], noise=Array{Float64,1}[],
            probability=Array{Float64,1}[])

        for timestamp in Dates.Time(0, 0, 0):Dates.Minute(15):Dates.Time(23, 45, 0)

            data = sorted_data[key][timestamp]
            x = collect(reshape(data["data"], model.lags, :)')
            y = data["target"]

            weights = fit_autoregressive_model(x, y, model.lags)
            push!(df_ar, [timestamp, weights])

            predict = hcat(x, ones(size(y)))*weights
            errors = reshape(y - predict, (1, :))            
            n_data = length(errors)
            k_means = kmeans(errors, k)
            noise = reshape(k_means.centers, :)
            probability = reshape(k_means.counts, :) / n_data
            push!(df_noise, [timestamp, noise, probability])

        end

        parameters[key] = df_ar
        noise_data[key] = df_noise

    end

    model.dynamics_parameters["ar"] = parameters
    return noise_data

end

function normalize!(model::SdpAR, data::DataFrame)

    df = data[:, [:timestamp]]
    net_energy_demand = (data[:actual_consumption] - data[:actual_pv]) / 1000
    upper_bound = maximum(net_energy_demand)
    lower_bound = minimum(net_energy_demand)
    df[:noise] = (net_energy_demand .- lower_bound) / (upper_bound - lower_bound)

    model.dynamics_parameters["noise_upper_bound"] = upper_bound
    model.dynamics_parameters["noise_lower_bound"] = lower_bound

    return df
end

function fit_autoregressive_model(data::Array{Float64,2}, target::Array{Float64,1}, lags::Int64)

    n_data, n_lags = size(data)
    data = hcat(data, ones(n_data, 1))
    weights = pinv(data'*data)*data'*target

    return weights
end

function train_noises_of_period!(model::SdpAR, period::Period, 
    train_noises::Dict{String, DataFrame})

    horizon = size(period.data, 1)
    noises = Float64[]
    probability = Float64[]

    weights = Float64[]

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

        df = train_noises[weekday*"_"*season]
        df = df[df.timestamp .== timing, :]

        push!(noises, df[1, :noise]...)
        push!(probability, df[1, :probability]...)

        df = model.dynamics_parameters["ar"][weekday*"_"*season]
        df = df[df.timestamp .== timing, :]

        push!(weights, df[1, :weights]...)

    end

    noises = collect(reshape(noises, :, horizon)')
    probability = collect(reshape(probability, :, horizon)')
    weights = collect(reshape(weights, model.lags+1, horizon)')
    model.dynamics_parameters["ar_period_weights"] = weights

    return  Noises(noises, probability)

end