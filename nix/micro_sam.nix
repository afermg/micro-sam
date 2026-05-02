{
  lib,
  buildPythonPackage,
  setuptools,
  wheel,
  numpy,
  imageio,
  tifffile,
  pooch,
  xxhash,
  zarr,
  torch,
  torchvision,
  scikit-image,
  segment_anything,
  python-elf,
  nifty,
  vigra,
  torch_em,
  tqdm,
  pyyaml,
  imagecodecs,
}:
# micro-sam itself. Source lives in this flake's repo (server.py is at the
# same root, so the dev shell doesn't strictly need to install this package
# -- but having it as a real Python package makes `nix run` self-contained
# and prevents PYTHONPATH shadow issues when other tools want to import
# `micro_sam`.
buildPythonPackage rec {
  pname = "micro_sam";
  version = "1.7.6";  # mirrors micro_sam/__version__.py at the time of writing
  format = "pyproject";

  src = ./..;

  build-system = [
    setuptools
    wheel
  ];

  dependencies = [
    numpy
    imageio
    tifffile
    pooch
    xxhash
    zarr
    torch
    torchvision
    scikit-image
    segment_anything
    python-elf
    nifty
    vigra
    torch_em
    tqdm
    pyyaml
    imagecodecs
  ];

  pythonImportsCheck = [
    "micro_sam"
    "micro_sam.util"
    "micro_sam.automatic_segmentation"
    "micro_sam.instance_segmentation"
  ];

  pythonRuntimeDepsCheck = false;
  dontCheckRuntimeDeps = true;

  meta = {
    description = "Segment Anything for Microscopy.";
    homepage = "https://github.com/computational-cell-analytics/micro-sam";
    license = lib.licenses.mit;
  };
}
