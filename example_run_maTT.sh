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
# export variables to maTT_main.sh

export atlasBaseDir=${PWD}/
export scriptBaseDir=${PWD}/
# make a list from these options: 
# nspn500 gordon333 yeo17 hcp-mmp schaefer100-yeo17 
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
OUT="maTT_notes.txt"
touch $OUT

####################################################################
####################################################################
# run the script

# script inputs:
# inputFSDir=$1 --> input freesurfer directory
# outputDir=$2 ---> output directory, will also write temporary 
#                   files here 
# optional inputs:
# refBrain=$3 ----> file to be used as reference when transfering 
#                   aparc+aseg.mgz to orginal (native) space.
# numThread=$4 ---> number of parallel processes to use when doing
#                   the label transfer

start=`date +%s`

cmd="${scriptBaseDir}/maTT_main.sh \
        ${inputFSDir} \
        ${outputDir} \
    "
echo $cmd 
eval $cmd | tee -a ${OUT}

# record how long that took!
end=`date +%s`
runtime=$((end-start))
echo "runtime: $runtime"


