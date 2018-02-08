# multiAtlasTT (Beta)
_Multi-Atlas Transfer Tools for Neuroimaging (maTT)_

Given a completed FreeSurfer _recon-all_ directoy, these scripts can transfer an atlas (.annot file; also called a 'parcellation') in fsaverage space to subject space, in both volume (nifti) and surface (.annot) format. Therefore, using these tools one can obtain multiple parcellations in the subject space (in addition to the Desikan-Killiany and Destrieux parcellations that recon-all usually constructs<sup>1</sup>). The major part of the label transfer script was written by the [CJNeuroLab](https://cjneurolab.org/2016/11/22/hcp-mmp1-0-volumetric-nifti-masks-in-native-structural-space/). The goal of these tools is to make fitting multiple atlases a piece of cake. Have fun! 

This project is in *beta*; work is ongoing. Please feel free to comment via issue/pull request.

## Prerequities

* FSL
* FreeSurfer
* [easy_lausanne](https://github.com/mattcieslak/easy_lausanne)
  * meaning you have nibabel and numpy too
  * Also, easy_lausanne is a great tool that you should check out!

## Usage

See ``example_run_maTT.sh`` for modifiable example scipt

## Data Sources

* [gordon333](https://mail.nmr.mgh.harvard.edu/pipermail//freesurfer/2017-April/051470.html) (333 nodes)
  * > Gordon, E. M., Laumann, T. O., Adeyemo, B., Huckins, J. F., Kelley, W. M., & Petersen, S. E. (2014). Generation and evaluation of a cortical area parcellation from resting-state correlations. Cerebral cortex, 26(1), 288-303.
Chicago	

* [hcp-mmp](https://figshare.com/articles/HCP-MMP1_0_projected_on_fsaverage/3498446) (360 nodes)
  * > Glasser, M. F., Coalson, T. S., Robinson, E. C., Hacker, C. D., Harwell, J., Yacoub, E., ... & Smith, S. M. (2016). A multi-modal parcellation of human cerebral cortex. Nature, 536(7615), 171-178.
  * <sup>2</sup>
 
* [nspn500](https://github.com/KirstieJane/NSPN_WhitakerVertes_PNAS2016/tree/master/FS_SUBJECTS/fsaverageSubP) (308 nodes)
  * > Whitaker, K. J., Vértes, P. E., Romero-Garcia, R., Váša, F., Moutoussis, M., Prabhu, G., ... & Tait, R. (2016). Adolescence is associated with genomically patterned consolidation of the hubs of the human brain connectome. Proceedings of the National Academy of Sciences, 113(32), 9105-9110.
  * > Romero-Garcia, R., Atienza, M., Clemmensen, L. H., & Cantero, J. L. (2012). Effects of network resolution on topological properties of human neocortex. Neuroimage, 59(4), 3522-3532.

* [schaefer*-yeo17](https://github.com/ThomasYeoLab/CBIG/tree/master/stable_projects/brain_parcellation/Schaefer2018_LocalGlobal) (100, 200, 400, 600, 800, 1000 nodes)
  * > Schaefer, A., Kong, R., Gordon, E. M., Laumann, T. O., Zuo, X. N., Holmes, A. J., ... & Yeo, B. T. (2017). Local-global parcellation of the human cerebral cortex from intrinsic functional connectivity mri. Cerebral Cortex, 1-20.
  
* [yeo17](https://github.com/ThomasYeoLab/CBIG/tree/master/stable_projects/brain_parcellation/Yeo2011_fcMRI_clustering) (114 nodes)
  * > Yeo BT, Krienen FM, Sepulcre J, Sabuncu MR, Lashkari D, Hollinshead M, Roffman JL, Smoller JW, Zollei L., Polimeni JR, Fischl B, Liu H, Buckner RL. The organization of the human cerebral cortex estimated by intrinsic functional connectivity. Journal of Neurophysiology 106(3):1125-1165, 2011.
  * > Krienen FM, Yeo BTT, Buckner RL. Reconfigurable state-dependent functional coupling modes cluster around a core functional architecture. Philosophical Transactions of the Royal Society B, 369:20130526, 2014.
  * > Yeo BTT, Tandi J, Chee MWL. Functional connectivity during rested wakefulness predicts vulnerability to sleep deprivation. Neuroimage 111:147-158, 2015.
  * > Zuo, X.N., et al. An open science resource for establishing reliability and reproducibility in functional connectomics, Sci data, 1:140049, 2014.

## Notes

Useful reading for considering what parcellation to use:
> Zalesky, A., Fornito, A., Harding, I. H., Cocchi, L., Yücel, M., Pantelis, C., & Bullmore, E. T. (2010). Whole-brain anatomical networks: does the choice of nodes matter?. Neuroimage, 50(3), 970-983.

> de Reus, M. A., & Van den Heuvel, M. P. (2013). The parcellation-based connectome: limitations and extensions. Neuroimage, 80, 397-404.

> Arslan, S., Ktena, S. I., Makropoulos, A., Robinson, E. C., Rueckert, D., & Parisot, S. (2017). Human brain mapping: a systematic comparison of parcellation methods for the human cerebral cortex. NeuroImage.

Note that the atlases here are not a comprehensive set of the parcellations used in neuroimaging. If you would like to see another parcellation (in fsaverage space) supported here, feel free to post an issue/pull request! 

Also note that fitting a parcellation in the manner used here is not the only method for fitting parcellations to neuroimage data. While these tools warp an 'average' brain to each subject, some methods compute individualized parcellations based on subject-level data. 

<sup>1</sup> These tools transfer the atlas from fsaverage to subject space using [_mri_label2label_](https://surfer.nmr.mgh.harvard.edu/fswiki/mri_label2label), whereas FreeSufer _recon-all_ uses _mris_ca_label_ to generative the Desikan and Destrieux parcellations in native space. This tool can be used as part of a pipeline to generate the appropriate .gcs files necessary for potentially using the _mris_ca_train_ and _mris_ca_label_ functions.

<sup>2</sup> The creators of the HCP-MMP1.0 atlas [do not fully support](https://www.mail-archive.com/hcp-users@humanconnectome.org/msg03072.html) transfering their parcellation to volume space. This is because the HCP altas is supposed to be fit with multiple imaging modalities, multi-modal surface matching, and a perceptron; on a high resolution surface. These tools only utilize the FreeSurfer surface registration. Therefore, proceed at your own risk. See also [this preprint](https://www.biorxiv.org/content/early/2018/01/29/255620) for additional info on the HCP viewpoint.
