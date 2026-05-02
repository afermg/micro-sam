{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  wheel,
  torch,
  torchvision,
}:
# Meta's Segment Anything model. The PyPI sdist declares no install_requires
# (torch / torchvision are obviously needed, listed below explicitly so the
# closure is correct). All other extras (matplotlib, cocotools, onnx) are
# eval-time only and not used by micro_sam at inference.
buildPythonPackage rec {
  pname = "segment_anything";
  version = "1.0";
  format = "pyproject";

  src = fetchPypi {
    pname = "segment_anything";
    inherit version;
    sha256 = "sha256-7Qyfb7B7vvnGI4pwKKE8gnLxumtjBcpz4+BkJmUDc2s=";
  };

  build-system = [
    setuptools
    wheel
  ];

  dependencies = [
    torch
    torchvision
  ];

  pythonImportsCheck = [ "segment_anything" ];

  pythonRuntimeDepsCheck = false;
  dontCheckRuntimeDeps = true;

  meta = {
    description = "Meta AI's Segment Anything Model.";
    homepage = "https://github.com/facebookresearch/segment-anything";
    license = lib.licenses.asl20;
  };
}
