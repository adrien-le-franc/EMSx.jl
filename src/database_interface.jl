# developed with Julia 1.1.1
#
# functions to prepare and access the sites database
const SCHNEIDER_API = "https://data.exchange.se.com/explore/"
const DATASET = "dataset/microgrid-energy-management-benchmark-time-series"

# modified MIT expat licensed code from HTTP.jl
# https://github.com/JuliaWeb/HTTP.jl/blob/668e7e68747bb333ebde13af8d16add5b82b3b8a/src/download.jl#L92
function _download(url::AbstractString, 
                   file_path::AbstractString; 
                   headers=Header[], 
                   file_size=nothing, 
                   update_period=1, 
                   kw...)
    format_progress(x) = round(x, digits=4)
    format_bytes(x) = !isfinite(x) ? "∞ B" : Base.format_bytes(x)
    format_seconds(x) = "$(round(x; digits=2)) s"
    format_bytes_per_second(x) = format_bytes(x) * "/s"

    file_name = split(file_path, '/')[end] 

    local file
    HTTP.open("GET", url, headers; kw...) do stream
        resp = startread(stream)
        eof(stream) && return  # don't do anything for streams we can't read (yet)
        
        file = file_path
        total_bytes = parse(Float64, HTTP.header(resp, "Content-Length", "NaN"))
        if !isnothing(file_size)
            total_bytes = file_size
        end
        downloaded_bytes = 0
        start_time = Dates.now()
        prev_time = Dates.now()

        p = Progress(floor(Int,total_bytes), update_period, "Downloading file "*file_name)
        
        function report_callback()
            prev_time = Dates.now()
            taken_time = (prev_time - start_time).value / 1000 # in seconds
            average_speed = downloaded_bytes / taken_time
            remaining_bytes = total_bytes - downloaded_bytes
            remaining_time = remaining_bytes / average_speed
            completion_progress = floor(Int,downloaded_bytes)
        
            update!(p, completion_progress)
        end

        Base.open(file, "w") do fh
            while(!eof(stream))
                downloaded_bytes += write(fh, readavailable(stream))
                if !isinf(update_period)
                    if Dates.now() - prev_time > Dates.Millisecond(round(1000update_period))
                        report_callback()
                    end
                end
            end
        end
        if !isinf(update_period)
            report_callback()
        end
    end
    return
end

function download_site_csv(siteid::Int, 
                           path_to_data_folder::String, 
                           compressed::Bool = true)
    sizes_jld_file = joinpath(@__DIR__, "..", "metadata", "sitefilesizes.jld")
    file_size = load(sizes_jld_file)["$(siteid).csv.gz"]
    @assert haskey(ENV, "SCHNEIDER_API_KEY") "you did not provide your api key"* 
            "please set it with: ENV[\"SCHNEIDER_API_KEY\"] = *your api key*"
    
    headers = Dict("Authorization" => "Apikey "*ENV["SCHNEIDER_API_KEY"])
    
    if compressed
        headers["Accept-Encoding"]="gzip"
    end

    url = SCHNEIDER_API*DATASET*"/download/?format=csv&refine.site_id=$(siteid)"*
          "&use_labels_for_header=true&csv_separator=%3B"
    file_extension = compressed ? ".csv.gz" : ".csv"
    _download(url, joinpath(path_to_data_folder, "$(siteid)"*file_extension); 
              headers=headers, file_size=file_size)
end

function download_sites_data(path_to_data_folder::String, 
                             sitesid::UnitRange{Int} = 1:70)
    @assert (maximum(sitesid) <= 70) && (minimum(sitesid) >= 1)
    download_site_csv.(sitesid, path_to_data_folder)
    return
end

make_directory(path::String) = if !isdir(path) mkpath(path) end

function gzpack(file::String)
    if Sys.isunix()
        run(`gzip $(file)`)
    end
    if Sys.iswindows()
        run(`$exe7z x $(file) $(file).gz`)
    end
end

function initialize_data(path_to_data_folder::String)
    println()
    println("Splitting train and test datasets")
    make_directory(joinpath(path_to_data_folder, "test"))
    make_directory(joinpath(path_to_data_folder, "train"))
    ls = readdir(path_to_data_folder)
    full_site_files = ls[findall(f -> !isnothing(match(r"(.*)\.csv.gz", f)), ls)]
    @showprogress for full_site_file in full_site_files
        train_test_split(full_site_file, path_to_data_folder)
        rm(full_site_file)
    end
end

function train_test_split(site_file::String, 
                          path_to_data_folder::String)
    
    path_to_test_periods_csv = joinpath(@__DIR__,
                                        "..", 
                                        "metadata", 
                                        "test_periods.csv")
    test_periods = CSV.read(path_to_test_periods_csv)
    date_format = dateformat"y-m-dTH:M:S+z"
    site_id = parse(Int, match(r"(.*)\.csv.gz", site_file).captures[1])

    compressed_data = open(joinpath(path_to_data_folder, site_file))
    data = CSV.read(GzipDecompressorStream(compressed_data), 
                    delim=';', 
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

function load_sites(path_to_metadata_csv::String, 
                    path_to_test_data_folder::Union{String, Nothing},
                    path_to_train_data_folder::Union{String, Nothing}, 
                    path_to_save_folder::String)

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

function load_sites(path_to_data_folder::String)
    path_to_metadata_csv = joinpath(@__DIR__, "..", "metadata")
    path_to_test_data_folder = joinpath(path_to_data_folder, "test")
    path_to_train_data_folder = joinpath(path_to_data_folder, "train")
    path_to_save_folder = joinpath(path_to_data_folder, "save")
    return load_sites(path_to_metadata_csv, path_to_test_data_folder,
                      path_to_train_data_folder, path_to_save_folder)
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

function load_site_test_data(site::Site)
    compressed_data = open(site.path_to_test_data_csv)
    test_data = CSV.read(GzipDecompressorStream(compressed_data), 
                    delim=';', 
                    copycols = true)
    site_hidden_test_data = Site(site.id, 
                                 site.battery, 
                                 nothing, 
                                 site.path_to_train_data_csv, 
                                 site.path_to_save_folder)
    return test_data, site_hidden_test_data
end

load_site_data(site::Site) = load_site_test_data(site) # too avoid code breaks


function load_site_train_data(site::Site)
    compressed_data = open(site.path_to_train_data_csv)
    data = CSV.read(GzipDecompressorStream(compressed_data), 
                    delim=';', 
                    copycols = true)
    site_hidden_train_data = Site(site.id, 
                                 site.battery, 
                                 site.path_to_test_data_csv, 
                                 nothing, 
                                 site.path_to_save_folder)
    return data, site_hidden_train_data
end