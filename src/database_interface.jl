# developed with Julia 1.1.1
#
# functions to prepare and access the sites database

make_directory(path::String) = if !isdir(path) mkpath(path) end

function gzpack(file::String)
    if Sys.isunix()
        run(`gzip $(file)`)
    end
    if Sys.iswindows()
        run(`$exe7z x $(file) $(file).gz`)
    end
end

function download_sites_data(apikey::String, 
                             path_to_data_folder::String, 
                             sites_range::UnitRange{Int} = 1:70)
    files_number = length(sites_range)
    req_url(siteid::Int) = "https://data.exchange.se.com/explore/dataset/microgrid-energy-management-benchmark-time-series/download/?format=csv&refine.site_id=$(siteid)&use_labels_for_header=true&csv_separator=%3B"

    payload = ""
    headers = headers = Dict("Authorization" => "Apikey "*apikey, 
                             "Accept-Encoding" => "gzip")

    @showprogress for (fileindex, site_id) in enumerate(sites_range)
        filepath = joinpath(path_to_data_folder, string(site_id)*".csv.gz")
        download_stream = open(filepath, "w")
        download_task = HTTP.get(req_url(site_id), 
                                 data=payload, 
                                 headers=headers, 
                                 response_stream = download_stream)
        close(download_stream)

        download_succeded = (download_task.status == 200)
        @assert download_succeded "Site $site_id data download failed, 
                                    you should download this site again" 
    end

    return
end

function initialize_data(path_to_data_folder::String, 
                         path_to_test_periods_csv::String)
    println()
    println("Splitting train and test datasets")
    make_directory(joinpath(path_to_data_folder, "test"))
    make_directory(joinpath(path_to_data_folder, "train"))
    ls = readdir(path_to_data_folder)
    full_site_files = ls[findall(f -> !isnothing(match(r"(.*)\.csv.gz", f)), ls)]
    @showprogress for full_site_file in full_site_files
        train_test_split(full_site_file, path_to_data_folder, path_to_test_periods_csv)
        rm(full_site_file)
    end
end

function train_test_split(site_file::String, 
                          path_to_data_folder::String, 
                          path_to_test_periods_csv::String)
    date_format = dateformat"y-m-dTH:M:S+z"
    test_periods = CSV.read(path_to_test_periods_csv)
    site_id = parse(Int, match(r"(.*)\.csv.gz", site_file).captures[1])
    data = CSV.read(GzipDecompressorStream(open(joinpath(path_to_data_folder, site_file))), delim=';', copycols = true)
    data.timestamp = DateTime.(data.timestamp, date_format)
    sort!(data, :timestamp)
    periods = test_periods[test_periods.site_id .== site_id, :test_periods][1]
    periods = [parse(Int, id) for id in split(periods[2:end-1], ",")]
    test_data = DataFrame()

    for period in periods
        df = data[data.period_id .== period, :]
        timestamp = df[1, :timestamp]
        history_span = timestamp-Dates.Day(1):Dates.Minute(15):timestamp-Dates.Minute(15)
        history = data[in(history_span).(data.timestamp), :]
        history[!, :period_id] = period*ones(Int, 96)
        new_period = vcat(history, df)
        test_data = vcat(test_data, new_period)
    end

    test_file = joinpath(path_to_data_folder, "test", site_file)
    CSV.write(test_file, test_data)
    gzpack(test_file)
    
    train_file = joinpath(path_to_data_folder, "train", site_file)
    train_data = data[(!).(in(periods).(data.period_id)), :]
    CSV.write(train_file, train_data)
    gzpack(train_file)

    return nothing

end

function load_sites(path_to_metadata_csv::String, path_to_test_data_folder::Union{String, Nothing},
    path_to_train_data_folder::Union{String, Nothing}, path_to_save_folder::String)

    sites = Site[]
    metadata = CSV.read(path_to_metadata_csv)
    number_of_sites = size(metadata, 1)

    for row in 1:number_of_sites
        site = Site(metadata, row, path_to_test_data_folder, 
            path_to_train_data_folder, path_to_save_folder)
        push!(sites, site)
    end

    return sites

end

function load_prices_csv(path_to_csv::String)

    prices = CSV.read(path_to_csv)

    if !(names(prices) == [:timestamp, :buy, :sell] && size(prices, 1) == 672)
        error("price DataFrame at $(path_to_csv) is not in expected shape")
    end

    if !(all(isa.(prices[!, :timestamp], Dates.Time)))
        try prices[!, :timestamp] = Dates.Time.(prices[!, :timestamp])
        catch error
            println("could not convert timestamp to Dates.Time")
        end
    end

    return prices

end

function load_prices(path_to_prices::String)

    prices = Price[]

    if !isdir(path_to_prices)
        name = split(split(path_to_prices, "/")[end], ".")[1]
        data_frame = load_prices_csv(path_to_prices)
        push!(prices, Price(name, data_frame[!, :buy], data_frame[!, :sell]))
    else
        for file in readdir(path_to_prices)
            name = split(split(path_to_prices, "/")[end], ".")[1]
            data_frame = load_prices_csv(joinpath(path_to_prices, file))
            push!(prices, Price(name, data_frame[!, :buy], data_frame[!, :sell]))   
        end
    end

    return prices

end

function load_site_data(site::Site)
    test_data = CSV.read(site.path_to_test_data_csv)
    site_hidden_test_data = Site(site.id, site.battery, nothing, 
        site.path_to_train_data_csv, site.path_to_save_folder)
    return test_data, site_hidden_test_data
end