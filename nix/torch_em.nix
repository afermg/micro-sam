{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  wheel,
  torch,
  torchvision,
  h5py,
  numpy,
  scikit-image,
  scipy,
  tqdm,
  imageio,
  tifffile,
  kornia,
  tensorboard,
  natsort,
  requests,
  xarray,
  python-elf,
}:
# torch_em: Constantin Pape's training utilities for U-Net family models on
# microscopy data. Pure Python on top of torch / torchvision / kornia / elf.
# Imports kornia + tensorboard at top-level via .segmentation, so they must
# be in the closure even though the server only calls a small subset.
buildPythonPackage rec {
  pname = "torch_em";
  version = "0.8.3";
  format = "pyproject";

  src = fetchFromGitHub {
    owner = "constantinpape";
    repo = "torch-em";
    rev = version;
    sha256 = "sha256-8W1IJyxLLAYfE8/ufxuY6w5bPAooMOUww7NJ86XGuZQ=";
  };

  build-system = [
    setuptools
    wheel
  ];

  dependencies = [
    torch
    torchvision
    h5py
    numpy
    scikit-image
    scipy
    tqdm
    imageio
    tifffile
    kornia
    tensorboard
    natsort
    requests
    xarray
    python-elf
  ];

  # Limit the imports check: `torch_em.__init__` pulls in
  # tensorboard_logger -> elf.segmentation.embeddings on first import,
  # which is fine, but the check is slow. Confirm just the submodules
  # micro_sam.automatic_segmentation actually touches.
  pythonImportsCheck = [
    "torch_em"
    "torch_em.data.datasets.util"
    "torch_em.model"
    "torch_em.util.segmentation"
  ];

  pythonRuntimeDepsCheck = false;
  dontCheckRuntimeDeps = true;

  meta = {
    description = "PyTorch + U-Net training and inference utilities for microscopy segmentation.";
    homepage = "https://github.com/constantinpape/torch-em";
    license = lib.licenses.mit;
  };
}
