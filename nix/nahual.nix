{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  hatchling,
  numpy,
  pynng,
  requests,
  pytest,
  loguru,
  matplotlib,
}:
# Stub Nahual derivation — used so the Nix dev shell can resolve `nahual`
# alongside editor tooling. The actual server runtime installs nahual via
# pip into the conda env (since micro-sam itself depends on conda-forge-only
# packages like nifty / vigra / python-elf that have no PyPI distribution).
buildPythonPackage {
  pname = "nahual";
  version = "0.0.8";
  format = "pyproject";

  src = fetchFromGitHub {
    owner = "afermg";
    repo = "nahual";
    rev = "87c4cecd5782acc42e4878ca6a439ac227663b69";
    sha256 = "sha256-oVoffChdzb2S3gTfCnhBKRUaGmI0auFJwo54+UVF4Sw=";
  };

  build-system = [
    hatchling
  ];

  dependencies = [
    numpy
    pynng
    requests
    pytest
    loguru
    matplotlib
  ];

  pythonImportsCheck = [
    "nahual"
  ];

  pythonRuntimeDepsCheck = false;
  dontCheckRuntimeDeps = true;

  meta = {
    description = "Deploy and access image and data processing models across processes.";
    homepage = "https://github.com/afermg/nahual";
    license = lib.licenses.mit;
  };
}
