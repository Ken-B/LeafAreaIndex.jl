# We use [dcraw](http://www.cybercom.net/~dcoffin/dcraw/) to extract from RAW images
# the blue channel pixels and convert to 16bit pgm without exposure manipulation. 

# The website notes: "Unless otherwise noted in the source code, these programs 
# are free for all uses, although I would like to receive credit for them."
# The program dcraw is written by Dave Coffin.


# On mac, compile dcraw.c with
# 	`llvm-gcc -o dcraw dcraw.c -lm -DNO_JPEG -DNO_LCMS -DNO_JASPER`
# source [http://vkphotoblog.blogspot.be/2014/05/dcraw-921-for-os-x-mavericks-users.html]

# ### dcraw options
# * -W: avoids stretching ("No matter how dark an image is, dcraw's auto-exposure stretches it so that one percent of its pixels appear white. The "-W" option avoids this behavior.")
# * -4: is for linear 16-bit, same as -6 -W -g 1 1 (with -g for gamma correction)
# * -j: don't stretch or rotate raw pixels
# * -t [0-7]: flip image (0=none)
# * -D: document mode without scaling (totally raw), while -d scales to 16bit (eg from 14bit). Either use -D and then reinterpret in julia or use -d. We now use -d otherwise we need to extract image property for bit depth (12bit, 14bit, ...).
# * -r 0 0 0 1: select only the blue channel (see Brusa and Bunker, 2014). This option selects from a bayer RGGB layout.
# * -v: for verbose output


const OVEREXP = 0.005
const RAW_EXT = ASCIIString[".3fr", ".ari", ".arw", ".bay", ".crw", ".cr2",
".cap", ".dcs", ".dcr", ".dng",
".drf", ".eip", ".erf", ".fff", ".iiq", ".k25", ".kdc", ".mdc", ".mef", ".mos", ".mrw",
".nef", ".nrw", ".obm", ".orf", ".pef", ".ptx", ".pxn", ".r3d", ".raf", ".raw", ".rwl",
".rw2", ".rwz", ".sr2", ".srf", ".srw", ".tif", ".x3f"]

const DCRAW_DIR = joinpath(Pkg.dir("LeafAreaIndex"),"src","dcraw")
@windows_only const DCRAW_EXE = joinpath(DCRAW_DIR, "dcraw-9.26-ms-64-bit.exe")
@unix_only begin
    const DCRAW_EXE = joinpath(DCRAW_DIR, "dcraw")
    isexecutable(DCRAW_EXE) || chmod(DCRAW_EXE, 0o755)
end

"""Read in the raw blue channel from a raw image. The image is copied to
a temporary directory and run through dcraw with options `-d -4 -j -t 0 -r 0 0 0 1`."""
function rawblueread(filepath::AbstractString;
    overwrite=false, destdir=joinpath(tempdir(), "pgm"), rmcopy=true, rmpgm=true)

    @assert isfile(filepath) 
    ext = lowercase(splitext(filepath)[end])
    @assert ext ∈ RAW_EXT
    isdir(destdir) || mkdir(destdir)

    raw2pgm(f) = run(`$DCRAW_EXE -d -4 -j -t 0 -r 0 0 0 1 $f`)

    copyfile = joinpath(destdir, splitdir(filepath)[end])
    pgm = splitext(copyfile)[1] * ".pgm"

    if !overwrite && isfile(pgm)
        return Netpbm.load(pgm)
    end

    cp(filepath, copyfile; remove_destination=true)
    raw2pgm(copyfile)
    img = Netpbm.load(pgm)
    rmcopy && rm(copyfile)
    rmpgm && rm(pgm)
    img
end

isoverexposed(img::AbstractArray) = sum(img .== 1) > OVEREXP * length(img)
isoverexposed(polim::PolarImage) = isoverexposed(pixels(polim))