# functions to split data into train and test periods for the EMSx challenge


function write_site_file(filename, df; compressed=true)
    if compressed
        open(GzipCompressorStream, "$(filename).gz", "w") do stream
            CSV.write(stream, df)
        end
    else
        CSV.write("$(filename)", df)
    end
end

function read_site_file(file::String; kw...)
    return CSV.read(file, DataFrame)
end

function find_site_files(folder)
    files = readdir(folder)
    filter!(f -> occursin(r"^(\d+)\.csv(\.gz)?$",f), files)
    sort!(files)
    unique!(f -> match(r"(\d+)", f)[1], files) # since files is sorted, ".csv" will be chosen over ".csv.gz"
    return files
end

function initialize_data(path_to_data_folder::String,
                         path_to_test_periods_csv::String = 
                             joinpath(DIR, "metadata", "test_periods.csv");
                         delete_files::Bool = true,
                         progress::Bool = true,
                         compressed = true)
    println()
    println("Splitting train and test datasets")
    mkpath(joinpath(path_to_data_folder, "test"))
    mkpath(joinpath(path_to_data_folder, "train"))
    full_site_files = find_site_files(path_to_data_folder)

    @showprogress for full_site_file in full_site_files
        train_test_split(full_site_file, 
                         path_to_data_folder, 
                         path_to_test_periods_csv;
                         compressed = compressed)
        delete_files && rm(joinpath(path_to_data_folder, full_site_file))
    end
end

function initialize_data_parallel(path_to_data_folder::String,
                                  path_to_test_periods_csv::String = 
                                      joinpath(DIR, "metadata", "test_periods.csv");
                                  delete_files::Bool = true,
                                  progress::Bool = true,
                                  compressed = true)
    println()
    mkpath(joinpath(path_to_data_folder, "test"))
    mkpath(joinpath(path_to_data_folder, "train"))
    full_site_files = find_site_files(path_to_data_folder)

    if progress
        prog = ParallelProgress(length(full_site_files); 
                                desc = "Splitting train and test datasets ")
        update!(prog, 0)
    end

    pmap(full_site_files) do full_site_file 
        train_test_split(full_site_file, 
                         path_to_data_folder, 
                         path_to_test_periods_csv;
                         compressed = compressed)
        delete_files && rm(joinpath(path_to_data_folder, full_site_file))
        progress && next!(prog)
    end
    progress && finish!(prog)
    return
end

function train_test_split(site_file::String, 
                          path_to_data_folder::String,
                          path_to_test_periods_csv::String;
                          compressed = true)
    
    
    test_periods = CSV.read(path_to_test_periods_csv, DataFrame)
    date_format = dateformat"y-m-dTH:M:S+z"
    site_id = parse(Int, match(r"(\d+)", site_file)[1])

    data = read_site_file(joinpath(path_to_data_folder, site_file))
    
    data.timestamp = DateTime.(data.timestamp, date_format)
    sort!(data, :timestamp)
    
    periods = test_periods[test_periods.site_id .== site_id, :test_periods][1]
    periods = [parse(Int, id) for id in split(periods[2:end-1], ",")]
    test_data = DataFrame()

    for period in periods
        df = data[data.period_id .== period, :]
        timestamp = df[1, :timestamp]
        history_span = timestamp-Day(1):Minute(15):timestamp-Minute(15)
        history = data[data.timestamp .∈ Ref(history_span), :]
        history[!, :period_id] = fill(period, 96)
        new_period = vcat(history, df)
        test_data = vcat(test_data, new_period)
    end

    test_file = joinpath(path_to_data_folder, "test", "$(site_id).csv")
    write_site_file(test_file, test_data; compressed=compressed)
    
    train_file = joinpath(path_to_data_folder, "train", "$(site_id).csv")
    train_data = data[data.period_id .∉ Ref(periods), :]
    write_site_file(train_file, train_data; compressed=compressed)

    return nothing
end
