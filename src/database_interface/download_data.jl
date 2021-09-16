# functions to download the data

const SIZE_DIVIDER = 100_000
const FILESIZES = CSV.read(joinpath(DIR,"metadata","filesizes.csv"), DataFrame)

# _download is a modified MIT expat licensed code from HTTP.jl
# https://github.com/JuliaWeb/HTTP.jl/blob/668e7e68747bb333ebde13af8d16add5b82b3b8a/src/download.jl#L92

function _download(url::AbstractString, 
                   file_path::AbstractString; 
                   headers = [], 
                   progress = nothing, # nothing or Progress or ParallelProgress
                   filesize = typemax(Int),
                   update_period = 1,
                   kw...)

    if isnothing(progress)
        update_period = Inf
    end

    HTTP.open("GET", url, headers; kw...) do stream
        eof(stream) && return  # don't do anything for streams we can't read (yet)
        
        downloaded_bytes = 0
        prev_time = Dates.now()

        function report_callback()
            prev_time = Dates.now()
            completion_progress = floor(Int, downloaded_bytes / SIZE_DIVIDER)
            # we stay stuck at 99% if file is bigger than expected
            update!(progress, min(completion_progress, filesize-1))
        end

        Base.open(file_path, "w") do fh
            while !eof(stream)
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

function get_file_size(siteid::Integer, compressed::Bool)
    col = compressed ? ".csv.gz" : ".csv"
    return ceil(Int, FILESIZES[siteid, col]/SIZE_DIVIDER)
end

function download_site_csv(source, siteid, path_to_data_folder; kw...)
    if source === :zenodo
        return download_site_csv_from_zenodo(siteid, path_to_data_folder; kw...)
    elseif source === :schneider
        return download_site_csv_from_schneider(siteid, path_to_data_folder; kw...)
    else
        error("Source $(repr(source)) not found")
    end
end

function download_sites_data(path_to_data_folder, 
                             sitesid = 1:70; 
                             source = :zenodo,
                             kw...)
    for siteid in sitesid
        download_site_csv(source, siteid, path_to_data_folder; kw...)
    end
    return
end

function download_sites_data_parallel(path_to_data_folder, 
                                      sitesid = 1:70; 
                                      progress = true,
                                      max_threads = 4,
                                      compressed = true,
                                      source = :zenodo,
                                      kw...)
    
    file_sizes = get_file_size.(sitesid, compressed)
    
    if progress
        ext = compressed ? ".csv.gz" : ".csv"
        mprog = MultipleProgress(length(sitesid), file_sizes;
                                 kws = [(:desc => "Downloading $j$ext ",) for j in sitesid],
                                 desc = "Downloading files... ",
                                 dt = 0.1)
    end

    i = firstindex(sitesid) - 1
    @sync for p in 1:max_threads
        @async while true
            idx = (i += 1)
            idx > lastindex(sitesid) && break
            download_site_csv(source, sitesid[idx], path_to_data_folder; 
                              progress = progress ? mprog[idx] : false, 
                              compressed = compressed,
                              file_size = file_sizes[idx],
                              kw...)
        end
    end
    progress && finish!(mprog)
    return
end
