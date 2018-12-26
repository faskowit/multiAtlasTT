#!/bin/bash

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

##########################################################

get_subcort_frm_aparcAseg()
{
    # inputs
    local iAparcAseg=$1
    local oDir=$2
    local subj=$3

    ## now add the subcort 
    # the fs_lables correspond to labes in the image FS outputs
    local fsLabels=( 10 11 12 13 17 18 26 49 50 51 52 53 54 58 )
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

    cmd="${FREESURFER_HOME}/bin/mri_binarize \
            --i ${iAparcAseg} \
            --match ${fsLabels[@]} --binval 1 --binvalnot 0 \
            --o ${oDir}/${subj}temp_subcort_mask1.nii.gz \
        "        
    echo $cmd #state the command
    log $cmd >> $OUT
    eval $cmd #execute the command

    # make inverse while we're at it
    cmd="${FREESURFER_HOME}/bin/mri_binarize \
            --i ${iAparcAseg} \
            --match ${fsLabels[@]} --binval 0 --binvalnot 1 \
            --o ${oDir}/${subj}_subcort_mask_binv.nii.gz \
        "        
    echo $cmd #state the command
    log $cmd >> $OUT
    eval $cmd #execute the command

    cmd="${FREESURFER_HOME}/bin/mri_mask \
            ${iAparcAseg} \
            ${oDir}/${subj}temp_subcort_mask1.nii.gz \
            ${oDir}/${subj}temp_subcort_mask2.nii.gz \
        "    
    echo $cmd
    eval $cmd

    #replaceStr=''
    > ${oDir}/${subj}temp_remap_list.txt

    # could use freesurfer func to speed this up lots
    local newIndex=( 1 2 3 4 5 6 7 8 9 10 11 12 13 14 )
    for (( x=0 ; x<14; x++ ))
    do

        getLabel=${fsLabels[x]}
        getIndex=${newIndex[x]}
        #replaceStr="${replaceStr} --replace ${getLabel} ${getIndex}"
        echo "$getLabel FreeSurferAsegRegion${getLabel}" >> ${oDir}/${subj}temp_remap_list.txt

    done

    # --replace is only in freesurfer 6.0... so lets not use it.
    #cmd="${FREESURFER_HOME}/bin/mri_binarize \
    #        --i ${oDir}/${subj}temp_subcort_mask2.nii.gz \
    #        ${replaceStr} \
    #        --o ${oDir}/${subj}_subcort_mask.nii.gz \
    #    "        
    #echo $cmd #state the command
    #log $cmd >> $OUT
    #eval $cmd #execute the command

    # instead, just remap
    # inputs to python script -->
    #  i_file = str(argv[1])
    #  o_file = str(argv[2])
    #  labs_file = str(argv[3])
    cmd="python2.7 ${scriptBaseDir}/src/maTT_remap.py \
            ${oDir}/${subj}temp_subcort_mask2.nii.gz \
            ${oDir}/${subj}_subcort_mask.nii.gz \
            ${oDir}/${subj}temp_remap_list.txt \
        "
    echo $cmd
    log $cmd >> $OUT
    eval $cmd        

    # remove flotsum
    ls ${oDir}/${subj}temp* && rm ${oDir}/${subj}temp*

}

##########################################################

dilate_cortex()
{

    local iCort=$1
    local iCortMask=$2
    local iSubcortMask=$3
    local tmpDir=$4

    # make temp subcort invert
    #cmd="${FSLDIR}/bin/fslmaths \
	#        ${iSubcortMask}  \
	#        -binv \
	#        ${tmpDir}/subcort_mask_inv_tmp.nii.gz \
    #        -odt int \
    #    "
    cmd="${FREESURFER_HOME}/bin/mri_binarize \
            --i ${iSubcortMask} \
            --min 1 --inv \
            --o ${tmpDir}/subcort_mask_inv_tmp.nii.gz \
        "        
    echo $cmd
    eval $cmd

    # mask out the subcort, keep temp copy
    #cmd="${FSLDIR}/bin/fslmaths \
	#	    ${iCort} \
	#	    -mas ${iSubcortMask} \
    #        ${tmpDir}/subcort_tmp.nii.gz \
    #        -odt int \
    #    "
    cmd="${FREESURFER_HOME}/bin/mri_mask \
            ${iCort} ${iSubcortMask} ${tmpDir}/subcort_tmp.nii.gz \
        "
    echo $cmd
    eval $cmd

    #get cortical parcellation without subcort
    #cmd="${FSLDIR}/bin/fslmaths \
	#	    ${iCort} \
	#	    -mas ${tmpDir}/subcort_mask_inv_tmp.nii.gz \
    #        ${tmpDir}/cort_tmp.nii.gz \
    #        -odt int \
    #    "
    cmd="${FREESURFER_HOME}/bin/mri_mask \
            ${iCort} ${tmpDir}/subcort_mask_inv_tmp.nii.gz \
            ${tmpDir}/cort_tmp.nii.gz \
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
    #cmd="${FSLDIR}/bin/fslmaths \
	#	    ${tmpDir}/cort_tmp2.nii.gz \
	#	    -mas ${iCortMask} \
    #        ${tmpDir}/cort_tmp2.nii.gz \
    #        -odt int \
    #    "
    cmd="${FREESURFER_HOME}/bin/mri_mask \
            ${tmpDir}/cort_tmp2.nii.gz ${iCortMask} \
            ${tmpDir}/cort_tmp2.nii.gz \
        "      
    echo $cmd
    eval $cmd

    #remove any area that went into subcort
    #and add back in cort
    #cmd="${FSLDIR}/bin/fslmaths \
	#	    ${tmpDir}/cort_tmp2.nii.gz \
	#	    -mas ${tmpDir}/subcort_mask_inv_tmp.nii.gz \
    #        -add ${tmpDir}/subcort_tmp.nii.gz \
    #        ${iCort} \
    #        -odt int \
    #    "
    cmd="${FREESURFER_HOME}/bin/mri_mask \
            ${tmpDir}/cort_tmp2.nii.gz ${tmpDir}/subcort_mask_inv_tmp.nii.gz \
            ${tmpDir}/cort_tmp2.nii.gz \
        "      
    echo $cmd
    eval $cmd

    cmd="${FREESURFER_HOME}/bin/mris_calc \
            --output ${iCort} \
            ${tmpDir}/cort_tmp2.nii.gz \
            add ${tmpDir}/subcort_tmp.nii.gz \           
        "     
    echo $cmd
    eval $cmd  

    #remove extra stuff that was created
    ls ${tmpDir}/subcort_tmp.nii.gz && rm ${tmpDir}/subcort_tmp.nii.gz
    ls ${tmpDir}/cort_tmp.nii.gz && rm ${tmpDir}/cort_tmp.nii.gz
    ls ${tmpDir}/cort_tmp2.nii.gz && rm ${tmpDir}/cort_tmp2.nii.gz
    ls ${tmpDir}/subcort_mask_inv_tmp.nii.gz && rm ${tmpDir}/subcort_mask_inv_tmp.nii.gz

}


##########################################################

