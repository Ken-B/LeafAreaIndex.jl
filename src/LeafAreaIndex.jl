module LeafAreaIndex

import FixedPointNumbers
import StreamStats

using Lexicon

export calibrate, PolarImage, pixels, gapfraction, contactfreq,
        zenith57, miller, lang

# default ring width for zenith57 and contactfreq
const RING_WIDTH = 5/180*π

include("CameraLens.jl")
include("PolarImage.jl")
include("PolarRings.jl")
include("PolarPixels.jl")
include("thresholding.jl")
include("gapfraction.jl")
include("inversion.jl")

end # module
