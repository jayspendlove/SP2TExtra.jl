function getdarkcounts(darkframes::AbstractArray{<:Integer,3}; batchsize::Integer=1)
    darkcounts = Array{Float64}(undef, size(darkframes, 1), size(darkframes, 2))
    sum!(darkcounts, darkframes)
    N = size(darkframes, 3) * batchsize
    @. darkcounts .= -log1p(-darkcounts / N)
    return darkcounts
end

# function getframes() end

function calculate_optimal_iterations(sizelimit::Int, min_iters::Int)
    if min_iters < sizelimit - 1
        error("min_iters must be at least sizelimit - 1 ($(sizelimit - 1)) to allow at least one fill cycle.")
    end
    
    # Start from k=1 (first shrink cycle)
    k = 1
    while true
        total_iters = (sizelimit - 1) * (2^k)
        if total_iters >= min_iters
            return total_iters
        end
        k += 1
        # Prevent infinite loop (though k would be large)
        if k > 40  # 2^40 is huge, unlikely to reach
            error("No suitable total iterations found within reasonable k (min_iters too large).")
        end
    end
end

function final_chain_length(sizelimit::Int, niters::Int)
    if sizelimit < 1
        error("sizelimit must be >= 1")
    end
    if niters < 0
        error("niters must be >= 0")
    end

    chain_len = 1
    iter = 0
    prev_diff = 1

    while true
        stride = chain_len == 1 ? 1 :
                 prev_diff * (chain_len == sizelimit ? 2 : 1)

        rem = iter % stride
        next_iter = rem == 0 ? iter + stride : iter + (stride - rem)

        if next_iter > niters
            break
        end

        iter = next_iter

        if chain_len == sizelimit
            chain_len = ceil(Int, chain_len / 2)
            chain_len += 1
        else
            chain_len += 1
        end

        prev_diff = stride
    end

    return chain_len
end