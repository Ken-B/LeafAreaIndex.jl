## PolarImage ##
const APPROX_N=1000

# Type to contain an image and its polar transform
type PolarImage{T, A <: AbstractMatrix}
    cl::CameraLens
    slope::SlopeInfo
    img::A              #original image
    imgsort::Vector{T}  #image sorted by ρ², then ϕ
    imgspiral::Vector{T}#image spiral sorted
    τsort::Vector{Float64}# incidence angle τ for sloped images, sorted as imgsort
end 

# PolarImage constructor
function PolarImage(img::AbstractMatrix, cl::CameraLens)
    imgsort = img[cl.sort_ind]
    imgspiral = img[cl.spiral_ind]
    τsort = create_τsort(NoSlope(), cl)
    PolarImage{eltype(img), typeof(img)}(cl, NoSlope(), img, imgsort, imgspiral,τsort)
end
function PolarImage(img::AbstractMatrix, cl::CameraLens, slope::SlopeInfo)
    imgsort = img[cl.sort_ind]
    imgspiral = img[cl.spiral_ind]
    τsort = create_τsort(slope, cl)
    PolarImage{eltype(img), typeof(img)}(cl, slope, img, imgsort, imgspiral,τsort)
end

function approx_fρ²θ(cl::CameraLens; N=APPROX_N)
    # fit θ(x) = ax + bx² + cx³ with x=ρ²

    ρ² = linspace(0, cl.ρ²sort[end], N)
    A = [ρ²ᵢ^p for ρ²ᵢ in ρ², p = 1:3]
    a,b,c = A \ ρ²
    x -> a*x + b*x^2 +c*c^3
    # TODO using FastAnonymous
end

function create_τsort(sl::NoSlope, cl::CameraLens)
    # create θ in case of no slope
    τsort = similar(cl.ϕsort)
    ρ²sort = cl.ρ²sort 
    fρ²θ = approx_fρ²θ(cl) 
    @inbounds for i = 1:length(τsort)
        τsort[i] = fρ²θ(τsort[i])
    end
    τsort
end
# @memoize?
function create_τsort(sl::Slope, cl::CameraLens)
    τsort = copy(cl.ϕsort)
    ρ²sort = cl.ρ²sort    
    fρ²θ(ρ²) = cl.fρθ(sqrt(ρ²)) 
    α = sl.α
    ε = sl.ε
    @inbounds for i = 1:length(τsort)
        θ = fρ²θ(ρ²sort[i])
        ϕ = τsort[i]
        τsort[i] = acos(cos(θ)*cos(α) + sin(θ)*cos(ε-ϕ)*sin(α))
    end
    τsort
end

slope(polim::PolarImage) = slope(polim.slope)
aspect(polim::PolarImage) = aspect(polim.slope)
has_slope(polim::PolarImage) = isa(polim.slope, Slope)

# generic constructor for testing
genPolarImage(M) = PolarImage(M, gencalibrate(M))

Base.eltype{T}(polim::PolarImage{T}) = T
Base.length(pm::PolarImage) = length(pm.cl.ρ²sort)

function Base.show(io::IO, polim::PolarImage)
    with_out = ifelse(isa(polim.slope, NoSlope), "without", "with")
    print(io::IO, "PolarImage $with_out slope")
end
Base.writemime(io::IO, ::MIME"text/plain", cl::CameraLens) = show(io, cl)

