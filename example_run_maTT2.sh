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

export atlasBaseDir=${PWD}/
export scriptBaseDir=${PWD}/
# make a list from these options: 
# nspn500 gordon333 yeo17 yeo17dil hcp-mmp schaefer100-yeo17 
# schaefer200-yeo17 schaefer400-yeo17 schaefer600-yeo17 schaefer800-yeo17 
# schaefer1000-yeo17
export atlasList="schaefer100-yeo17 schaefer200-yeo17 yeo17"

####################################################################
####################################################################
# subject variables

subj="my_subject"
inputFSDir="/path/to/freesurfer/${subj}/"
outputDir="/output/to/somwhere/${subj}/"
mkdir -p ${outputDir}

####################################################################
####################################################################
# go into the folder where we also want output and setup notes file!

cd ${outputDir}
OUT="maTT2_notes.txt"
touch $OUT

####################################################################
####################################################################
# run the script

# script inputs:
# -d          inputFSDir --> input freesurfer directory
# -o          outputDir ---> output directory, will also write temporary 
# -f          fsVersion ---> freeSurfer version (5p3 or 6p0)

############
# REMINDER #
############

# for maTT2 to function, download the .gcs files from: 
# https://doi.org/10.6084/m9.figshare.5998583.v1 
# and put these files into the respective 
# /atlas_data/{atlas}/ folders

start=`date +%s`

cmd="${scriptBaseDir}/src/maTT2_applyGCS.sh \
        -d ${inputFSDir} \
        -o ${outputDir} \
        -f 5p3 \
    "
echo $cmd 
eval $cmd | tee -a ${OUT}

# record how long that took!
end=`date +%s`
runtime=$((end-start))
echo "runtime: $runtime"


