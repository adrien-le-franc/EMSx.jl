# developed with Julia 1.3.0
#
# functions to split data into train and test periods for the EMSx challenge


make_directory(path::String) = isdir(path) || mkpath(path)

function gzpack(file::String)
    if Sys.isunix()
        run(`gzip $(file)`)
    end
    if Sys.iswindows()
        run(`7z a $(file).gz $(file) -bso0 -bsp0`) # only shows errors
    end
end

function read_site_file(file::String; kw...)
    f = open(file)
    csv = CSV.read(GzipDecompressorStream(f); kw...)
    close(f)
    return csv
end

function initialize_data(path_to_data_folder::String,
                         path_to_test_periods_csv::String = joinpath(DIR, 
                                                                     "metadata", 
                                                                     "test_periods.csv");
                         delete_files::Bool = true)
    println()
    println("Splitting train and test datasets")
    make_directory(joinpath(path_to_data_folder, "test"))
    make_directory(joinpath(path_to_data_folder, "train"))
    ls = readdir(path_to_data_folder)
    full_site_files = ls[findall(f -> !isnothing(match(r"(.*)\.csv.gz", f)), ls)]
    @showprogress for full_site_file in full_site_files
        train_test_split(full_site_file, 
                         path_to_data_folder, 
                         path_to_test_periods_csv)
        delete_files && rm(joinpath(path_to_data_folder, full_site_file))
    end
end

function initialize_data_parallel(path_to_data_folder::String,
                                  path_to_test_periods_csv::String = 
                                      joinpath(DIR, "metadata", "test_periods.csv");
                                  delete_files::Bool = true,
                                  progress::Bool = true)
    println()
    make_directory(joinpath(path_to_data_folder, "test"))
    make_directory(joinpath(path_to_data_folder, "train"))
    ls = readdir(path_to_data_folder)
    full_site_files = ls[findall(f -> !isnothing(match(r"(.*)\.csv.gz", f)), ls)]

    if progress
        prog = ParallelProgress(length(full_site_files); 
                                desc = "Splitting train and test datasets ")
        update!(prog, 0)
    end

    pmap(full_site_files) do full_site_file 
        train_test_split(full_site_file, 
                         path_to_data_folder, 
                         path_to_test_periods_csv)
        delete_files && rm(joinpath(path_to_data_folder, full_site_file))
        progress && next!(prog)
    end
    return
end

function train_test_split(site_file::String, 
                          path_to_data_folder::String,
                          path_to_test_periods_csv::String)
    
    
    test_periods = CSV.read(path_to_test_periods_csv)
    date_format = dateformat"y-m-dTH:M:S+z"
    site_id = parse(Int, match(r"(.*)\.csv.gz", site_file).captures[1])

    data = read_site_file(joinpath(path_to_data_folder, site_file), 
                          copycols = true)
    
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

    test_file = joinpath(path_to_data_folder, "test", "$(site_id).csv")
    CSV.write(test_file, test_data)
    gzpack(test_file)
    
    train_file = joinpath(path_to_data_folder, "train", "$(site_id).csv")
    train_data = data[(!).(in(periods).(data.period_id)), :]
    CSV.write(train_file, train_data)
    gzpack(train_file)

    return nothing

end
