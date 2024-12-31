#!/bin/bash

fflags="-qopenmp -fPIC"
f2pycomp="intelem"

# f90 shared library
target=lib${pylib}

# set directory
flibloc="/home/yyli/spt/cmblensplus/F90"
lapack="${flibloc}/pub/LAPACK95/"
# lapack="/cvmfs/spt.opensciencegrid.org/py3-v5/RHEL_9_x86_64/lib/"
fftw="${flibloc}/pub/FFTW/"
# fftw="/cvmfs/spt.opensciencegrid.org/py3-v5/RHEL_9_x86_64/lib/"
#cfitsio="${flibloc}/pub/cfitsio"
cfitsio="/cvmfs/spt.opensciencegrid.org/py3-v5/RHEL_9_x86_64/lib/"
# healpix="${flibloc}/pub/Healpix"
healpix="/home/yyli/software/Healpix_3.83"
lenspix="${flibloc}/pub/lenspix"

pylibloc="../../py/"
wrapdir="../../wrap${pyv}/"

