#!/bin/bash

<<'COMMENT'
josh faskowitz
Indiana University
Computational Cognitive Neurosciene Lab

Copyright (c) 2018 Josh Faskowitz
See LICENSE file for license
COMMENT

####################################################################
####################################################################
#
# This script uses GCS files to fit atlases to individuals--> which
# makes it different from the label transfer script, which just uses
# the spherical warp to transfer labels from fsaverage to each subj.
# This script will use a GCS file that Josh made from the mindboggle
# 101 subjects. 
#
####################################################################
####################################################################
#
# vars that this script would like exported in, via 'export=' 
#   atlasBaseDir
#   scriptBaseDir
#   atlasList
#
# note: the atlas atlasBaseDir needs to minimally have the lh and rh
# GCS file, and the appropriate LUT (made after running maTT main). 
# Because of size of GCS files, they will not be hosted on GitHub,
# but will be hosted elsewhere--which will be aparent in the repo
#
####################################################################
####################################################################

help_usage() 
{
cat <<helpusagetext

USAGE: ${0} 
        -d          inputFSDir --> input freesurfer directory
        -o          outputDir ---> output directory, will also write temporary 
        -f          fsVersion ---> freeSurfer version (5p3 or 6p0)
helpusagetext
}

usage() 
{
cat <<usagetext

USAGE: ${0} 
        -d          inputFSDir 
        -o          outputDir
        -f          fsVersion (5p3 or 6p0)
usagetext
}

####################################################################
####################################################################
# define main function here, and then call it at the end

main() 
{

start=`date +%s`

####################################################################
####################################################################

# Check the number of arguments. If none are passed, print help and exit.
NUMARGS=$#
if [ $NUMARGS -lt 3 ]; then
	echo "Not enough args"
	usage &>2 
	exit 1
fi

# read in args
while getopts "a:b:c:d:e:f:g:hi:j:k:l:m:n:o:p:q:s:r:t:u:v:w:x:y:z:" OPTION
do
     case $OPTION in
		d)
			inputFSDir=$OPTARG
			;;
		o)
			outputDir=$OPTARG
            ;;  
        f)
            fsVersion=$OPTARG
            ;;
		h) 
			help_usage >&2
            exit 1
      		;;
		?) # getopts issues an error message
			usage >&2
            exit 1
      		;;
     esac
done

shift "$((OPTIND-1))" # Shift off the options and optional

####################################################################
####################################################################
# check user inputs

# if these two variables are empty, return
if [[ -z ${inputFSDir} ]] || [[ -z ${outputDir} ]]
then
    echo "minimun arguments -d and -o not provided"
	usage >&2
    exit 1
fi

# make full path, add forward slash too
inputFSDir=$(readlink -f ${inputFSDir})/
outputDir=${outputDir}/

# check existence of FS directory
if [[ ! -d ${inputFSDir} ]]
then 
    echo "input FS directory does not exist. exiting"
    exit 1
fi

# add check for fsVersion
if [[ ${fsVersion} != '5p3' ]] && \
    [[ ${fsVersion} != '6p0' ]] 
then
    echo "fsVersion must be set and must be either:"
    echo "5p3 or 6p0"
    exit 1
fi

# check if we can make output dir
mkdir -p ${outputDir}/ || \
    { echo "could not make output dir; exiting" ; exit 1 ; } 

####################################################################
####################################################################

# setup note-taking
OUT=${outputDir}/notes.txt
touch $OUT

# also make this a full path
outputDir=$(readlink -f ${outputDir})/

# set subj variable to fs dir name, as is freesurfer custom
subj=$(basename $inputFSDir)

if [[ -z ${atlasBaseDir} ]]
then
    echo "atlasBaseDir is unset"
    atlasBaseDir=${PWD}/atlas_data/    
    if [[ ! -d ${atlasBaseDir} ]]
    then
        echo "cannot find the atlas_data; please set and retry"
        exit 1
    fi
    echo "will assume this is the right dir: ${atlasBaseDir}"
fi

# if this variable is empty, set it
if [[ -z ${atlasList} ]]
then
    # all the available atlases
    atlasList="gordon333 nspn500 yeo17 yeo17dil hcp-mmp schaefer100-yeo17 schaefer200-yeo17 schaefer400-yeo17 schaefer600-yeo17 schaefer800-yeo17 schaefer1000-yeo17"
else
    echo "using the atlasList exported to this script"
fi

# check the other scripts too
if [[ -z ${scriptBaseDir} ]] 
then
    scriptBaseDir=${PWD}/
fi

other_scripts="/src/maTT_remap.py /src/maTT_funcs.sh"
for script in ${other_scripts}
do

    if [[ ! -e ${scriptBaseDir}/${script} ]]
    then
        echo "need ${script} for this to work; cannot find"
        exit 1
    fi
done

####################################################################
####################################################################

mkdir -p ${outputDir}/tmpFsDir/${subj}/
tempFSSubj=${outputDir}/tmpFsDir/${subj}/

# copy minimally to speed up
mkdir -p ${tempFSSubj}/surf/
mkdir -p ${tempFSSubj}/label/
mkdir -p ${tempFSSubj}/mri/

# surf
cp -asv ${inputFSDir}/surf/?h.sphere.reg ${tempFSSubj}/surf/
cp -asv ${inputFSDir}/surf/?h.white ${tempFSSubj}/surf/
cp -asv ${inputFSDir}/surf/?h.pial ${tempFSSubj}/surf/
cp -asv ${inputFSDir}/surf/?h.smoothwm ${tempFSSubj}/surf/
cp -asv ${inputFSDir}/surf/?h.sulc ${tempFSSubj}/surf/
cp -asv ${inputFSDir}/surf/?h.thickness ${tempFSSubj}/surf/

# label
cp -asv ${inputFSDir}/label/?h.cortex.label ${tempFSSubj}/label/

# mri
cp -asv ${inputFSDir}/mri/aseg.mgz ${tempFSSubj}/mri/
cp -asv ${inputFSDir}/mri/ribbon.mgz ${tempFSSubj}/mri/
cp -asv ${inputFSDir}/mri/rawavg.mgz ${tempFSSubj}/mri/

# reset SUJECTS_DIR to the new inputFSDir
export SUBJECTS_DIR=${outputDir}/tmpFsDir/

####################################################################
####################################################################

# run it
for atlas in ${atlasList}
do
 
    if [[ -e ${outputDir}/${atlas}/${atlas}.mgz ]]
    then 
        continue 
    fi

    for hemi in lh rh
    do

        currentGCS=${atlasBaseDir}/${atlas}/${hemi}.${atlas}_${fsVersion}.gcs

        if [[ ! -f ${currentGCS} ]]
        then
            echo "could not find GCS: ${currentGCS} ...skipping"
            continue
        fi

        mkdir -p ${outputDir}/${atlas}/

        # mris_ca_label [options] <subject> <hemi> <canonsurf> <classifier> <outputfile>
        cmd="${FREESURFER_HOME}/bin/mris_ca_label \
                    -l ${tempFSSubj}/label/${hemi}.cortex.label \
                    -aseg ${tempFSSubj}/mri/aseg.mgz \
                    -seed 1234 \
                    ${subj} \
                    ${hemi} \
                    ${tempFSSubj}/surf/${hemi}.sphere.reg \
                    ${currentGCS} \
                    ${outputDir}/${atlas}/${hemi}.${atlas}.annot \
		    "
        echo $cmd #state the command
        log $cmd
        eval $cmd #execute the command

        st=$!
        [[ ${st} -gt 0 ]] && { exit 1 ; }
        

    done # for hemi in lh rh

    if [[ ! -f ${outputDir}/${atlas}/${hemi}.${atlas}.annot ]] || \
        [[ ! -f ${outputDir}/${atlas}/${hemi}.${atlas}.annot ]]
    then
        echo "problem making the atlas: ${atlas} ...skipping"
        continue
    else
        ln -s ${outputDir}/${atlas}/lh.${atlas}.annot ${tempFSSubj}/label/lh.${atlas}.annot
        ln -s ${outputDir}/${atlas}/rh.${atlas}.annot ${tempFSSubj}/label/rh.${atlas}.annot
        # and link the LUT to the output
        ln -s ${atlasBaseDir}/${atlas}/LUT_${atlas}.txt ${outputDir}/${atlas}/LUT_${atlas}.txt
    fi

    # mri_aparc2aseg
    cmd="${FREESURFER_HOME}/bin/mri_aparc2aseg \
            --s ${subj} \
            --annot ${atlas} \
            --volmask \
            --o ${outputDir}/${atlas}/${atlas}.mgz \
	    "
    echo $cmd #state the command
    log $cmd 
    eval $cmd #execute the command

    # convert out of freesurfer space
    cmd="${FREESURFER_HOME}/bin/mri_label2vol \
		    --seg ${outputDir}/${atlas}/${atlas}.mgz \
		    --temp ${tempFSSubj}/mri/rawavg.mgz \
		    --o ${outputDir}/${atlas}/${atlas}.nii.gz \
		    --regheader ${outputDir}/${atlas}/${atlas}.mgz \
		    "
    echo $cmd #state the command
    log $cmd >> $OUT
    eval $cmd #execute the command

done # for atlas in atlasList

####################################################################
####################################################################
# create aparc+aseg - derrived data using just one of the 
# parcellations just made. we will pick the first. since we are 
# reading information (cortical mask and subcort vols) that dont
# change with atlas, we can pick any one.

atlasListArray=($(echo ${atlasList}))
pickAtlas=${atlasListArray[0]}
subjAparcAseg=${outputDir}/${pickAtlas}/${pickAtlas}.nii.gz

if [[ ! -e ${subjAparcAseg} ]]
then
    echo "problem. could not read subjAparcAseg: ${subjAparcAseg}"
    exit 1
else
    ln -s ${subjAparcAseg} ${outputDir}/subj_aparc+aseg_ln.nii.gz 
fi

####################################################################
####################################################################
# get gm ribbom if does not exits

if [[ ! -e ${outputDir}/${subj}_cortical_mask.nii.gz ]]
then

    # let's get a lh and rh, get largest component of each
    cmd="${FREESURFER_HOME}/bin/mri_binarize \
            --i ${subjAparcAseg} \
            --min 1000 --max 1999 --binval 1 \
            --o ${outputDir}/lh.tmp_cort_mask.nii.gz \
        "     
    echo $cmd #state the command
    log $cmd >> $OUT
    eval $cmd #execute the command
    cmd="${FREESURFER_HOME}/bin/mri_extract_largest_CC \
            -T 1 \
            ${outputDir}/lh.tmp_cort_mask.nii.gz \
            ${outputDir}/lh.tmp_cort_mask.nii.gz \
        "     
    echo $cmd #state the command
    log $cmd >> $OUT
    eval $cmd #execute the command

    cmd="${FREESURFER_HOME}/bin/mri_binarize \
            --i ${subjAparcAseg} \
            --min 2000 --max 2999 --binval 1 \
            --o ${outputDir}/rh.tmp_cort_mask.nii.gz \
        "     
    echo $cmd #state the command
    log $cmd >> $OUT
    eval $cmd #execute the command
    cmd="${FREESURFER_HOME}/bin/mri_extract_largest_CC \
            -T 1 \
            ${outputDir}/rh.tmp_cort_mask.nii.gz \
            ${outputDir}/rh.tmp_cort_mask.nii.gz \
        "     
    echo $cmd #state the command
    log $cmd >> $OUT
    eval $cmd #execute the command

    # write out the combined cortical_mask
    cmd="${FREESURFER_HOME}/bin/mris_calc \
            -o ${outputDir}/${subj}_cortical_mask.nii.gz \
            ${outputDir}/lh.tmp_cort_mask.nii.gz \
            add ${outputDir}/rh.tmp_cort_mask.nii.gz \
        "
    echo $cmd
    log $cmd >> $OUT
    eval $cmd

    # remove the tmp
    ls ${outputDir}/?h.tmp_cort_mask.nii.gz && rm ${outputDir}/?h.tmp_cort_mask.nii.gz

fi

####################################################################
####################################################################
# get subcort if does not exist

if [[ ! -e ${outputDir}/${subj}_subcort_mask.nii.gz ]]
then

    # function inputs:
    #   aparc+aseg
    #   out directory
    #   subj variable, to name output files

    # function output files:
    #   ${subj}_subcort_mask.nii.gz
    #   ${subj}_subcort_mask_binv.nii.gz

    get_subcort_frm_aparcAseg \
        ${subjAparcAseg} \
        ${outputDir} \
        ${subj} 

fi

####################################################################
####################################################################
# loop through atlasList again to get rid of extra areas and to add 
# subcortical areas

for atlas in ${atlasList}
do

    atlasOutputDir=${outputDir}/${atlas}/

    if [[ -e ${atlasOutputDir}/${atlas}_rmap.nii.gz ]]
    then
        echo "remapped image already exists."
        continue
    fi

    # extract only the cortex, based on the LUT table
    minVal=$(cat ${atlasOutputDir}/LUT_${atlas}.txt | awk '{print int($1)}' | head -n1)
    maxVal=$(cat ${atlasOutputDir}/LUT_${atlas}.txt | awk '{print int($1)}' | tail -n1)

    # threshold atlas image to min and max label values from the LUT table
    cmd="${FSLDIR}/bin/fslmaths \
            ${atlasOutputDir}/${atlas}.nii.gz \
            -thr ${minVal} -uthr ${maxVal} \
            ${atlasOutputDir}/${atlas}.nii.gz \
            -odt int \
        "
    echo $cmd
    log $cmd >> $OUT
    eval $cmd

    # look at only cortical
    cmd="${FSLDIR}/bin/fslmaths \
            ${atlasOutputDir}/${atlas}.nii.gz \
            -mas ${outputDir}/${subj}_cortical_mask.nii.gz \
            ${atlasOutputDir}/${atlas}.nii.gz \
            -odt int \
        "
    echo $cmd
    log $cmd >> $OUT
    eval $cmd

    ##################    
    #do a quick remap#
    ##################
    # remaps lables to start at 1-(n labels), assumes the LUT is the 
    # simple LUT produced by make_fs_stuff script

    if [[ -n ${py_bin} ]] ; then
        echo "using py given to script"
    else
        py_bin=python
    fi
    # inputs to python script -->
    #  i_file = str(argv[1])
    #  o_file = str(argv[2])
    #  labs_file = str(argv[3])
    cmd="${py_bin} ${scriptBaseDir}/src/maTT_remap.py \
            ${atlasOutputDir}/${atlas}.nii.gz \
            ${atlasOutputDir}/${atlas}_rmap.nii.gz \
            ${atlasOutputDir}/LUT_${atlas}.txt \
        "
    echo $cmd
    log $cmd >> $OUT
    eval $cmd

    ########################################
    #add the subcortical areas relabled way#
    ########################################

    # remove any stuff in area of subcortical (shouldnt be there anyways...)
    cmd="${FSLDIR}/bin/fslmaths \
            ${atlasOutputDir}/${atlas}_rmap.nii.gz \
            -mas ${outputDir}/${subj}_subcort_mask_binv.nii.gz \
            ${atlasOutputDir}/${atlas}_rmap.nii.gz \
            -odt int \
        "
    echo $cmd
    log $cmd >> $OUT
    eval $cmd

    # get the max value from cortical atlas image
    # maxCortical=$(fslstats ${atlasOutputDir}/${atlas}_rmap.nii.gz -R | awk '{print int($2)}')
    maxCortical=$(wc -l ${atlasOutputDir}/LUT_${atlas}.txt | awk '{print int($1)}')
    # add the max value to subcort, theshold out areas that should be 0
    cmd="${FSLDIR}/bin/fslmaths \
            ${outputDir}/${subj}_subcort_mask.nii.gz \
            -add ${maxCortical} \
            -thr $(( ${maxCortical} + 1 ))
            ${atlasOutputDir}/${subj}_subcort_mask_${atlas}tmp.nii.gz \
            -odt int \
        "
    echo $cmd
    log $cmd >> $OUT
    eval $cmd

    # add in the re-numbered subcortical
    cmd="${FSLDIR}/bin/fslmaths \
            ${atlasOutputDir}/${atlas}_rmap.nii.gz \
            -add ${atlasOutputDir}/${subj}_subcort_mask_${atlas}tmp.nii.gz \
            ${atlasOutputDir}/${atlas}_rmap.nii.gz \
            -odt int \
        "
    echo $cmd
    log $cmd >> $OUT
    eval $cmd

    # remove temp files
    ls ${atlasOutputDir}/${subj}_subcort_mask_${atlas}tmp.nii.gz && rm ${atlasOutputDir}/${subj}_subcort_mask_${atlas}tmp.nii.gz 

done

# delete extra stuff
# the temp fsDirectory we setup at very beginning
ls -d ${outputDir}/tmpFsDir/ && rm -r ${outputDir}/tmpFsDir/

} # main

# source the funcs
source ${scriptBaseDir}/src/maTT_funcs.sh

####################################################################
####################################################################

# run main with input args from shell scrip call
main "$@"



