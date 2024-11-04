#!/bin/bash

## Adapted from the example found at: https://github.com/faskowit/multiAtlasTT
## Under a MIT License Copyright (c) 2018 Josh Faskowitz

## Author: Marco Bedini, Postdoc, marco.bedini@univ-amu.fr
## Last updated: November 4, 2024 

####################################################################
####################################################################

# SETUP FSL HERE (I have these lines in my .zshrc profile on Ubuntu 22.04 LTS)
# FSLDIR=/home/marc_be/fsl
# PATH=${FSLDIR}/share/fsl/bin:${PATH}
# export FSLDIR PATH
# . ${FSLDIR}/etc/fslconf/fsl.sh

# SETUP FREESUFER HERE (example on Ubuntu 22.04 LTS)
# FREESURFER_HOME   /usr/local/freesurfer/7.3.2
# FSFAST_HOME       /usr/local/freesurfer/7.3.2/fsfast
# FSF_OUTPUT_FORMAT nii.gz
# SUBJECTS_DIR      /usr/local/freesurfer/7.3.2/subjects
# MNI_DIR           /usr/local/freesurfer/7.3.2/mni

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
export scriptBaseDir=${PWD}

# make a list from these options: 
# aal aicha arslan baldassano gordon333dil hcp-mmp-b ica nspn500 power 
# schaefer100-yeo17 schaefer200-yeo17 schaefer300-yeo17 schaefer400-yeo17 
# schaefer500-yeo17 shen268cort yeo17dil
#
# example line to explore some atlases I would like to work with in the RetinoMaps project
export atlasList="hcp-mmp-b schaefer100-yeo17 schaefer400-yeo17 yeo17dil"

# if you have a specific install of python that you'd like to
# point this script to (for example, if you have your own 
# python install on a supercomputer account), uncomment
# this line and set the variable 'py_bin' to that location
# export py_bin=/custom/path/to/your/python

####################################################################
####################################################################

# subject variables

subj="sub-03"
inputFSDir="/media/marc_be/marc_be_flashSD/RetinoMaps/atlases/freesurfer/${subj}"
outputDir="/media/marc_be/marc_be_flashSD/RetinoMaps/atlases/multiAtlasTT_test/${subj}"
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
# -s          subject_num -> bids subject identifier 
# -d          inputFSDir --> input freesurfer directory
# -o          outputDir ---> output directory, will also write temporary 
# -f          fsVersion ---> freeSurfer version (5p3 or 6p0 and 7p1)
# -s 	      doStats -----> flag for doing stats on parcellation; takes a while but gives you info about vol and coordinate

# start the timer! 
start=`date +%s`

# run it
cmd="${scriptBaseDir}/src/maTT2_applyGCS.sh \
        -d ${inputFSDir} \
        -o ${outputDir} \
        -f 7p1 \
    "
echo $cmd 
eval $cmd | tee -a ${OUT}

# record how long that took!
end=`date +%s`
runtime=$((end-start))
echo "runtime: $runtime"


