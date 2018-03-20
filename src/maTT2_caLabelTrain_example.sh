#!/bin/bash

<<'COMMENT'
josh faskowitz
Indiana University
Computational Cognitive Neurosciene Lab

Copyright (c) 2018 Josh Faskowitz
See LICENSE file for license
COMMENT

# an example script that shows how the GCS files were trained, 
# given the subject annot files created with the maTT label 
# transfer workflow. 
#
# this will have to be edited to use on one's own system

# setup fsl stuffs
export FSLDIR=/somewhere/programs/fsl/
source ${FSLDIR}/etc/fslconf/fsl.sh

# setup fs stuffs
module load freesurfer/5.3.0

export atlasBaseDir=/somewhere/atlas_data/
export atlas_list="gordon333 nspn500 yeo17 hcp-mmp schaefer100-yeo17 schaefer200-yeo17 schaefer400-yeo17 schaefer600-yeo17 schaefer800-yeo17 schaefer1000-yeo17"

####################################################################
####################################################################

#101 subjects
SUBJECT=($(cat /somewhere/mindboggle/subject_list.txt))

workingDir=/somewhere/mindboggle/ca_training_FS5p3/
mkdir -p $workingDir

#go into the folder where the script should be run
cd $workingDir
echo "CHANGING DIRECTORY into $workingDir"

OUT=notes.txt
touch $OUT
PRINT_LOG_HEADER_DUDE $OUT

start=`date +%s`

export SUBJECTS_DIR=/somewhere/mindboggle/FS_5p3/

###############################################################################
# first copy over all of the FreeSurfer subject into fake dir

mkdir -p ${workingDir}/fake_fs_dir/

for (( idx=0 ; idx < ${#SUBJECT[@]} ; idx++ ))
do
    realFSDir=${SUBJECTS_DIR}/${SUBJECT[idx]}/
    cp -asv ${realFSDir} ${workingDir}/fake_fs_dir/${SUBJECT[idx]}/
done

# and copy over a fsaverage for good measure
cp -asv ${FREESURFER_HOME}/subjects/fsaverage ${workingDir}/fake_fs_dir/

###############################################################################
# now link all the annot files into the fake fs dirs

for atlas in ${atlas_list}
do

    echo "linking over atlas: ${atlas}"

    for (( idx=0 ; idx < ${#SUBJECT[@]} ; idx++ ))
    do

        atlasFitDir=/somewhere/maTT_label_trnsfr_FS5p3/${SUBJECT[idx]}/${atlas}/

        # LH
        ls ${atlasFitDir}/lh.${SUBJECT[idx]}_${atlas}.annot && \
            ln -s ${atlasFitDir}/lh.${SUBJECT[idx]}_${atlas}.annot \
            ${workingDir}/fake_fs_dir/${SUBJECT[idx]}/label/lh.${atlas}.annot

        # RH
        ls ${atlasFitDir}/rh.${SUBJECT[idx]}_${atlas}.annot && \
            ln -s ${atlasFitDir}/rh.${SUBJECT[idx]}_${atlas}.annot \
            ${workingDir}/fake_fs_dir/${SUBJECT[idx]}/label/rh.${atlas}.annot

    done

done

###############################################################################
# call the ca_train

export SUBJECTS_DIR=${workingDir}/fake_fs_dir/

for atlas in ${atlas_list}
do

    for hemi in lh rh
    do
        
        # if output already exists...skip
        if [[ -e ${workingDir}/${hemi}.${atlas}.gcs ]]
        then
            echo "already done, moving on!"
        else
            cmd="${FREESURFER_HOME}/bin/mris_ca_train \
                    -t ${atlasBaseDir}/${atlas}/${hemi}.${atlas}_colortab.txt \
                    ${hemi} \
                    sphere.reg \
                    ${atlas} \
                    $(echo ${SUBJECT[@]}) \
                    ${workingDir}/${hemi}.${atlas}.gcs
                "
            echo $cmd 
            log $cmd 
            eval $cmd | tee -a ${OUT} 
        fi

    done
done


end=`date +%s`
runtime=$((end-start))
echo "runtime: $runtime"
log "runtime: $runtime" >> $OUT









