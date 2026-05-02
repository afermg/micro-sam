{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  numpy,
  imageio,
  requests,
  scikit-image,
  scikit-learn,
  # The conda recipe pulls these in too. They're imported in submodules
  # micro_sam touches at runtime: affogato (segmentation.gasp,
  # segmentation.mutex_watershed), nifty (segmentation.{multicut,gasp_utils,
  # workflows}). z5py / mrcfile / motile / skan are gracefully optional.
  affogato,
  nifty,
  vigra,
  h5py,
  zarr,
  pandas,
  threadpoolctl,
  tqdm,
  networkx,
}:
buildPythonPackage rec {
  pname = "python-elf";
  version = "0.7.4";
  format = "pyproject";

  src = fetchFromGitHub {
    owner = "constantinpape";
    repo = "elf";
    rev = version;
    sha256 = "sha256-ivez53cZ54mwwMEOUjW6wwIaFKZx7dIdR9mIDtCHANg=";
  };

  build-system = [ setuptools ];

  dependencies = [
    numpy
    imageio
    requests
    scikit-image
    scikit-learn
    affogato
    nifty
    vigra
    h5py
    zarr
    pandas
    threadpoolctl
    tqdm
    networkx
  ];

  pythonImportsCheck = [
    "elf"
    "elf.io"
    "elf.parallel"
    "elf.segmentation"
    "elf.tracking.tracking_utils"
    "elf.wrapper"
  ];

  pythonRuntimeDepsCheck = false;
  dontCheckRuntimeDeps = true;

  meta = {
    description = "Image analysis primitives for large microscopy data (formerly python-elf).";
    homepage = "https://github.com/constantinpape/elf";
    license = lib.licenses.mit;
  };
}
