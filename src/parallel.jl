
function init_parallel(N::Integer = Sys.CPU_THREADS; kw...)
    if N < 1
        error("Number of workers must be greater than 0")
    elseif N == 1 && workers() != [1]
        rmprocs(workers())
    elseif N > nworkers()
        p = addprocs(N - (nprocs() == 1 ? 0 : nworkers()); kw...)
    elseif N < nworkers()
        rmprocs(workers()[N + 1:end])
    end
    @everywhere @eval using EMSx
    return workers()
end