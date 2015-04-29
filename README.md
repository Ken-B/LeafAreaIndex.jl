# LeafAreaIndex

[![Build Status](https://travis-ci.org/ETC-UA/LeafAreaIndex.jl.svg?branch=master)](https://travis-ci.org/ETC-UA/LeafAreaIndex.jl)
[![Documentation Status](https://readthedocs.org/projects/leafareaindexjl/badge/?version=latest)](https://readthedocs.org/projects/leafareaindexjl/?badge=latest)

Tools to work with [hemispherical pictures](http://en.wikipedia.org/wiki/Hemispherical_photography) for the determination of [Leaf Area Index (LAI)](http://en.wikipedia.org/wiki/Leaf_area_index).

This package introduces the PolarImage type with a few convenient methods to access certain parts of an image in polar coordinates.

View the full documentation on readthedocs: http://leafareaindexjl.readthedocs.org .

# Quick introduction

Install the package through

    Pkg.clone("https://github.com/ETC-UA/LeafAreaIndex.jl")

You construct a PolarImage from a Calibration type and an Image (or in general, a Matrix). The calibration requires the image size, the coordinates of the lens center and the (inverse) projection function. 
(The projection function maps polar distance ρ [in pixels] on the image to the zenith angle θ [in radians] of the scene and is usually not linear.)

    using Images
    img = imread("image.dng")
    imgblue = blue(img) #take the blue channel
    using LeafAreaIndex
    mycameralens = calibrate(height, width, ci, cj, fθρ, fρθ)
    polarimg = PolarImage(imgblue, mycameralens)

The first step is automatical thresholding with the default method Ridler Calvard:

    thresh = threshold(polarimg)

The clumping factor can be estimated with the method of Lang Xiang with 45ᵒ segments between view angles θ1 and θ2 using `langxiang45(polarimg, thresh, θ1, θ2)`. Similarly `chencihlar(polarimg, thresh, θ1, θ2)` for the Chen Chilar method.

There are two methods to estimate LAI assuming an ellipsoidal leave angle distribution, both also estimating the Average Leaf Inclination Angle (ALIA). The first one uses a Lookup Table (LUT) and the second one an optimization method.

    LAI1 = ellips_LUT(polarimg, thresh)
    LAI2 = ellips_opt(polarimg, thresh)

## further methods

For images taken (vertically upwards) on a domain with slope of eg 10ᵒ and downward to the East, you must include this in your PolarImage.

    myslope = Slope(10/180*pi, pi/2)
    polarimg = PolarImage(img, mycameralens, myslope)

Two more automatic thresholding methods can be used with `edge_threshold` and `minimum_threshhold` for the Edge Detection and Minimum algorithm.

Further LAI estimation methods are available: `zenith57(polarimg, thresh)` for using a view angle of 57ᵒ where the ALIA influence is minimal; `miller(polarimg, thresh` for miller integration assuming a constant leaf angle; and `lang(polarimg, thresh)` that uses a first order regression on the miller method.

To access the pixels in a particular zenith range, `pixels(polarimg, pi/6, pi/3)` will return a vector with pixels quickly, sorted by increasing ρ (and then by polar angles ϕ for identical ρ). A shortcut `pixels(polarimg)` is translated to `pixels(polarimg, 0, pi/2)`.

The `segments` function can further split these ring pixels in n segments (eg. for clumping calculation). It returns a vector with n elements, each a vector with segment pixels.

You can also construct an *iterator* to access a specific zenith range. It will return the pixels on each ring in the range by increasing integer ρ² in a tuple with a vector of polar angles ϕ and a vector of corresponding pixels.
    
    for (ρ², ϕ, px) in rings(polarimg, pi/6, pi/3)
        # do something with each ρ², ϕ, px variable
    end

In case of problems or suggestion, don't hesitate to submit an issue through the issue tracker or code suggestions through a pull request.



