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