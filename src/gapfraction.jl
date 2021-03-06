# For slope correction on contact frequencies:
const AZIMUTH_GROUPS = 360 #number of τ groups per 2π
const MAX_ITER_τ = 5 # (Schleppi, 2007) says "after a few cycles"
const SLOPE_TOL = 1e-3


#fallback
gapfraction(pixs, thresh) = mean(pixs .> thresh)

#in general specialize on type of input array
function gapfraction(pixs::AbstractArray, thresh)
    threshT = convert(eltype(pixs), thresh)
    gapfrsum = 0
    for pix in pixs
        gapfrsum += pix > threshT
    end
    return(gapfrsum / length(pixs))
end

# specialized gapfraction method for Ufixed pixels, with threshold already 
# converted to Ufixed type for type stability.
# TODO check time difference against general function 
function gapfraction{T<:FixedPointNumbers.UFixed}(pixs::AbstractArray{T}, thresh)
    threshT = convert(T, thresh)
    gapfrsum = zero(Int)        
    for pix in pixs
        gapfrsum += pix.i > threshT.i
    end
    return(gapfrsum / length(pixs))
end

function loggapfraction(pixs, thresh)
    gf = gapfraction(pixs, thresh)
    gf == zero(gf) && return(log(1/length(pixs)))
    log(gf)
end

"Auxilary function to create rings with similar amount of pixels per ring."
function weightedrings(polim::PolarImage, θ1::Real, θ2::Real, N::Integer)
    
    # create edges for θ rings with similar number of pixels each
    θedges = map(polim.cl.fρθ, sqrt(linspace(polim.cl.fθρ(θ1)^2, 
                                             polim.cl.fθρ(θ2)^2, N+1)))
    #fix possible floating point roundoff errors
    θedges[1] = max(θedges[1], θ1) 
    θedges[end] = min(θedges[end], θ2)
    
    # weighted average midpoints
    θdouble = map(polim.cl.fρθ, sqrt(linspace(polim.cl.fθρ(θ1)^2, (polim.cl.fθρ(θ2))^2, 2N+1)))
    θmid = θdouble[2:2:2N]
    
    return θedges, θmid
end
weightedrings(polim::PolarImage, N::Integer) = weightedrings(polim, 0, pi/2, N)


function contactfreqs(polim::PolarImage, θ1::Real, θ2::Real, N::Integer, thresh;kwargs...)
    contactfreqs(polim, polim.slope, θ1, θ2, N, thresh; kwargs...)
end

function contactfreqs(polim::PolarImage, sl::NoSlope, θ1::Real, θ2::Real, 
                      N::Integer, thresh)
    checkθ1θ2(θ1,θ2)
    θedges, θmid = weightedrings(polim, θ1, θ2, N)    
    K = zeros(N)
    for i = 1:N        
        logT = loggapfraction(pixels(polim, θedges[i], θedges[i+1]), thresh)
        K[i] = -logT * cos(θmid[i])
    end
    θedges, θmid, K
end

# Method Schleppi et al 2007
function contactfreqs_iterate(pixs::AbstractArray, τs::AbstractArray, thresh, θ::Float64;
        Nϕ=AZIMUTH_GROUPS, max_iter=MAX_ITER_τ, tol=SLOPE_TOL)

    τmax = π/2
    τ = Base.midpoints(linspace(0, τmax, Nϕ+1))    
    Aθτ = fasthist(τs, -1/Nϕ : τmax/Nϕ : τmax)

    iter = 0
    # initially start with contact frequency K from whole θ ring 
    logT = loggapfraction(pixs, thresh)
    K = - logT * cos(θ)
    while iter < max_iter
        iter += 1 
        Tnew = sum(Aθτ .* exp(-K ./ cos(τ))) / sum(Aθτ)
        logTnew = log(Tnew)
        abs(logTnew / logT - 1) < tol && break
        K *= logTnew / logT
        logT = logTnew
    end
    K
end

function contactfreqs(polim::PolarImage, sl::Slope, θ1::Real, θ2::Real, 
      N::Integer, thresh; Nϕ=AZIMUTH_GROUPS, max_iter=MAX_ITER_τ, tol=SLOPE_TOL)

    checkθ1θ2(θ1,θ2)
    θedges, θmid = weightedrings(polim, θ1, θ2, N)    

    K = zeros(N)
    for i = 1:N
        pixs = pixels(polim, θedges[i], θedges[i+1])

        ρ²indstart = searchsortedfirst(polim.cl.ρ²unique, polim.cl.fθρ(θedges[i])^2) 
          ρ²indend =  searchsortedlast(polim.cl.ρ²unique, polim.cl.fθρ(θedges[i+1])^2) 
        indstart = polim.cl.ρ²unique_ind[ρ²indstart]
          indend = polim.cl.ρ²unique_ind[ρ²indend]
        τs = ArrayViews.view(polim.τsort, indstart:indend)
        
        K[i] = contactfreqs_iterate(pixs, τs, thresh, θmid[i]; 
                                    Nϕ=Nϕ, max_iter=max_iter, tol=tol)

        # Method España et al 2007. Nϕ different here!
        # adj = slope_adj(polim.slope, θmid[i], ϕv)
        # # we divide each ring in Nϕ azimuth  segments, calculate the slope 
        # # adjustment and loggapfraction per segment, then take average weighted 
        # # by segment length.
        # segm = segments(polim, θedges[i], θedges[i+1], Nϕ)
        # lengths = Int[length(seg) for seg in segm]
        
        # T = Float64[gapfraction(seg, thresh) for seg in segm]
        # nz = find(T) # avoid 0.^(negative float)
        # if isempty(nz) #to avoid infinity with log, assume at least 1 sky pixel
        #     Tadj = 1 / sum(lengths)
        # else
        #     Tadj = sum(T[nz].^(1./adj[nz]) .* lengths[nz])/sum(lengths)
        # end      
        # K[i] = -log(Tadj) * cos(θmid[i])

    end
    θedges, θmid, K
end
