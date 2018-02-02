# multiAtlasTT
_Multi-Atlas Transfer Tools for Neuroimaging_

Given a completed FreeSurfer _recon-all_ directoy, these scripts can transfer an atlas (.annot file; also called a 'parcellation') in fsaverage space to subject space, in both volume (nifti) and surface (.annot) format. Therefore, using these tools one can obtain multiple parcellations in the subject space (in addition to the Desikan-Killiany and Destrieux parcellations that recon-all usually constructs<sup>1</sup>). 

## Prerequities

* FSL
* FreeSurfer
* [easy_lausanne](https://github.com/mattcieslak/easy_lausanne)

## Usage

## Notes

<sup>1</sup> these tools transfer the atlas from fsaverage to subject space, wherase FreeSufer _recon-all_ uses _mris_ca_label_ to generative the Desikan and Destrieux parcellations in native space. This tool can be used as part of a pipeline to generate the appropriate gcs files necessary for potentially using the _mris_ca_label_ function
