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

function load_train_data(model::DynamicProgrammingModel, site::Site, paths::Paths; k=10)

    data_frame = load_data(site.id, paths.train_data)
    sorted_data = parse_data_frame(model, data_frame)
    noise_data_frames = data_to_noise(model, sorted_data, k)

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

function data_to_noise(model::DynamicProgrammingModel, data::Dict{String,Dict{Any,Any}}, 
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

function train_noise_of_period(model::DynamicProgrammingModel, period::Period, 
    train_noise::Dict{String, DataFrame})

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

        df = train_noise[weekday*"_"*season]
        df = df[df.timestamp .== timing, :]

        push!(noise, df[1, :noise]...)
        push!(probability, df[1, :probability]...)

    end

    noise = collect(reshape(noise, :, horizon)')
    probability = collect(reshape(probability, :, horizon)')
    return  Noise(noise, probability)

end


