

function langxiang45(thresh, polim::PolarImage, θ1::Real, θ2::Real)
    @checkθ1θ2
    n = 8
    segm = segments(polim, θ1, θ2, n)
    
    segm_gapfr = Float64[gapfraction(segm[i], thresh) for i in 1:length(segm)]
    clump_LX = log(mean(segm_gapfr)) / mean(log(segm_gapfr))
end
function langxiang45(polim::PolarImage, θ1::Real, θ2::Real)
    @checkθ1θ2
    thresh = threshold(polim)
    langxiang45(thresh, polim, θ1, θ2)
end
