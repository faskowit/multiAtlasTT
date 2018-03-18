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
# given' one subject's completed directory, add information for LUT
# and colortab to atlas directory
# this should only be useful if adding more atlases yourself
#
####################################################################
####################################################################

main() 
{

####################################################################
####################################################################

inputSubjDir="${1}"
atlasBaseDir="${2}"
atlasList="${3}"

# Check the number of arguments.
NUMARGS=$#
if [ $NUMARGS -lt 3 ]; then
	echo -e "Usage:\t ${0} inputSubjDir atlasBaseDir atlasList" 
	exit 1
fi 

####################################################################
####################################################################

for atlas in ${atlasList}
do
    
    # colortable

    for hemi in LH RH
    do

        atlasColorTab=${atlasBaseDir}/${atlas}/${hemi,,}.${atlas}_colortab.txt
        subjColorTab=${inputSubjDir}/${atlas}/colortab_${atlas}_${hemi:0:1}

        # check subject data
        if [[ ! -e ${subjColorTab} ]] 
        then 
            echo "pick new subj to use info from"
            exit 1
        fi

        # check atlas data
        if [[ ! -e ${atlasColorTab} ]]
        then
            cp -v ${subjColorTab} ${atlasColorTab}
            echo "colortab file from: ${subjColorTab}" >> ${atlasBaseDir}/${atlas}/colortab_notes.txt
        else
            echo "colortab already there"
        fi

    done

    # LUT

    atlasLUT=${atlasBaseDir}/${atlas}/LUT_${atlas}.txt
    subjLUT=${inputSubjDir}/${atlas}/LUT_${atlas}.txt

    # check subject data
    if [[ ! -e ${subjLUT} ]] 
    then 
        echo "pick new subj to use info from"
        exit 1
    fi
    
    # check atlas data
    if [[ ! -e ${atlasLUT} ]]
    then
        cp -v ${subjLUT} ${atlasLUT}
        echo "LUT file from: ${subjLUT}" >> ${atlasBaseDir}/${atlas}/LUT_notes.txt
    else
        echo "LUT already there"
    fi

done

} # main 

# run main with input args from shell scrip call
main "$@"


