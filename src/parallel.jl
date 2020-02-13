
function init_parallel(n::Integer = Sys.CPU_THREADS; kw...)
    if n < 1
        error("number of workers must be greater than 0")
    elseif n == 1 && workers() != [1]
        rmprocs(workers())
    elseif n > nworkers()
        p = addprocs(n - (nprocs() == 1 ? 0 : nworkers()); kw...)
    elseif n < nworkers()
        rmprocs(workers()[n + 1:end])
    end
    @everywhere @eval using EMSx
    return workers()
end
