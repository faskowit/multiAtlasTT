"""Remap FreeSurfer-style cortical parcel labels in a NIfTI image.

Labels from 1001--1999 are treated as left-hemisphere parcels and labels from
2001--2999 as right-hemisphere parcels. Cortical labels present in the image
are assigned a new value, so gaps in the original label series do not matter.
By default, the 14 labels in ``subcortical_remap.txt`` are assigned immediately
afterwards. Pass ``--skip-subcortical`` to omit them.

Usage: ``python quickremap.py input.nii.gz output.nii.gz [--skip-subcortical]``
"""

from __future__ import annotations

import argparse
from pathlib import Path
import re
from typing import Dict, Iterable, Tuple
import warnings

import nibabel as nib
import numpy as np


LEFT_RANGE = (1000, 1999)
RIGHT_RANGE = (2000, 2999)
LEFT_ANNOT_OFFSET = 1000
RIGHT_ANNOT_OFFSET = 2000


def load_subcortical_labels(path: Path) -> Dict[int, str]:
    """Read a two-column ``label area_name`` subcortical lookup file."""
    labels: Dict[int, str] = {}
    with path.open(encoding="utf-8") as lookup_file:
        for line_number, line in enumerate(lookup_file, start=1):
            fields = line.split(maxsplit=1)
            if not fields:
                continue
            if len(fields) != 2:
                raise ValueError(f"{path}:{line_number} must have a label and area name.")
            try:
                label = int(fields[0])
            except ValueError as error:
                raise ValueError(f"{path}:{line_number} has a non-integer label.") from error
            if label in labels:
                raise ValueError(f"{path}:{line_number} repeats label {label}.")
            labels[label] = fields[1].strip()
    return labels


def load_cortical_names(lh_annot: Path, rh_annot: Path) -> Dict[int, str]:
    """Read cortical names from FreeSurfer annotations keyed by NIfTI label."""
    cortical_names: Dict[int, str] = {}
    for hemisphere, offset, annot_path in (
        ("left", LEFT_ANNOT_OFFSET, lh_annot),
        ("right", RIGHT_ANNOT_OFFSET, rh_annot),
    ):
        # ``read_annot`` returns color-table names in positional-ID order. In a
        # FreeSurfer parcellation volume, those IDs are offset by 1000 (left)
        # or 2000 (right), e.g. table entry 1 is label 1001 or 2001.
        _, _, names = nib.freesurfer.read_annot(str(annot_path))
        for table_id, name in enumerate(names):
            try:
                cortical_names[offset + table_id] = name.decode("utf-8")
            except UnicodeDecodeError as error:
                raise ValueError(
                    f"Could not decode {hemisphere} annotation name {table_id} in {annot_path}."
                ) from error
    return cortical_names


def excluded_cortical_labels(cortical_names: Dict[int, str]) -> set[int]:
    """Return annotation labels whose names indicate background or missing data."""
    excluded: set[int] = set()
    for label, name in cortical_names.items():
        normalized_name = name.strip()
        if re.search(r"\bbackground\b", normalized_name, flags=re.IGNORECASE) or (
            normalized_name.casefold() == "nan"
        ):
            excluded.add(label)
    return excluded


def remap_parcellation(
    data: np.ndarray,
    subcortical_labels: Iterable[int] = (),
    excluded_labels: Iterable[int] = (),
    cortical_labels: Iterable[int] | None = None,
) -> Tuple[np.ndarray, Dict[int, int]]:
    """Remap cortical parcels first, then listed subcortical parcels.

    All voxels other than the recognized cortical and listed subcortical labels
    are set to 0. Subcortical labels are assigned even if they are absent from
    the image, so their output IDs stay fixed. When ``cortical_labels`` is
    supplied from annotation tables, it similarly fixes cortical output IDs
    even for parcels absent from the image.
    """
    if not np.issubdtype(data.dtype, np.number):
        raise TypeError("Parcellation data must be numeric.")
    if not np.all(np.isfinite(data)) or not np.all(data == np.floor(data)):
        raise ValueError("Parcellation data must contain only finite integer labels.")

    excluded = np.asarray(tuple(excluded_labels), dtype=np.int64)
    if cortical_labels is None:
        labels = np.unique(data.astype(np.int64, copy=False))
    else:
        labels = np.unique(np.asarray(tuple(cortical_labels), dtype=np.int64))

    left_labels = labels[(labels >= LEFT_RANGE[0]) & (labels <= LEFT_RANGE[1])]
    right_labels = labels[(labels >= RIGHT_RANGE[0]) & (labels <= RIGHT_RANGE[1])]
    if excluded.size:
        left_labels = left_labels[~np.isin(left_labels, excluded)]
        right_labels = right_labels[~np.isin(right_labels, excluded)]

    mapping: Dict[int, int] = {}
    for new_label, old_label in enumerate(left_labels, start=1):
        mapping[int(old_label)] = new_label
    for new_label, old_label in enumerate(right_labels, start=len(left_labels) + 1):
        mapping[int(old_label)] = new_label
    for new_label, old_label in enumerate(
        subcortical_labels, start=len(left_labels) + len(right_labels) + 1
    ):
        old_label = int(old_label)
        if old_label in mapping:
            raise ValueError(f"Subcortical label {old_label} overlaps a cortical label.")
        mapping[old_label] = new_label

    # Start from an empty parcellation: do not retain background or unrelated
    # FreeSurfer labels in the output image.
    remapped = np.zeros(data.shape, dtype=np.int32)
    for old_label, new_label in mapping.items():
        remapped[data == old_label] = new_label
    return remapped, mapping


def write_mapping(
    mapping: Dict[int, int], region_names: Dict[int, str], subcortical_names: Dict[int, str], path: Path
) -> None:
    """Write a tab-separated old-label/new-label mapping file."""
    with path.open("w", encoding="utf-8") as mapping_file:
        mapping_file.write("old_label\tnew_label\tstructure\tname\n")
        for old_label, new_label in mapping.items():
            if old_label in subcortical_names:
                structure = "subcortical"
            elif old_label <= LEFT_RANGE[1]:
                structure = "left_cortex"
            else:
                structure = "right_cortex"
            name = region_names.get(old_label, "")
            mapping_file.write(f"{old_label}\t{new_label}\t{structure}\t{name}\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input_file", type=Path, help="Input parcellation NIfTI file")
    parser.add_argument("output_file", type=Path, help="Output remapped NIfTI file")
    parser.add_argument(
        "--mapping-file",
        type=Path,
        help="Optional TSV mapping path (default: OUTPUT_FILE_remap.tsv)",
    )
    parser.add_argument(
        "--subcortical-remap",
        type=Path,
        default=Path(__file__).with_name("subcortical_remap.txt"),
        help="Two-column subcortical label lookup (default: subcortical_remap.txt beside this script)",
    )
    parser.add_argument(
        "--skip-subcortical",
        action="store_true",
        help="Do not include or remap subcortical areas (they are included by default)",
    )
    parser.add_argument(
        "--lh-annot",
        type=Path,
        help="Optional left-hemisphere FreeSurfer .annot file for cortical names",
    )
    parser.add_argument(
        "--rh-annot",
        type=Path,
        help="Optional right-hemisphere FreeSurfer .annot file for cortical names",
    )
    args = parser.parse_args()
    if (args.lh_annot is None) != (args.rh_annot is None):
        parser.error("Provide both --lh-annot and --rh-annot, or neither.")

    image = nib.load(str(args.input_file))
    data = np.asanyarray(image.dataobj)
    subcortical_names = (
        {} if args.skip_subcortical else load_subcortical_labels(args.subcortical_remap)
    )
    region_names = dict(subcortical_names)
    skipped_labels: set[int] = set()
    if args.lh_annot is not None:
        cortical_names = load_cortical_names(args.lh_annot, args.rh_annot)
        region_names.update(cortical_names)
        skipped_labels = excluded_cortical_labels(cortical_names)
        present_skipped_labels = sorted(
            label for label in skipped_labels if np.any(data == label)
        )
        for label in present_skipped_labels:
            warnings.warn(
                f"Skipping cortical label {label} ({cortical_names[label]!r}) because its "
                "annotation name indicates background or missing data.",
                stacklevel=1,
            )
    remapped_data, mapping = remap_parcellation(
        data,
        subcortical_names,
        skipped_labels,
        cortical_labels=cortical_names if args.lh_annot is not None else None,
    )

    header = image.header.copy()
    header.set_data_dtype(np.int32)
    nib.save(nib.Nifti1Image(remapped_data, image.affine, header=header), str(args.output_file))

    mapping_path = args.mapping_file or Path(f"{args.output_file}_remap.tsv")
    write_mapping(mapping, region_names, subcortical_names, mapping_path)
    print(f"Remapped {len(mapping)} parcels; mapping written to {mapping_path}")


if __name__ == "__main__":
    main()
