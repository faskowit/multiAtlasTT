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
# this script should fit multiple atlases to data given as a 
# freesurfer directory. when calling this script, need to define the
# a few global variables (below). Also should have FreeSurfer, FSL 
# and easy_lausanne* setup/installed before calling this script
#
# https://github.com/mattcieslak/easy_lausanne
#
####################################################################
####################################################################
#
# vars that this script would like exported in, via 'export=' 
#   atlasBaseDir
#   scriptBaseDir
#   atlasList
#
####################################################################
####################################################################

help_usage() 
{
cat <<helpusagetext

USAGE: ${0} 
        -d          inputFSDir --> input freesurfer directory
        -o          outputDir ---> output directory, will also write temporary 
                        files here 
        -r (opt)    refBrain ----> file to be used as reference transforming 
                        aparc+aseg.mgz out of FS conformed space (default=rawavg) 
        -n (opt)    numThread ---> number of parallel processes to use when doing
                        the label transfer (default=4)
helpusagetext
}

usage() 
{
cat <<usagetext

USAGE: ${0} 
        -d          inputFSDir 
        -o          outputDir 
        -r (opt)    refBrain 
        -n (opt)    numThread 
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
if [ $NUMARGS -lt 2 ]; then
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
		r)
			refBrain=$OPTARG
			;;
		n)
			numThread=$OPTARG
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

# check reference brain if set
if [[ -z ${refBrain} ]] || [[ ${refBrain} == 'rawavg' ]]
then
    refBrain=${inputFSDir}/mri/rawavg.mgz
elif [[ ! -z ${refBrain} ]] && [[ ! -f ${refBrain} ]]
then
    echo "not good ref brain"
    exit 1
fi

# check number threads to use
if [[ -z ${numThread} ]]
then 
    N=4
else
    if ! [[ "${numThread}" =~ ^[0-9]+$ ]]
    then
        echo "numThread, number parallel, needs to be int"
        exit 1
    fi
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

####################################################################
####################################################################
# FreeSurfer Stuff

# setup FS stuff
# specific to the subj
# we will have to reset this later in script ~ line 200 ish
export SUBJECTS_DIR=$(dirname ${inputFSDir})/

####################################################################
####################################################################
# setup stuff related to exported variables and paths

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
    atlasList="gordon333 nspn500 yeo17 hcp-mmp schaefer100-yeo17 schaefer200-yeo17 schaefer400-yeo17 schaefer600-yeo17 schaefer800-yeo17 schaefer1000-yeo17"
else
    echo "using the atlasList exported to this script"
fi

# check the other scripts too
if [[ -z ${scriptBaseDir} ]] 
then
    scriptBaseDir=${PWD}/
fi

other_scripts="/src/maTT_labelTrnsfr.sh /src/maTT_remap.py /src/maTT_funcs.sh"
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
# GET CORTICAL AND SUBCORTICAL IMAGES

# check if we converted the aparc+aseg outta FS space
# then can proceed
if [[ ! -e ${outputDir}/${subj}_aparc+aseg.nii.gz ]]
then

    # convert out of freesurfer space
    cmd="${FREESURFER_HOME}/bin/mri_label2vol \
		    --seg ${inputFSDir}/mri/aparc+aseg.mgz \
		    --temp ${refBrain} \
		    --o ${outputDir}/${subj}_aparc+aseg.nii.gz \
		    --regheader ${inputFSDir}/mri/aparc+aseg.mgz \
		    "
    echo $cmd #state the command
    log $cmd >> $OUT
    eval $cmd #execute the command

fi

# check output
if [[ ! -e ${outputDir}/${subj}_aparc+aseg.nii.gz ]]
then 
    echo "problem reading the fs directory it seems"
    exit 1
else
    echo "read FS directory, has aparc+aseg, good to go"
fi

####################################################################
####################################################################
# setup space on disk to make this all work

mkdir -p ${outputDir}/tmpFsDir/ && \
    cp -asv ${inputFSDir} ${outputDir}/tmpFsDir/${subj}/

# now the input fsDir will be our temporary dir
inputFSDir=${outputDir}/tmpFsDir/${subj}/

# reset SUJECTS_DIR to the new inputFSDir
export SUBJECTS_DIR=${outputDir}/tmpFsDir/

# copy over the fsaverage here
fsAvg=$(dirname ${inputFSDir}/)/fsaverage

# test if we can write into it
fsAvgTmp=''
if [[ -d ${fsAvg} ]] && [[ -w ${fsAvg} ]] 
then
    echo "can write into fs dir... we good"
else
    # if fsAvg dir exists, lets move it out of the way
    if [[ -d ${fsAvg} ]]
    then 
       mv ${fsAvg} ${fsAvg}.bk
    fi

    echo "copying a fsaverage we can modify to here: ${fsAvg}"
    cp -asv ${FREESURFER_HOME}/subjects/fsaverage/ ${fsAvg}/

    fsAvgTmp=${fsAvg}/
fi

# get gm ribbom if does not exits
if [[ ! -e ${outputDir}/${subj}_cortical_mask.nii.gz ]]
then

    cmd="${FSLDIR}/bin/fslmaths \
	        ${outputDir}/${subj}_aparc+aseg.nii.gz \
	        -thr 1000 -bin \
            ${outputDir}/${subj}_cortical_mask.nii.gz \
            -odt int \
        "
    echo $cmd #state the command
    log $cmd >> $OUT
    eval $cmd #execute the command

fi

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
        ${outputDir}/${subj}_aparc+aseg.nii.gz \
        ${outputDir} \
        ${subj} 

fi

####################################################################
####################################################################
# NOW DO THE MAPPING

for atlas in ${atlasList}
do

    atlasOutputDir=${outputDir}/${atlas}/
    mkdir -p ${atlasOutputDir}

    # if atlas already exists
    if [[ -e ${atlasOutputDir}/${atlas}_rmap.nii.gz ]]
    then
        echo "looks like already made: ${atlasOutputDir}/${atlas}_rmap.nii.gz"
        echo "will skip"
        continue
    fi

    # first, link the atlas we currently looking at to the fsavergae
    ln -s ${atlasBaseDir}/${atlas}/lh.${atlas}.annot ${fsAvg}/label/lh.${atlas}.annot
    ln -s ${atlasBaseDir}/${atlas}/rh.${atlas}.annot ${fsAvg}/label/rh.${atlas}.annot

    # make fake list
    echo "${subj}" > ${atlasOutputDir}/temp_list.txt

    # this is the mapping script
    cmd="${scriptBaseDir}/src/maTT_labelTrnsfr.sh \
            -d ${atlasOutputDir}/labtemp/ \
            -a ${atlas} \
            -L ${atlasOutputDir}/temp_list.txt \
            -n ${numThread} \
        "
    echo $cmd
    log $cmd >> $OUT
    eval $cmd

    # check job status of mapping and quit if not good
    if [[ $? -ne 0 ]]
    then
        echo "label transfer mapping seems to have failed. quitting"
        exit 1
    fi

    # before removing all the crap...keep some important stuff
    # the atlas volume
    mv ${atlasOutputDir}/labtemp/${subj}/${atlas}.nii.gz ${atlasOutputDir}/${atlas}.nii.gz
    # the LUT
    mv ${atlasOutputDir}/labtemp/${subj}/LUT_${atlas}.txt ${atlasOutputDir}/LUT_${atlas}.txt
    # the colortables
    mv ${atlasOutputDir}/labtemp/${subj}/colortab_${atlas}_? ${atlasOutputDir}/
    # the logs
    mv ${atlasOutputDir}/labtemp/${subj}/*log* ${atlasOutputDir}/
    # the annot files
    cp ${inputFSDir}/label/?h.${subj}_${atlas}.annot ${atlasOutputDir}/

    # remove the temporary labtemp dir
    ls -d ${atlasOutputDir}/labtemp/ && rm -r ${atlasOutputDir}/labtemp/
    rm ${atlasOutputDir}/temp_list.txt

    #TODO make a better remap function...
    #TODO make a function to condition output aparc+aseg into only cort label stuff

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

    # move atlas from freesurfer conformed ---> native space
    cmd="${FREESURFER_HOME}/bin/mri_vol2vol \
            --mov ${atlasOutputDir}/${atlas}.nii.gz \
            --targ ${inputFSDir}/mri/rawavg.mgz \
            --regheader \
            --o ${atlasOutputDir}/${atlas}.nii.gz \
            --no-save-reg --nearest \
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

    # inputs to python script -->
    #  i_file = str(argv[1])
    #  o_file = str(argv[2])
    #  labs_file = str(argv[3])
    cmd="python2.7 ${scriptBaseDir}/src/maTT_remap.py \
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
    maxCortical=$(fslstats ${atlasOutputDir}/${atlas}_rmap.nii.gz -R | awk '{print int($2)}')
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

    ##########################################################
    #finally, lets condition the parcels based on grey matter#
    ##########################################################

    ## but only do if the function is available...
    if [[ $(which ${scriptBaseDir}/atlas_dilate) ]] || [[ $(which atlas_dilate) ]]
    then    

        # because sometimes the mapping to the grey matter does not fill the cortical
        # ribbon, lets dilate the labels to fill this ribbon

        # initialize tmpDir
        mkdir -p ${atlasOutputDir}/tmpDilDir/
        
        # function inputs
        #   i_cort=$1
        #   i_cort_mask=$2
        #   i_subcort_mask=$3
        #   tmpDir=$4

        # function output files:
        #   none (replaces i_cort with dilated version of i_cort)
        
        dilate_cortex \
            ${atlasOutputDir}/${atlas}_rmap.nii.gz \
            ${outputDir}/${subj}_cortical_mask.nii.gz \
            ${outputDir}/${subj}_subcort_mask.nii.gz \
            ${atlasOutputDir}/tmpDilDir/
     
        if [[ $? -ne 0 ]]
        then
            echo "seems like cortex did not dilate properly"
            exit 1
        fi

        # remove temporary mess (should just be empty dir)
        rmdir ${atlasOutputDir}/tmpDilDir/
    
    else
        echo "did not dilate atlas within cortex"
        echo "resulting atlas might not fill cortical ribbon"
    fi

done # loop through atlas list

# lets remove the temp fsaverage dir we made
# and move other back, if the bk dir is ther
if [[ -d ${fsAvg}.bk ]]
then
    ls -d ${fsAvg} && rm -r ${fsAvg} \
        && mv ${fsAvg}.bk ${fsAvg} 
fi

if [[ ! -z ${fsAvgTmp} ]]
then
    ls -d ${fsAvgTmp} && rm -r ${fsAvgTmp}
fi

if [[ -d ${outputDir}/tmpFsDir ]]
then 
    ls -d ${outputDir}/tmpFsDir && rm -r ${outputDir}/tmpFsDir
fi

# record how long that all took
end=`date +%s`
runtime=$((end-start))
echo "runtime: $runtime"
log "runtime: $runtime" >> $OUT 2>/dev/null

} # main 

# source the funcs
source ${scriptBaseDir}/src/maTT_funcs.sh

####################################################################
####################################################################

# run main with input args from shell scrip call
main "$@"


