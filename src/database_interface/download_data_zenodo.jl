# functions to download the data from Schneider's database 

const ZENODO_API = "https://zenodo.org/record/"
const ZENODO_ID = "5510400"
const ZENODO_CONCEPT_ID = "5510399"

function download_site_csv_from_zenodo(siteid::Int, 
                           path_to_data_folder::String;
                           compressed::Bool = true,
                           periods::Union{Nothing, AbstractArray{Int}} = nothing,
                           progress = true, # true/false or Progress or ParallelProgress
                           api_key = get(ENV, "ZENODO_API_KEY", nothing),
                           zenodo_id = ZENODO_ID)

    if progress == true
        file_size = get_file_size(siteid, true)
        progress = Progress(file_size; desc = "Downloading $siteid.csv.gz ")
    elseif progress == false
        file_size = nothing
        progress = nothing
    end

    headers = Dict("Accept-Encoding" => "gzip")

    if !isnothing(api_key)
        headers["Authorization"] = "Bearer "*api_key
    end

    url = ZENODO_API*zenodo_id*"/files/$(siteid).csv.gz?download=1"

    if !isnothing(periods)
        @info "`periods` not supported for Zenodo, full data will be downloaded"
    end
    
    file_extension = ".csv.gz"
    _download(url, 
              joinpath(path_to_data_folder, "$(siteid)"*file_extension); 
              headers=headers, 
              file_size=file_size, 
              progress=progress, 
              )
end

function get_latest_zenodo_id(concept_id = ZENODO_CONCEPT_ID)
    res = HTTP.get("https://zenodo.org/api/records?q=conceptrecid:\"$(concept_id)\"")
    d = JSON.parse(String(res.body))
    hits = d["hits"]["hits"]
    length(hits) == 0 && error("Concept id $(concept_id) not found")
    return hits[1]["id"]
end
