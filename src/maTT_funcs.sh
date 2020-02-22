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

    if [[ -n ${py_bin} ]] ; then
        echo "using py given to script"
    else
        py_bin=python
    fi
    # instead, just remap
    # inputs to python script -->
    #  i_file = str(argv[1])
    #  o_file = str(argv[2])
    #  labs_file = str(argv[3])
    cmd="${py_bin} ${scriptBaseDir}/src/maTT_remap.py \
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

make_annot_stats()
{

    local annot=$1 # a path to a file
    local inFsDir=$2 # path to a dir
    local inHemi=$3 # string 
    local outDir=$4 # path to a dir
    local annotName=$5 # string

    cmd="${FREESURFER_HOME}/bin/mris_anatomical_stats \
            -cortex ${inFsDir}/label/${inHemi}.cortex.label
            -f ${outDir}/tmp.stats \
            -b \
            -a ${annot} \
            $(basename $inFsDir) ${inHemi} white \
        "
    echo $cmd #state the command
    eval $cmd #execute the command

    # only retain the rows with stats info
    cat ${outDir}/tmp.stats | \
        grep "ColHeaders" | \
        sed 's,^#\s,,' > ${outDir}/tmp2.stats
    # output all non-header columns to the file
    grep "^[^#;]" ${outDir}/tmp.stats >> ${outDir}/tmp2.stats
    # make into csv
    cat ${outDir}/tmp2.stats | \
            sed 's/\s/,/g' | \
            sed 's/,\{2,\}/,/g' | \
            sed 's/^,//' > ${outDir}/${inHemi}.${annotName}.stats.csv

    # remove the tmp stats
    ls ${outDir}/tmp2.stats && rm ${outDir}/tmp2.stats
    # rename the original output 
    mv ${outDir}/tmp.stats ${outDir}/${inHemi}.${annotName}.stats.tab

}

##########################################################

make_seg_stats()
{

    local inSeg=$1 # path to nifti
    local outDir=$2 # path to a dir
    local annotName=$3 # string

    cmd="${FREESURFER_HOME}/bin/mri_segstats \
            --seg $inSeg \
            --excludeid 0 \
            --sum ${outDir}/tmp.stats \
        "
    echo $cmd 
    eval $cmd

    # only retain the rows with stats info
    cat ${outDir}/tmp.stats | \
        grep "ColHeaders" | \
        sed 's,^#\s,,' > ${outDir}/tmp2.stats
    # output all non-header columns to the file
    grep "^[^#;]" ${outDir}/tmp.stats >> ${outDir}/tmp2.stats
    # make into csv
    cat ${outDir}/tmp2.stats | \
            sed 's/\s/,/g' | \
            sed 's/,\{2,\}/,/g' | \
            sed 's/^,//' > ${outDir}/${annotName}.segvol.csv

    # remove the tmp stats
    ls ${outDir}/tmp2.stats && rm ${outDir}/tmp2.stats
    # rename the original output 
    mv ${outDir}/tmp.stats ${outDir}/${annotName}.segvol.tab

}

##########################################################

make_seg_coords()
{
    
    local inputVol=$1
    local inputMask=$2
    local outputDir=$3
    local annotName=$4

    for coordStyle in mm # vox
    do

        if [[ ${coordStyle}=='mm' ]]
        then
            fslstatCmd="-c"
        else
            fslstatCmd="-C"
        fi

        #get the center of gravity stuff...
        # in voxel coords
        cmd="${FSLDIR}/bin/fslstats \
                -K ${inputVol} ${inputVol} \
                ${fslstatCmd} \
                -k ${inputMask} 2>/dev/null \
            "
        echo $cmd
        log $cmd >> $OUT
        tmpRes=$(eval $cmd)
        
        #save the results temp
        for x in $tmpRes ; do echo ${x} ; 
        done | pr -ts"," --columns 3 --across > ${outputDir}/temp_coords_1.txt

        cmd="${FSLDIR}/bin/fslstats \
                -K ${inputVol} ${inputVol} \
                -M \
                -k ${inputMask} 2>/dev/null \
            "
        echo $cmd
        log $cmd >> $OUT
        imgIndex=$(eval $cmd)

        for x in $imgIndex ; do echo ${x} ; 
        done | pr -ts"," --columns 1 --across > ${outputDir}/temp_indicies_1.txt

        # vertical concat
        paste -d "," ${outputDir}/temp_indicies_1.txt ${outputDir}/temp_coords_1.txt > ${outputDir}/temp_coords_2.txt
        
        #add line numbers 
        awk -F',' -v OFS="," '{print NR,int($1),$2,$3,$4}' ${outputDir}/temp_coords_2.txt > ${outputDir}/${annotName}_coords_${coordStyle}.csv

    done # in mm vox

    #####################
    # now remove stuff
    ls ${outputDir}/temp_*.txt && rm ${outputDir}/temp_*.txt

}

##########################################################
