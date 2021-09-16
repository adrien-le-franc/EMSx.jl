# developed with Julia 1.3.0
#
# functions to download the data from Schneider's database 


const SCHNEIDER_API = "https://data.exchange.se.com/explore/"
const DATASET = "dataset/microgrid-energy-management-benchmark-time-series"
const SIZE_DIVIDER = 100_000

# _download is a modified MIT expat licensed code from HTTP.jl
# https://github.com/JuliaWeb/HTTP.jl/blob/668e7e68747bb333ebde13af8d16add5b82b3b8a/src/download.jl#L92

function _download(url::AbstractString, 
                   file_path::AbstractString; 
                   headers = Header[], 
                   file_size = nothing, 
                   update_period = 1, 
                   progress = nothing, # nothing or Progress or ParallelProgress
                   kw...)

    file_name = basename(file_path) 
    if isnothing(file_size) || isnothing(progress)
        update_period = Inf
    end

    local file
    HTTP.open("GET", url, headers; kw...) do stream
        resp = startread(stream)
        eof(stream) && return  # don't do anything for streams we can't read (yet)
        
        file = file_path

        downloaded_bytes = 0
        start_time = Dates.now()
        prev_time = Dates.now()

        function report_callback()
            prev_time = Dates.now()
            completion_progress = floor(Int, downloaded_bytes / SIZE_DIVIDER)
            update!(progress, completion_progress)
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
            finish!(progress)
        end
    end
    return
end

function get_file_size(sitesid::AbstractVector{<:Integer})
    sizes_jld_file = joinpath(DIR, "metadata", "site_file_sizes.jld2")
    round.(Int, getindex.([load(sizes_jld_file)], string.(sitesid) .* ".csv.gz") ./ SIZE_DIVIDER, RoundUp)
end

function get_file_size(siteid::Integer)
    sizes_jld_file = joinpath(DIR, "metadata", "site_file_sizes.jld2")
    round(Int, load(sizes_jld_file)["$(siteid).csv.gz"]/SIZE_DIVIDER, RoundUp)
end

function download_site_csv(siteid::Int, 
                           path_to_data_folder::String, 
                           compressed::Bool = true; 
                           periods::Union{Nothing, AbstractArray{Int}} = nothing,
                           progress = true, # true/false or Progress or ParallelProgress
                           file_size = nothing)

    if progress == true
        file_size = get_file_size(siteid)
        progress = Progress(file_size; desc = "Downloading $siteid.csv.gz ")
    elseif progress == false
        file_size = nothing
        progress = nothing
    end

    @assert haskey(ENV, "SCHNEIDER_API_KEY") "you did not provide your api key"* 
            " please set it with: ENV[\"SCHNEIDER_API_KEY\"] = *your api key*"
    
    headers = Dict("Authorization" => "Apikey "*ENV["SCHNEIDER_API_KEY"])
    
    if compressed
        headers["Accept-Encoding"]="gzip"
    end

    url = SCHNEIDER_API*DATASET*"/download/?format=csv&refine.site_id=$(siteid)"

    if !isnothing(periods)
        for p in periods
            url *= "&refine.period_id=$p"
        end
        url *= "&disjunctive.period_id=true"
    end

    url *= "&use_labels_for_header=true&csv_separator=%3B"
    
    file_extension = compressed ? ".csv.gz" : ".csv"
    _download(url, 
              joinpath(path_to_data_folder, "$(siteid)"*file_extension); 
              headers=headers, 
              file_size=file_size, 
              progress=progress, 
              )
end

function download_sites_data(path_to_data_folder::String, 
                             sitesid::UnitRange{Int} = 1:70; 
                             kw...)
    @assert (maximum(sitesid) <= 70) && (minimum(sitesid) >= 1)
    for siteid in sitesid
        download_site_csv(siteid, path_to_data_folder; kw...)
    end
    return
end

function download_sites_data_parallel(path_to_data_folder::String, 
                                      sitesid::AbstractVector{<:Integer} = 1:70; 
                                      progress = true,
                                      max_threads::Int = 4,
                                      kw...)
    @assert (maximum(sitesid) <= 70) && (minimum(sitesid) >= 1)
    
    file_sizes = get_file_size(sitesid)
    if progress 
        mprog = MultipleProgress(length(sitesid), file_sizes;
                                 kws = [(:desc => "Downloading $j.csv.gz ",) for j in sitesid],
                                 desc = "Downloading files... ",
                                 dt = 0.1)
    end

    i = firstindex(sitesid) - 1
    @sync for p in 1:max_threads
        @async while true
            idx = (i += 1)
            idx > lastindex(sitesid) && break
            download_site_csv(sitesid[idx], path_to_data_folder; 
                              progress = progress ? mprog[idx] : false, 
                              file_size = file_sizes[idx],
                              kw...)
        end
    end
    progress && finish!(mprog)
    return
end