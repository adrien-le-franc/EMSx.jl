# developed with Julia 1.3.0
#
# functions to download the data from Schneider's database 


const SCHNEIDER_API = "https://data.exchange.se.com/explore/"
const DATASET = "dataset/microgrid-energy-management-benchmark-time-series"

function download_site_csv_from_schneider(siteid::Int, 
                           path_to_data_folder::String, 
                           compressed::Bool = true; 
                           periods::Union{Nothing, AbstractArray{Int}} = nothing,
                           progress = true, # true/false or Progress or ParallelProgress
                           api_key = get(ENV, "SCHNEIDER_API_KEY", nothing))

    if progress == true
        file_size = get_file_size(siteid)
        progress = Progress(file_size; desc = "Downloading $siteid.csv.gz ")
    elseif progress == false
        file_size = nothing
        progress = nothing
    end

    isnothing(api_key) && error("""you did not provide your api key
        please set it with the keyword `api_key`
        or with the ENV veriable: `ENV["SCHNEIDER_API_KEY"] = *your api key*`""")
    
    headers = Dict("Authorization" => "Apikey "*api_key)
    
    if compressed
        headers["Accept-Encoding"] = "gzip"
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
