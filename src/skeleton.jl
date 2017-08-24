using LightGraphs
using LightGraphs.SimpleGraphs
using Combinatorics
 

"""
    removesorted(collection, item) -> contains(collection, item)
    
Remove item from sorted collection. 
"""
function removesorted!(n, v)
    i = searchsorted(n, v)
    isempty(i) && return false   # not found
    deleteat!(n, first(i))
    true
end

"""
    skeleton(n, I) -> g, S

Perform the undirected PC skeleton algorithm for a set of 1:n variables using the test I.
Returns skeleton graph and separating set  
"""
function skeleton(n::V, I, par...) where {V}
    g = CompleteGraph(n)
    S = Dict{edgetype(g),Vector{V}}()
    d = 0 # depth
    while true
        isdone = true
        for e0 in collect(edges(g))::Vector{edgetype(g)} # cannot remove edges while iterating
            for e in (e0, reverse(e0))
                nb0 = neighbors(g, src(e))
                if length(nb0) > d  # i.e. |nb\{dst(e)}| >= d 
                    nb = copy(nb0)
                    removesorted!(nb, dst(e))
                    isdone = false
                    for s in combinations(nb, d)
                        if I(src(e), dst(e), s, par...) 
                            rem_edge!(g, e0)
                            if !(e0 in keys(S))
                                S[e0] = s
                            end
                            break 
                        end
                    end
                end
            end
        end 
        d = d + 1
        if isdone
            return g, S
        end
    end    
end


function dseporacle(i, j, s, g)
    dsep(g, i, j, s)
end        

function partialcor(i, j, s, C)
    n = length(s)
    if n == 0
        C[i,j]
    elseif n == 1
        k = s[1]
        (C[i, j] - C[i, k]*C[j, k])/sqrt((1 - C[j, k]^2)*(1 - C[i, k]^2))
    else 
        is = zeros(Int, n+2)
        is[1] = i
        is[2] = j
        for k in 1:n
            is[k+2] = s[k]
        end
        C0 = C[is, is]
        P = pinv(C0, 1.5e-8)
        -P[1, 2]/sqrt(P[1, 1]*P[2, 2])
    end    
end



"""
    gausscitest(i, j, s, (C,n), c)

Test for conditional independence of variable no i and j given variables in s with 
Gaussian test at the critical value c. C is covariance of n observations.

"""
@inline function gausscitest(i, j, s, stat, c)
    C, n = stat
    r = partialcor(i, j, s, C)
    r = clamp(r, -1, 1)
    n - length(s) - 3 <= 0 && return true # remove edges which cannot be tested for
    t = sqrt(n - length(s) - 3)*atanh(r)
    abs(t) < c
end 

function partialcorchol(i, j, s, C)
    n = length(s)
    if n == 0
        C[i,j]
    elseif n == 1
        k = s[1]
        (C[i, j] - C[i, k]*C[j, k])/sqrt((1 - C[j, k]^2)*(1 - C[i, k]^2))
    elseif n < 10
        C0 = C[[i;j;s],[i;j;s]]
        #P = cholfact(C0*C0')\C0
        P = inv(cholfact(C0))
        -P[1, 2]/sqrt(P[1, 1]*P[2, 2])
    else 
        C0 = C[[i;j;s],[i;j;s]]
        P = pinv(C0, 1.5e-8)
        -P[1, 2]/sqrt(P[1, 1]*P[2, 2])
    end  
end
@inline function gausscitestchol(i, j, s, stat, c)
    C, n = stat
    r = partialcorchol(i, j, s, C)
    r = clamp(r, -1, 1)
    n - length(s) - 3 <= 0 && return true # remove edges which cannot be tested for
    t = sqrt(n - length(s) - 3)*atanh(r)
    abs(t) < c
end 
