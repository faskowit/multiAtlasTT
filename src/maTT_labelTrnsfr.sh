#!/bin/bash

<<'COMMENT'
josh faskowitz
Indiana University
Computational Cognitive Neurosciene Lab

Copyright (c) 2018 Josh Faskowitz
See LICENSE file for license
COMMENT

# this script has been adapted from here: 
#   https://cjneurolab.org/2016/11/22/hcp-mmp1-0-volumetric-nifti-masks-in-native-structural-space/
#   https://figshare.com/articles/HCP-MMP1_0_volumetric_NIfTI_masks_in_native_structural_space/4249400
# 
# original script was distriubted under MIT license:
#
# 2017 CJNeurolab University of Barcelona by Hugo C Baggio & Alexandra Abos
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
# documentation files (the "Software"), to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and
# to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of
# the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
# THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
# CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.

# -L subject_list_name
# -a name_of_annotation_file (without hemisphere or extension; in this case, HCPMMP1)
# -d name_of_output_dir (will be created in $SUBJECTS_DIR)

# define compulsory and optional arguments
while getopts ":n:L:f:l:a:d::" o; do
    case "${o}" in
        L)
            L=${OPTARG}
            ;;
        a)
            a=${OPTARG}
            ;;
        d)
            d=${OPTARG}
            ;;
        n)
            N=${OPTARG}
            ;;
    esac
done

if [ -z "${L}" ] || [ -z "${a}" ] || [ -z "${d}" ]
then 
    echo "Usage: $0 -L (subject list) -a (annotation name) -d (output dir) -n opt(number parallel threads)" 
    exit 1 
fi

annotation_file=$a
subject_list_all=$L
output_dir=$d

first=1
last=$(wc -l < ${subject_list_all})

<<<<<<< HEAD
DEBUG="no"
=======
DEBUG="true"
>>>>>>> 81be2afe59017c2a4534fb1a2667444ad03296b5

if [[ -z ${N} ]]
then 
    N=4
else
    if ! [[ "${N}" =~ ^[0-9]+$ ]]
    then
        echo "N, number parallel, needs to be int"
        exit 1
    elif [[ $N -gt 8 ]]
    then
        echo "too many parallel to run"
        exit 1
    fi
fi

############################################################################################
############################################################################################
# Create subject list with subjects defined in the input
sed -n "${first},${last} p" ${subject_list_all} > temp_subject_list_${first}_${last}
subject_list=temp_subject_list_${first}_${last}

mkdir -p ${output_dir}
mkdir -p ${output_dir}/label
mkdir -p ${output_dir}/temp_${first}_${last}
rm -f ${output_dir}/temp_${first}_${last}/colortab_?
rm -f ${output_dir}/temp_${first}_${last}/list_labels_${annotation_file}?

############################################################################################
############################################################################################
# Check whether original annotation files are in fsaverage/label folder, copy them if not
if [ ! -e ${SUBJECTS_DIR}/fsaverage/label/lh.${annotation_file}.annot ] 
then 
    cp lh.${annotation_file}.annot ${SUBJECTS_DIR}/fsaverage/label/
fi
if [ ! -e ${SUBJECTS_DIR}/fsaverage/label/rh.${annotation_file}.annot ] 
then 
    cp rh.${annotation_file}.annot ${SUBJECTS_DIR}/fsaverage/label/
fi

############################################################################################
############################################################################################
# Convert annotation to label, and get color lookup tables
rm -f ${output_dir}/log_annotation2label

${FREESURFER_HOME}/bin/mri_annotation2label --subject fsaverage --hemi lh --outdir ${output_dir}/label --annotation ${annotation_file} >> ${output_dir}/temp_${first}_${last}/log_annotation2label

${FREESURFER_HOME}/bin/mri_annotation2label --subject fsaverage --hemi lh --outdir ${output_dir}/label --annotation ${annotation_file} --ctab ${output_dir}/temp_${first}_${last}/colortab_${annotation_file}_L1 >> ${output_dir}/temp_${first}_${last}/log_annotation2label

${FREESURFER_HOME}/bin/mri_annotation2label --subject fsaverage --hemi rh --outdir ${output_dir}/label --annotation ${annotation_file} >> ${output_dir}/temp_${first}_${last}/log_annotation2label

${FREESURFER_HOME}/bin/mri_annotation2label --subject fsaverage --hemi rh --outdir ${output_dir}/label --annotation ${annotation_file} --ctab ${output_dir}/temp_${first}_${last}/colortab_${annotation_file}_R1 >> ${output_dir}/temp_${first}_${last}/log_annotation2label

############################################################################################
############################################################################################
# Remove number columns from ctab
awk '!($1="")' ${output_dir}/temp_${first}_${last}/colortab_${annotation_file}_L1 >> ${output_dir}/temp_${first}_${last}/colortab_${annotation_file}_L2
awk '!($1="")' ${output_dir}/temp_${first}_${last}/colortab_${annotation_file}_R1 >> ${output_dir}/temp_${first}_${last}/colortab_${annotation_file}_R2

############################################################################################
############################################################################################
# Create list with region names
awk '{print $2}' ${output_dir}/temp_${first}_${last}/colortab_${annotation_file}_L1 > ${output_dir}/temp_${first}_${last}/list_labels_${annotation_file}L1
awk '{print $2}' ${output_dir}/temp_${first}_${last}/colortab_${annotation_file}_R1 > ${output_dir}/temp_${first}_${last}/list_labels_${annotation_file}R1

############################################################################################
############################################################################################
# Create lists with regions that actually have corresponding labels
# LEFT HEMI
for labelsL in `cat ${output_dir}/temp_${first}_${last}/list_labels_${annotation_file}L1`
do 
    if [[ -e ${output_dir}/label/lh.${labelsL}.label ]]
	then
		echo lh.${labelsL}.label >> ${output_dir}/temp_${first}_${last}/list_labels_${annotation_file}L
		grep " ${labelsL} " ${output_dir}/temp_${first}_${last}/colortab_${annotation_file}_L2 >> ${output_dir}/temp_${first}_${last}/colortab_${annotation_file}_L3
	fi
done
# RIGHT HEMI
for labelsR in `cat ${output_dir}/temp_${first}_${last}/list_labels_${annotation_file}R1`
do 
    if [[ -e ${output_dir}/label/rh.${labelsR}.label ]]
    then
		echo rh.${labelsR}.label >> ${output_dir}/temp_${first}_${last}/list_labels_${annotation_file}R
		grep " ${labelsR} " ${output_dir}/temp_${first}_${last}/colortab_${annotation_file}_R2 >> ${output_dir}/temp_${first}_${last}/colortab_${annotation_file}_R3
	fi
done

############################################################################################
############################################################################################
# Create new numbers column
number_labels_R=`wc -l < ${output_dir}/temp_${first}_${last}/list_labels_${annotation_file}R` 
number_labels_L=`wc -l < ${output_dir}/temp_${first}_${last}/list_labels_${annotation_file}L`

for ((i=1;i<=${number_labels_L};i+=1))
do 
    num=`echo "${i}+1000" | bc`
	printf "$num\n" >> ${output_dir}/temp_${first}_${last}/LUT_number_table_${annotation_file}L
	printf "$i\n" >> ${output_dir}/temp_${first}_${last}/${annotation_file}_number_tableL
done
for ((i=1;i<=${number_labels_R};i+=1))
do 
    num=`echo "${i}+2000" | bc`
	printf "$num\n" >> ${output_dir}/temp_${first}_${last}/LUT_number_table_${annotation_file}R
	printf "$i\n" >> ${output_dir}/temp_${first}_${last}/${annotation_file}_number_tableR
done

############################################################################################
############################################################################################
# Create ctabs with actual regions

# LEFT
# initialize with unknown
# edit. NOT GOOD IDEA
#printf "0\tunknown 1 2 5 0\n" > ${output_dir}/temp_${first}_${last}/colortab_${annotation_file}_L
> ${output_dir}/temp_${first}_${last}/colortab_${annotation_file}_L

paste ${output_dir}/temp_${first}_${last}/${annotation_file}_number_tableL ${output_dir}/temp_${first}_${last}/colortab_${annotation_file}_L3 >> ${output_dir}/temp_${first}_${last}/colortab_${annotation_file}_L

paste ${output_dir}/temp_${first}_${last}/LUT_number_table_${annotation_file}L ${output_dir}/temp_${first}_${last}/list_labels_${annotation_file}L > ${output_dir}/temp_${first}_${last}/LUT_left_${annotation_file}

# RIGHT
# initialize with unknown
# edit. NOT GOOD IDEA
#printf "0\tunknown 1 2 5 0\n" > ${output_dir}/temp_${first}_${last}/colortab_${annotation_file}_R
> ${output_dir}/temp_${first}_${last}/colortab_${annotation_file}_R

paste ${output_dir}/temp_${first}_${last}/${annotation_file}_number_tableR ${output_dir}/temp_${first}_${last}/colortab_${annotation_file}_R3 >> ${output_dir}/temp_${first}_${last}/colortab_${annotation_file}_R

paste ${output_dir}/temp_${first}_${last}/LUT_number_table_${annotation_file}R ${output_dir}/temp_${first}_${last}/list_labels_${annotation_file}R > ${output_dir}/temp_${first}_${last}/LUT_right_${annotation_file}

# LUT
# initialize
# edit. NOT GOOD IDEA
#printf "0\tunknown\n" > ${output_dir}/temp_${first}_${last}/LUT_${annotation_file}.txt
> ${output_dir}/temp_${first}_${last}/LUT_${annotation_file}.txt

cat ${output_dir}/temp_${first}_${last}/LUT_left_${annotation_file} ${output_dir}/temp_${first}_${last}/LUT_right_${annotation_file} >> ${output_dir}/temp_${first}_${last}/LUT_${annotation_file}.txt

############################################################################################
############################################################################################
# Take labels from fsaverage to subject space
for subject in $(cat ${subject_list})

	do printf "\n>>>> PREPROCESSING ${subject} <<<< \n"
    echo $subject

	echo $(date) > ${output_dir}/temp_${first}_${last}/start_date
	echo ">>>> START TIME: `cat ${output_dir}/temp_${first}_${last}/start_date` <<<<"
	mkdir -p ${output_dir}/${subject}/label

	if [[ -e ${subject}/label/lh.${subject}_${annotation_file}.annot ]] && [[ -e ${subject}/label/rh.${subject}_${annotation_file}.annot ]]
		then
		echo ">>>> Annotation files lh.${subject}_${annotation_file}.annot and "
        echo "rh.${subject}_${annotation_file}.annot already exist in ${subject}/label."
        echo "Won't perform transformations <<<<"

    else

        # removing files that we'll create
		rm -f ${output_dir}/${subject}/label2annot_${annotation_file}?h.log
		rm -f ${output_dir}/${subject}/log_label2label

		cp ${output_dir}/temp_${first}_${last}/LUT_${annotation_file}.txt ${output_dir}/${subject}/

        ####################################################################################
        ####################################################################################
        # these are the loops where each label is transformed from fsaverage to subject

        # parallelize this section
        # by running these loops in bunches
        # set N as an input

        (
        # RIGHT HEMI
		for label in `cat ${output_dir}/temp_${first}_${last}/list_labels_${annotation_file}R`
		do
            ((i=i%N))
            ((i++==0)) && wait
 
            echo "transforming ${label}"
			${FREESURFER_HOME}/bin/mri_label2label --srcsubject fsaverage --srclabel ${output_dir}/label/${label} --trgsubject ${subject} --trglabel ${output_dir}/${subject}/label/${label}.label --regmethod surface --hemi rh >> ${output_dir}/${subject}/log_label2label & 

            #add pid to list
            pid=$!
            echo $pid >> ${output_dir}/temp_${first}_${last}/pid_list_R.txt

		done 

        # adding another wait
        wait $(cat ${output_dir}/temp_${first}_${last}/pid_list_R.txt) 2> /dev/null

        )


        (
        # LEFT HEMI
		for label in `cat ${output_dir}/temp_${first}_${last}/list_labels_${annotation_file}L`
		do 
            ((i=i%N))
            ((i++==0)) && wait

            echo "transforming ${label}"
			${FREESURFER_HOME}/bin/mri_label2label --srcsubject fsaverage --srclabel ${output_dir}/label/${label} --trgsubject ${subject} --trglabel ${output_dir}/${subject}/label/${label}.label --regmethod surface --hemi lh >> ${output_dir}/${subject}/log_label2label &

            #add pid to list
            pid=$!
            echo $pid >> ${output_dir}/temp_${first}_${last}/pid_list_L.txt

		done

        # adding another wait
        wait $(cat ${output_dir}/temp_${first}_${last}/pid_list_L.txt) 2> /dev/null

        )

        ####################################################################################
        ####################################################################################
		# Convert labels to annot (in subject space)
		rm -f ${output_dir}/temp_${first}_${last}/temp_cat_${annotation_file}_R
		rm -f ${output_dir}/temp_${first}_${last}/temp_cat_${annotation_file}_L

		for labelsR in `cat ${output_dir}/temp_${first}_${last}/list_labels_${annotation_file}R`
		do 

            if [ -e ${output_dir}/${subject}/label/${labelsR} ]
		    then
                echo "adding ${labelsR}"
                printf " --l ${output_dir}/${subject}/label/${labelsR}" >> ${output_dir}/temp_${first}_${last}/temp_cat_${annotation_file}_R
            else
                echo "DID NOT ADD ${labelsR}"
            fi

		done

		for labelsL in `cat ${output_dir}/temp_${first}_${last}/list_labels_${annotation_file}L`
		do 
            if [ -e ${output_dir}/${subject}/label/${labelsL} ]
		    then
                echo "adding ${labelsL}"
                printf " --l ${output_dir}/${subject}/label/${labelsL}" >> ${output_dir}/temp_${first}_${last}/temp_cat_${annotation_file}_L
			else
                echo "DID NOT ADD ${labelsL}"
            fi
		done
	
		${FREESURFER_HOME}/bin/mris_label2annot --s ${subject} --h lh `cat ${output_dir}/temp_${first}_${last}/temp_cat_${annotation_file}_L` --a ${subject}_${annotation_file} --ctab ${output_dir}/temp_${first}_${last}/colortab_${annotation_file}_L >> ${output_dir}/${subject}/label2annot_${annotation_file}lh.log 
		${FREESURFER_HOME}/bin/mris_label2annot --s ${subject} --h rh `cat ${output_dir}/temp_${first}_${last}/temp_cat_${annotation_file}_R` --a ${subject}_${annotation_file} --ctab ${output_dir}/temp_${first}_${last}/colortab_${annotation_file}_R >> ${output_dir}/${subject}/label2annot_${annotation_file}rh.log 

	fi # if annotation files already exist

    ########################################################################################
    ########################################################################################
	# Convert annot to volume
	rm -f ${output_dir}/${subject}/log_aparc2aseg
	${FREESURFER_HOME}/bin/mri_aparc2aseg --s ${subject} --volmask --o ${output_dir}/${subject}/${annotation_file}.nii.gz  --annot ${subject}_${annotation_file} >> ${output_dir}/${subject}/log_aparc2aseg

	echo ">>>> ${subject} STARTED AT `cat ${output_dir}/temp_${first}_${last}/start_date`, "
    echo "ENDED AT: $(date)  <<<<"

done # for subject in subject list

############################################################################################
############################################################################################

# keep color tabs (ctab)
mv ${output_dir}/temp_${first}_${last}/colortab_${annotation_file}_? ${output_dir}/${subject}/
<<<<<<< HEAD
[[ "${DEBUG}" == "true" ]] || rm -r ${output_dir}/temp_${first}_${last}
[[ "${DEBUG}" == "true" ]] || rm ${subject_list}
=======
[[ "${DEBUG}" == true ]] || rm -r ${output_dir}/temp_${first}_${last}
[[ "${DEBUG}" == true ]] || rm ${subject_list}
>>>>>>> 81be2afe59017c2a4534fb1a2667444ad03296b5





