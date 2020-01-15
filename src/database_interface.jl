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
                             files_range::UnitRange{Int} = 1:24)
    files_number = length(files_range)
    base_url = "https://data.exchange.se.com/api/datasets/1.0/
                microgrid-energy-management-benchmark-time-series/
                alternative_exports/memb_ts_part_"
    payload = ""
    headers = Dict("Authorization" => "Apikey "*apikey)
    files_sizes = [223_307_074, 160_151_765, 178_683_342, 239_746_014, 
                   194_319_624, 229_800_343, 225_999_196, 205_952_190, 
                   227_255_093, 188_492_377, 175_456_044, 223_456_964, 
                   212_553_744, 194_117_872, 183_992_889, 230_422_835, 
                   243_373_871, 180_393_452, 163_495_560, 176_314_186, 
                   167_929_157, 183_420_654, 178_688_199, 90_261_417]

    for (fileindex, filenumber) in enumerate(files_range)
        filepath = joinpath(path_to_data_folder, string(filenumber)*".zip")
        download_stream = open(filepath, "w")
        download_task = @async HTTP.get(base_url*string(filenumber)*"_zip/", 
                                        data=payload, 
                                        headers=headers, 
                                        response_stream = download_stream)
        progress_meter = Progress(files_sizes[filenumber], 
                                  "Downloading file $fileindex / $files_number")
        while download_task.state != :done
            update!(progress_meter, filesize(filepath))
        end
        close(download_stream)
        
        (download_task.state == :failed) && error(download_task.result)

        download_succeded = (download_task.result.status == 200) && 
                            (filesize(filepath) == files_sizes[n])
        @assert download_succeded "File $n download failed, you should download 
                                    this file again" 
    end

    return
end

function initialize_data(path_to_data_folder::String, 
                         path_to_test_periods_csv::String)
    println()
    println("Splitting train and test datasets")
    make_directory(joinpath(path_to_data_folder, "test"))
    make_directory(joinpath(path_to_data_folder, "train"))
    zipfiles = readdir(path_to_data_folder)
    csv_folder = ""
    csv_files = String[]
    @showprogress for zipfile in zipfiles
        unpack(joinpath(path_to_data_folder, zipfile))
        for (root, dirs, files) in walkdir(path_to_data_folder)
            if root ∉ joinpath.(path_to_data_folder, ["test", "train"]) ∪ [path_to_data_folder]
                csv_files = files
                csv_folder = root
                break
            end
        end
        train_test_split.(csv_folder, csv_files, path_to_data_folder, path_to_test_periods_csv)
        rm(csv_folder, recursive = true)
    end
end

function train_test_split(site_folder::String, 
                          site_file::String, 
                          path_to_data_folder::String, 
                          path_to_test_periods_csv::String)

    test_periods = CSV.read(path_to_test_periods_csv)
    site_id = parse(Int, match(r"(.*)\.csv", site_file).captures[1])

    data = CSV.read(joinpath(site_folder, site_file), copycols=true)
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