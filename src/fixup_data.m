

sch100_annot = struct() ; 
sch200_annot = struct() ; 
sch300_annot = struct() ; 
sch400_annot = struct() ; 
sch500_annot = struct() ; 
sch600_annot = struct() ; 
sch800_annot = struct() ; 
sch1000_annot = struct() ; 

sch100_annot.lh.file = '../atlas_data/schaefer100-yeo17/lh.schaefer100-yeo17.annot' ;
sch100_annot.rh.file = '../atlas_data/schaefer100-yeo17/rh.schaefer100-yeo17.annot' ;

sch200_annot.lh.file = '../atlas_data/schaefer200-yeo17/lh.schaefer200-yeo17.annot' ;
sch200_annot.rh.file = '../atlas_data/schaefer200-yeo17/rh.schaefer200-yeo17.annot' ;

sch300_annot.lh.file = '../atlas_data/schaefer300-yeo17/lh.schaefer300-yeo17.annot' ;
sch300_annot.rh.file = '../atlas_data/schaefer300-yeo17/rh.schaefer300-yeo17.annot' ;

sch400_annot.lh.file = '../atlas_data/schaefer400-yeo17/lh.schaefer400-yeo17.annot' ;
sch400_annot.rh.file = '../atlas_data/schaefer400-yeo17/rh.schaefer400-yeo17.annot' ;

sch500_annot.lh.file = '../atlas_data/schaefer500-yeo17/lh.schaefer500-yeo17.annot' ;
sch500_annot.rh.file = '../atlas_data/schaefer500-yeo17/rh.schaefer500-yeo17.annot' ;

sch600_annot.lh.file = '../atlas_data/schaefer600-yeo17/lh.schaefer600-yeo17.annot' ;
sch600_annot.rh.file = '../atlas_data/schaefer600-yeo17/rh.schaefer600-yeo17.annot' ;

sch800_annot.lh.file = '../atlas_data/schaefer800-yeo17/lh.schaefer800-yeo17.annot' ;
sch800_annot.rh.file = '../atlas_data/schaefer800-yeo17/rh.schaefer800-yeo17.annot' ;

sch1000_annot.lh.file = '../atlas_data/schaefer1000-yeo17/lh.schaefer1000-yeo17.annot' ;
sch1000_annot.rh.file = '../atlas_data/schaefer1000-yeo17/rh.schaefer1000-yeo17.annot' ;

% fixannot(sch100_annot)
fixannot(sch200_annot)
fixannot(sch300_annot)
fixannot(sch400_annot)
fixannot(sch500_annot)
fixannot(sch600_annot)
fixannot(sch800_annot)
fixannot(sch1000_annot)

function fixannot(inStruct)

% function [vertices, label, colortable] = read_annotation(filename, varargin)
[ inStruct.lh.vert , inStruct.lh.lab , inStruct.lh.ct ] = read_annotation(inStruct.lh.file) ;
[ inStruct.rh.vert , inStruct.rh.lab , inStruct.rh.ct ] = read_annotation(inStruct.rh.file) ;

% add name for right hemi label!!
tmpName = inStruct.lh.ct.struct_names{1} ;
inStruct.rh.ct.struct_names{1} = tmpName ;

% for good measure, make it a slightly different color
if isequal(inStruct.rh.ct.table(1,:),inStruct.lh.ct.table(1,:))
    tmpVals = inStruct.rh.ct.table(1,:) + [ 0 1 0 0 0 ] ;
    inStruct.rh.ct.table(1,:) = tmpVals ;
    % r + g*2^8 + b*2^16 + flag*2^24 
    newLab = tmpVals(1) + tmpVals(2)*2^8 + tmpVals(3)*2^16 + tmpVals(4)*2^24 ;
     
    oldLab = inStruct.lh.ct.table(1,5) ;
    
    % change old vals to new unique vals
    inStruct.rh.lab(inStruct.rh.lab == oldLab) = newLab ;
    % change that lad identifier
    inStruct.rh.ct.table(1,5) = newLab ;
end 

fileDir = dirname(inStruct.lh.file) ;

lh_filename = basename(inStruct.lh.file) ;
rh_filename = basename(inStruct.rh.file) ;

lh_outName = [ fileDir '/' lh_filename ] ;
rh_outName = [ fileDir '/' rh_filename ] ;

% move the old file
movefile(lh_outName,[lh_outName '.old'])
movefile(rh_outName,[rh_outName '.old'])

% function write_annotation(filename, vertices, label, ct)
% write_annotation(filename, vertices, label, ct)
%
% Only writes version 2...
%
% vertices expected to be simply from 0 to number of vertices - 1;
% label is the vector of annotation
%
% ct is a struct
% ct.numEntries = number of Entries
% ct.orig_tab = name of original ct
% ct.struct_names = list of structure names (e.g. central sulcus and so on)
% ct.table = n x 5 matrix. 1st column is r, 2nd column is g, 3rd column
% is b, 4th column is flag, 5th column is resultant integer values
% calculated from r + g*2^8 + b*2^16 + flag*2^24. flag expected to be all 0

write_annotation(lh_outName,inStruct.lh.vert,...
                            inStruct.lh.lab,...
                            inStruct.lh.ct)
write_annotation(rh_outName,inStruct.rh.vert,...
                            inStruct.rh.lab,...
                            inStruct.rh.ct)

end