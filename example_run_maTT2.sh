#!/bin/bash

####################################################################
####################################################################

# SETUP FSL HERE (however it is done on your system)
# export FSLDIR=/programs/fsl/
# source ${FSLDIR}/etc/fslconf/fsl.sh

# SETUP FREESUFER HERE (however it is done on your system)
# module load freesurfer/5.3.0

####################################################################
####################################################################

# for maTT2 to function, download the .gcs files from: 
# https://doi.org/10.6084/m9.figshare.5998583  
# or here:
# https://doi.org/10.6084/m9.figshare.7552853
# and put these files into the 
# /atlas_data/{atlas}/ folders that correspond to
# the atlasBaseDir variable set here
export atlasBaseDir=${PWD}/atlas_data/

# this is just the location where these scripts live
# ... needed so that the ${scriptBaseDir}/src can 
# be found
export scriptBaseDir=${PWD}/

# make a list from these options: 
# aal aicha arslan baldassano gordon333dil hcp-mmp-b ica nspn500 power 
# schaefer100-yeo17 schaefer200-yeo17 schaefer300-yeo17 schaefer400-yeo17 
# schaefer500-yeo17 shen268cort yeo17dil
#
# for example, for the schaefer 100, 200 and yeo-114 parcellation
# the line would be --> 
export atlasList="schaefer100-yeo17 schaefer200-yeo17 yeo17dil"

# if you have a specific instal of python that you'd like to
# point this script to (for example, if you have your own 
# python install on a supercomputer account), uncomment
# this line and set the variable 'py_bin' to that location
# export py_bin=/custom/path/to/your/python

####################################################################
####################################################################
# subject variables

subj="my_subject"
inputFSDir="/path/to/freesurfer/${subj}/"
outputDir="/output/to/somwhere/${subj}/"
mkdir -p ${outputDir} || \
   { echo "could not make dir" ; exit 0 ; } # safe-ish mkdir

####################################################################
####################################################################
# go into the folder where we also want output and setup notes file!

cd ${outputDir} || { echo "could not cd" ; exit 0 ; } # safe-ish cd
OUT="maTT2_notes.txt"
touch $OUT

####################################################################
####################################################################
# run the script

# script inputs:
# -d          inputFSDir --> input freesurfer directory
# -o          outputDir ---> output directory, will also write temporary 
# -f          fsVersion ---> freeSurfer version (5p3 or 6p0 and 7p1)
# -s 		  doStats -----> flag for doing stats on parcellation; takes a while
# 							 but gives you information about vol and coordinate

# start the timer! 
start=`date +%s`

# run it
cmd="${scriptBaseDir}/src/maTT2_applyGCS.sh \
        -d ${inputFSDir} \
        -o ${outputDir} \
        -f 6p0 \
    "
echo $cmd 
eval $cmd | tee -a ${OUT}

# record how long that took!
end=`date +%s`
runtime=$((end-start))
echo "runtime: $runtime"


