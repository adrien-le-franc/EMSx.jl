# developed with Julia 1.1.1
#
# functions for displaying progress in parallel computing 
# can be replaced with default progressmeter when https://github.com/timholy/ProgressMeter.jl/pull/157 is merged

import ProgressMeter: next!, finish!, cancel, update!
import Distributed: RemoteChannel, put!

struct ParallelProgress{C}
    channel::C
    n::Int
end

const PP_NEXT = -1
const PP_FINISH = -2
const PP_CANCEL = -3

next!(pp::ParallelProgress) = put!(pp.channel, PP_NEXT)
finish!(pp::ParallelProgress) = put!(pp.channel, PP_FINISH)
cancel(pp::ParallelProgress, args...; kw...) = put!(pp.channel, PP_CANCEL)
update!(pp::ParallelProgress, counter, color = nothing) = put!(pp.channel, counter)

function ParallelProgress(n::Int; kw...)
    channel = RemoteChannel(() -> Channel{Int}(n))
    progress = Progress(n; kw...)
    
    @async while progress.counter < progress.n
        f = take!(channel)
        if f == PP_NEXT
            next!(progress)
        elseif f == PP_FINISH
            finish!(progress)
            break
        elseif f == PP_CANCEL
            cancel(progress)
            break
        elseif f >= 0
            update!(progress, f)
        end
    end
    return ParallelProgress(channel, n)
end

struct MultipleChannel{C}
    channel::C
    id
end
put!(mc::MultipleChannel, x) = put!(mc.channel, (mc.id, x))


struct MultipleProgress{C}
    channel::C
    amount::Int
    lengths::Vector{Int}
end

Base.getindex(mp::MultipleProgress, n::Integer) = ParallelProgress(MultipleChannel(mp.channel, n), mp.lengths[n])
finish!(mp::MultipleProgress) = put!.([mp.channel], [(p, PP_FINISH) for p in 1:mp.amount])

function MultipleProgress(amount::Integer, lengths::Integer; kw...)
    MultipleProgress(amount, fill(lengths, amount); kw...)
end

function MultipleProgress(amount::Integer, 
                          lengths::AbstractVector{<:Integer}; 
                          update_period = 0.1,
                          kws = [() for _ in 1:amount],
                          kw...)
    @assert amount == length(lengths) "`length(lengths)` must be equal to `amount`"

    total_length = sum(lengths)
    main_progress = Progress(total_length; offset=0, kw...)
    progresses = Union{Progress,Nothing}[nothing for _ in 1:amount]
    taken_offsets = Set(Int[])
    channel = RemoteChannel(() -> Channel{Tuple{Int,Int}}(max(2amount, 64)))

    max_offsets = 1

    # we must make sure that 2 progresses aren't updated at the same time
    @async begin
        while true
            
            (p, value) = take!(channel)

            # first time calling progress p
            if isnothing(progresses[p])
                # find first available offset
                offset = 1
                while offset in taken_offsets
                    offset += 1
                end
                max_offsets = max(max_offsets, offset)
                progresses[p] = Progress(lengths[p]; offset=offset, kw..., kws[p]...)
                push!(taken_offsets, offset)
            end

            if value == PP_NEXT
                next!(progresses[p])
                next!(main_progress)
            else
                prev_p_value = progresses[p].counter
                
                if value == PP_FINISH
                    finish!(progresses[p])
                elseif value == PP_CANCEL
                    cancel(progresses[p])
                elseif value >= 0
                    update!(progresses[p], value)
                end

                update!(main_progress, 
                        main_progress.counter - prev_p_value + progresses[p].counter)
            end

            if progresses[p].counter >= lengths[p]
                delete!(taken_offsets, progresses[p].offset)
            end

            main_progress.counter >= total_length && break
        end

        print("\n" ^ max_offsets)
    end

    return MultipleProgress(channel, amount, lengths)
end


