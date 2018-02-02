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
#
# inputFSDir=$1 --> input freesurfer directory
# outputDir=$2 ---> output directory, will also write temporary 
#                   files here 
# refBrain=$3 ----> file to be used as reference when transfering 
#                   aparc+aseg.mgz to orginal (native) space.
# numThread=$4 ---> number of parallel processes to use when doing
#                   the label transfer
#
####################################################################
####################################################################
# define main function here, and then call it at the end

main() 
{

####################################################################
####################################################################

start=`date +%s`

#Check the number of arguments. If none are passed, print help and exit.
NUMARGS=$#
if [ $NUMARGS -lt 2 ]; then
	echo "Not enough args"
    echo "Usage: $0 (input FreeSurfer dir) (output dir) opt(reference brain) opt(num parallel threads)"
	exit 1
fi

####################################################################
####################################################################
# handling input

inputFSDir=$1
outputDir=$2
refBrain=$3
numThread=$4

# make full path, add forward slash too
inputFSDir=$(readlink -f ${inputFSDir})/
outputDir=${outputDir}/

# check inputs
if [[ ! -d ${inputFSDir} ]]
then 
    echo "input FS directory does not exits. exiting"
    exit 1
fi

if [[ -z ${refBrain} ]] || [[ ${refBrain} == 'rawavg' ]]
then
    refBrain=${inputFSDir}/mri/rawavg.mgz
elif [[ ! -z ${refBrain} ]] && [[ ! -f ${refBrain} ]]
then
    echo "not good ref brain"
    exit 1
fi

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

####################################################################
####################################################################
# setup note-taking

mkdir -p ${outputDir}/ || \
    { echo "could not make output dir. exiting" ; exit 1 ; } 
subj=$(basename $inputFSDir)
OUT=${outputDir}/notes.txt
touch $OUT

# also make this a full path
outputDir=$(readlink -f ${outputDir})/

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
        echo "cannot find the atlas_data. please set and retry"
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

other_scripts="maTT_labelTrnsfr.sh maTT_remap.py"
for script in ${other_scripts}
do

    if [[ ! -e ${PWD}/${script} ]] || [[ ! -e ${scriptBaseDir}/${script} ]]
    then
        echo "need the other script, ${script} for this to work"
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

# and this, reset SUJECTS_DIR
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

    # initialize the subcort image, should make blank image
    cmd="${FSLDIR}/bin/fslmaths \
            ${outputDir}/${subj}_aparc+aseg.nii.gz \
            -thr 0 -uthr 0 -bin \
            ${outputDir}/${subj}_subcort_mask.nii.gz \
            -odt int \
        "
    echo $cmd #state the command
    log $cmd >> $OUT
    eval $cmd #execute the command

    ## now add the subcort 
    # the fs_lables correspond to labes in the image FS outputs
    fs_labels=( 10 11 12 13 17 18 26 49 50 51 52 53 54 58 )
    # 10: Left-Thalamus-Proper
    # 11: Left-Caudate 
    # 12: Left-Putamen
    # 13: Left-Pallidum 
    # 17: Left-Hippocampus
    # 18: Left-Amygdala
    # 26: Left-Accumbens-area
    # 49: Right-Thalamus-Proper
    # 50: Right-Caudate 
    # 51: Right-Putamen
    # 52: Right-Pallidum 
    # 53: Right-Hippocampus
    # 54: Right-Amygdala
    # 58: Right-Accumbens-area
    new_index=( 1 2 3 4 5 6 7 8 9 10 11 12 13 14 )
    for (( x=0 ; x<14; x++ ))
    do

        get_label=${fs_labels[x]}
        get_index=${new_index[x]}

        cmd="${FSLDIR}/bin/fslmaths \
                ${outputDir}/${subj}_aparc+aseg.nii.gz \
		        -thr ${get_label} -uthr ${get_label} \
                -binv \
                ${outputDir}/${subj}temp${get_index}.nii.gz"		
        echo $cmd #state the command
        log $cmd >> $OUT
        eval $cmd #execute the command

        ### first lets make sure that there is nothhing in this subcort area
        cmd="${FSLDIR}/bin/fslmaths \
                ${outputDir}/${subj}_subcort_mask.nii.gz \
		        -mas ${outputDir}${subj}temp${get_index}.nii.gz \
		        ${outputDir}/${subj}_subcort_mask.nii.gz \
            "
        echo $cmd #state the command
        log $cmd >> $OUT
        eval $cmd #execute the command

        ### reverse the label now 
        cmd="${FSLDIR}/bin/fslmaths \
                ${outputDir}/${subj}temp${get_index}.nii.gz \
                -binv \
		        -mul ${get_index} \
		        ${outputDir}/${subj}temp${get_index}.nii.gz"		
        echo $cmd #state the command
        log $cmd >> $OUT
        eval $cmd #execute the command
        
        ### add to subcort mask image now
        cmd="${FSLDIR}/bin/fslmaths \
		        ${outputDir}/${subj}_subcort_mask.nii.gz \
		        -add ${outputDir}${subj}temp${get_index}.nii.gz \
		        ${outputDir}/${subj}_subcort_mask.nii.gz \
                -odt int \
            "
        echo $cmd
        log $cmd >> $OUT
        eval $cmd
    done
    
    # and make inverted binary mask
    cmd="${FSLDIR}/bin/fslmaths \
	        ${outputDir}/${subj}_subcort_mask.nii.gz \
	        -binv \
	        ${outputDir}/${subj}_subcort_mask_binv.nii.gz \
            -odt int \
        "
    echo $cmd
    log $cmd >> $OUT
    eval $cmd    

    ls ${outputDir}${subj}temp*.nii.gz && rm ${outputDir}${subj}temp*.nii.gz

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
    ln ${atlasBaseDir}/${atlas}/lh.${atlas}.annot ${fsAvg}/label/lh.${atlas}.annot
    ln ${atlasBaseDir}/${atlas}/rh.${atlas}.annot ${fsAvg}/label/rh.${atlas}.annot

    # make fake list
    echo "${subj}" > ${atlasOutputDir}/temp_list.txt

    # this is the mapping script
    cmd="${scriptBaseDir}/maTT_labelTrnsfr.sh \
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
    cmd="python2.7 ${scriptBaseDir}/maTT_remap.py \
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

    # remove any stuff in area of subcortical (should be there anyways...)
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

    # add in the re-numbers subcortical
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
        
        # inputs to function
        #  i_cort=$1
        #  i_cort_mask=$2
        #  i_subcort_mask=$3
        #  tmpDir=$4
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

##########################################################
##########################################################
# FUNCTIONS

log() 
{
    local msg="$*"
    local dateTime=`date`
    echo "# "$dateTime "-" $log_toolName "-" "$msg"
    echo "$msg"
    echo 
}

dilate_cortex()
{

    i_cort=$1
    i_cort_mask=$2
    i_subcort_mask=$3
    tmpDir=$4

    # make temp subcort invert
    cmd="${FSLDIR}/bin/fslmaths \
	        ${i_subcort_mask}  \
	        -binv \
	        ${tmpDir}/subcort_mask_inv_tmp.nii.gz \
            -odt int \
        "
    echo $cmd
    eval $cmd

    # mask out the subcort, keep temp copy
    cmd="${FSLDIR}/bin/fslmaths \
		    ${i_cort} \
		    -mas ${i_subcort_mask} \
            ${tmpDir}/subcort_tmp.nii.gz \
            -odt int \
        "
    echo $cmd
    eval $cmd

    #get cortical parcellation without subcort
    cmd="${FSLDIR}/bin/fslmaths \
		    ${i_cort} \
		    -mas ${tmpDir}/subcort_mask_inv_tmp.nii.gz \
            ${tmpDir}/cort_tmp.nii.gz \
            -odt int \
        "
    echo $cmd
    eval $cmd

    ##########################################################
    # dilate the cortex and then mask with cortical ribbon...
    # this step is done to make sure cortical ribbon is filled

    #dilate tmp cort
    cmd="atlas_dilate \
            ${tmpDir}/cort_tmp.nii.gz \
            ${tmpDir}/cort_tmp2.nii.gz \
        "
    echo $cmd
    eval $cmd

    # check if the dilate step worked
    if [[ ! -e ${tmpDir}/cort_tmp2.nii.gz ]]
    then
        return 1
    fi

    # mask this by the cortical mask
    cmd="${FSLDIR}/bin/fslmaths \
		    ${tmpDir}/cort_tmp2.nii.gz \
		    -mas ${i_cort_mask} \
            ${tmpDir}/cort_tmp2.nii.gz \
            -odt int \
        "
    echo $cmd
    eval $cmd

    #remove any area that went into subcort
    #and add back in cort
    cmd="${FSLDIR}/bin/fslmaths \
		    ${tmpDir}/cort_tmp2.nii.gz \
		    -mas ${tmpDir}/subcort_mask_inv_tmp.nii.gz \
            -add ${tmpDir}/subcort_tmp.nii.gz \
            ${i_cort} \
            -odt int \
        "
    echo $cmd
    eval $cmd

    #remove extra stuff that was created
    ls ${tmpDir}/subcort_tmp.nii.gz && rm ${tmpDir}/subcort_tmp.nii.gz
    ls ${tmpDir}/cort_tmp.nii.gz && rm ${tmpDir}/cort_tmp.nii.gz
    ls ${tmpDir}/cort_tmp2.nii.gz && rm ${tmpDir}/cort_tmp2.nii.gz
    ls ${tmpDir}/subcort_mask_inv_tmp.nii.gz && rm ${tmpDir}/subcort_mask_inv_tmp.nii.gz

}

####################################################################
####################################################################

# run main with input args from shell scrip call
main "$@"


