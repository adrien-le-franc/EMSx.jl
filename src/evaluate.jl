# developed with Julia 1.4.2
#
# functions to evaluate a model based on performance metrics 
# computed after simulation


function average_cost_per_site(result_model::String, 
	result_dummy::String=joinpath(DIR, "metadata", "baseline", "dummy.jld2"), 
	result_anticipative::String=joinpath(DIR, "metadata", "baseline", "anticipative.jld2"))
    
    model = load(result_model)
    dummy = load(result_dummy)
    anticipative = load(result_anticipative)
    scores = DataFrame(site=String[], period=String[], model=Float64[], 
    	dummy=Float64[], anticipative=Float64[])
    
    sites = keys(model)
    ordered_sites = string.(sort!(parse.(Int64, string.(sites))))
    
    for site in ordered_sites
        
        simulations_model = model[site]
        simulations_dummy = dummy[site]
        simulations_anticipative = anticipative[site]
        
        for simulation in zip(simulations_model, simulations_dummy, 
        	simulations_anticipative)
            
            model_cost = sum(simulation[1].result.cost)
            dummy_cost = sum(simulation[2].result.cost)
            anticipative_cost = sum(simulation[3].result.cost)
            push!(scores, [simulation[1].id.site_id, simulation[1].id.period_id, 
                    model_cost, dummy_cost, anticipative_cost])
            
        end
        
    end
        
    summary = DataFrame(site=String[], model=Float64[], dummy=Float64[], anticipative=Float64[])

    for site in ordered_sites
        data = scores[scores.site .== site, :]
        model_mean_cost = mean(data[!, :model])
        dummy_mean_cost = mean(data[!, :dummy])
        anticipative_mean_cost = mean(data[!, :anticipative])
        push!(summary, [site, model_mean_cost, dummy_mean_cost, anticipative_mean_cost])
    end
    
    return summary 
    
end

function evaluate_model(result_model::String,
	result_dummy::String=joinpath(DIR, "metadata", "baseline", "dummy.jld2"), 
	result_anticipative::String=joinpath(DIR, "metadata", "baseline", "anticipative.jld2"))
    
    average_costs = average_cost_per_site(result_model, result_dummy, result_anticipative)
    
    DataFrame(site=average_costs[!, :site], 
    	cost=average_costs[!, :model],
    	gain=average_costs[!, :dummy] - average_costs[!, :model],
    	score=(average_costs[!, :dummy] - average_costs[!, :model]) ./ (average_costs[!, :dummy]
    	- average_costs[!, :anticipative]))
    
end