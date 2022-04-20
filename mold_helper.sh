#!/bin/bash

# ========================================================
# REQUIRED INPUTS TO THE SCRIPT - IF USING HEMISPHERE SCAN
# ========================================================

# The 9.4T MRI scan of the entire MTL specimen (0.4 x 0.4 x 1.2 mm3)
MTL_94T=mtl_94t.nii.gz

# The 7T MRI T2-weighted scan of the hemisphere (0.3 x 0.3 x 0.3 mm3)
HEMI=hemi_7t.nii.gz

# The "evolving contour" saved while segmenting the MTL in ITK-SNAP
MTL_CONTOUR_NATIVE=contour_image_94t.nii.gz

# The "evolving contour" saved while segmenting the MTL in ITK-SNAP
HEMI_TO_MTL_AFFINE=affine.mat

# ========================================================
# REQUIRED INPUTS TO THE SCRIPT - IF USING 7T MTL SCAN
# ========================================================

# The MTL 7T T2-weighted MRI scan
MTL_7T=mtl7t.nii.gz

# The "evolving contour" saved while segmenting the MTL in ITK-SNAP
MTL_CONTOUR_7T=contour_image.nii.gz

# The rotation that places the MRI into the mold
HOLDER_MAT=holderrotation.mat

# The cropping mask
CROP_MASK=cropmask.nii.gz


# =================================================
# OTHER IMAGES USED IN THE SCRIPT
# =================================================
REFERENCE_MOLD=reference_mold.nii.gz
SLIT_MOLD=slitmold.nii.gz
SLIT_MOLD_CROP=slitmold_cropped.nii.gz
SLIT_MOLD_STL=slitmold.stl

# =================================================
# PERFORM REGISTRATION BETWEEN 7T and 9.4T
# =================================================
function reg_mtl_to_hemi()
{
  # Check the required inputs for this function
  for input in $MTL_94T $HEMI $MTL_CONTOUR $HEMI_TO_MTL_AFFINE; do
    if [[ ! -f $input ]]; then
      echo "Error: missing required input $input"
      exit 255
    fi
  done

  # Images used by this function only
  MTLISO=mtl_iso.nii.gz
  MTLISO_MASK=mtl_iso_mask.nii.gz
  HEMI_AFF=reslice_hemi_aff.nii.gz
  WARPROOT=warproot.nii.gz

  # Generate isotropic image from the MTL
  c3d $MTL_94T -info -resample-mm 0.4mm -pad 0x0x10 0x0x10 0 -info -o $MTLISO
  c3d $MTLISO $MTL_CONTOUR_NATIVE -reslice-identity -thresh -inf 0 1 0 -o $MTLISO_MASK

  # Apply affine transform to the hemisphere
  greedy -d 3 -rf $MTLISO -rm $HEMI $HEMI_AFF -r $HEMI_TO_MTL_AFFINE

  # Perform deformable registration
  greedy -d 3 -i $MTLISO $HEMI_AFF -oroot $WARPROOT \
    -wp 0 -gm $MTLISO_MASK -bg NaN \
    -m WNCC 2x2x2 -s 3mm 0.2mm -n 100x100x60 -sv

  # Apply registration to map MTL into hemisphere space
  greedy -d 3 -rf $HEMI \
    -rm $MTL_94T $MTL_7T \
    -rb 4 -rm $MTL_CONTOUR_NATIVE $MTL_CONTOUR_7T \
    -rb 0 -ri LABEL 0.2mm \
    -r $HEMI_TO_MTL_AFFINE,-1 $WARPROOT,-64 
}

# =================================================
# GENERATE REFERENCE MOLD
# =================================================
function make_reference_mold()
{
  # Read the required parameter
  SLITSPC=${1:-0.4}
  echo "Generating reference mold with slit spacing of $SLITSPC"

  # Generate the mold
  c3d -create 384x576x384 0.2x0.2x0.2mm -orient LPI -origin-voxel 50% \
    -cmp -popas z -popas y -popas x \
    -push y -scale 1.570796 -cos -acos -scale 0.318310 -thresh -inf $SLITSPC -4 4 \
    -push z -thresh -inf -28 4 -4 -max -push y -thresh -60 60 -4 4 -max \
    -pad 5x5x5 5x5x5 -4 -o $REFERENCE_MOLD
}


# =================================================
# CARVE THE REFERENCE MOLD OUT
# =================================================
function carve_mold()
{
  # Check the required inputs for this function
  for input in $REFERENCE_MOLD $MTL_CONTOUR_7T $HOLDER_MAT; do
    if [[ ! -f $input ]]; then
      echo "Error: missing required input $input"
      exit 255
    fi
  done

  c3d $REFERENCE_MOLD -as R $MTL_CONTOUR_7T -background 4 \
    -reslice-matrix $HOLDER_MAT \
    -swapdim IPL -extrude-seg -swapdim LPI \
    -push R -min -o $SLIT_MOLD
}

# =================================================
# COMPLETE THE MOLD USING CROPMASK
# =================================================
function finish_mold()
{
  for input in $CROP_MASK $SLIT_MOLD; do
    if [[ ! -f $input ]]; then
      echo "Error: missing required input $input"
      exit 255
    fi
  done 

  # Apply the carving to the mold
  c3d $CROP_MASK -pad 4x4x4 4x4x4 0 \
    -stretch 0 1 -4 4 -dup $SLIT_MOLD \
    -reslice-identity -min -o $SLIT_MOLD_CROP

  # Extract the mesh of the mold
  vtklevelset $SLIT_MOLD_CROP $SLIT_MOLD_STL 0.0

  # Extract the mesh of the object (for paraview)
  c3d $SLIT_MOLD_CROP $MTL_CONTOUR_7T -reslice-matrix $HOLDER_MAT \
    -o contour_image_rotated.nii.gz
 
  vtklevelset contour_image_rotated.nii.gz sample_inplace_mesh.stl 0.0
}

# =================================================
# SETUP SCRIPT ENVIRONMENT
# =================================================
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BIN_DIR=$SCRIPT_DIR/ext/$(uname)/bin

PATH=$BIN_DIR:$PATH
for prog in c3d greedy vtklevelset; do
  if ! command -v $BIN_DIR/$prog &> /dev/null; then
    echo "Command $BIN_DIR/$prog not found"
    exit 255
  fi
done

# =================================================
# MAIN ENTRYPOINT
# =================================================
if [[ $# -eq 0 ]]; then
  echo "Script Usage:"
  echo "  mold_helper.sh reg_mtl_to_hemi"
  echo "  mold_helper.sh make_reference_mold [SLIT_SPACING]"
  echo "  mold_helper.sh carve_mold"
  echo "  mold_helper.sh finish_mold"
  exit 0
fi

CMD=${1?}
shift 
$CMD "$@"
