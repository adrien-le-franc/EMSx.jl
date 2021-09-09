# functions to download the data from Schneider's database 

#! TODO: use correct ids when available
@info "Incorrect Zenodo ID, please fix"
const ZENODO_API = "https://zenodo.org/record/"
const ZENODO_ID = "5458943"
const ZENODO_CONCEPT_ID = "3723281"

function download_site_csv_from_zenodo(siteid::Int, 
                           path_to_data_folder::String;
                           compressed::Bool = true,
                           periods::Union{Nothing, AbstractArray{Int}} = nothing,
                           progress = true, # true/false or Progress or ParallelProgress
                           api_key = get(ENV, "ZENODO_API_KEY", nothing),
                           zenodo_id = ZENODO_ID)

    if progress == true
        file_size = get_file_size(siteid, compressed)
        progress = Progress(file_size; desc = "Downloading $siteid.csv.gz ")
    elseif progress == false
        file_size = nothing
        progress = nothing
    end

    headers = Dict("Accept-Encoding" => compressed ? "gzip" : "identity")

    if !isnothing(api_key)
        headers["Authorization"] = "Bearer "*api_key
    end

    url = ZENODO_API*zenodo_id*"/files/$(siteid).csv?download=1"

    if !isnothing(periods)
        @info "`periods` not supported for Zenodo, full data will be downloaded"
    end
    
    file_extension = compressed ? ".csv.gz" : ".csv"
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
