{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  cmake,
  python,
  numpy,
  boost,
  xtensor,
  xtl,
  xtensor-python,
  pybind11,
}:
# Affogato: C++ implementations of mutex watershed / GASP. Python bindings
# built via pybind11 + xtensor-python. Distributed only as an sdist on PyPI
# (no manylinux wheel) and as a conda-forge package; we build from the
# upstream tag.
let
  boostPy = boost.override {
    enablePython = true;
    inherit python;
  };
in
buildPythonPackage rec {
  # Stay on 0.3.3. The 0.4.x line moved its xtensor includes to the new
  # `xtensor/containers/...` layout introduced in xtensor 0.27, which
  # we deliberately don't ship (see nix/xtensor_pinned.nix).
  pname = "affogato";
  version = "0.3.3";
  format = "other";

  src = fetchFromGitHub {
    owner = "constantinpape";
    repo = "affogato";
    rev = version;
    sha256 = "sha256-o3rpg+fF0U1NfToEYVNORIgYiZRZyEc0CblGz+KiV68=";
  };

  # Upstream's CMake installs into the literal value of cmake's
  # `Python_SITELIB`, which points back at the python derivation's
  # store path -- impossible inside a sandboxed build. Rewrite the
  # install destination to a relative `python.sitePackages` so it
  # lands under `$out/lib/python3.X/site-packages/affogato/`.
  # 0.3.3's CMakeLists uses a custom FindNUMPY + the third-party
  # FindPythonPyEnv module to assemble a Python environment, instead
  # of cmake's standard `find_package(Python COMPONENTS Development)`.
  # On NixOS that fails to expose Python.h to per-target compile flags.
  # Replace the python-discovery lines with the modern variant that
  # 0.4.x already uses, and forward the NumPy include path with the
  # name FindPython exports.
  #
  # Also drop the `learning` submodule from the build: malis.hxx hits
  # an `operator/=` ambiguity between pybind11 and xtensor that we'd
  # need a non-trivial source patch to fix, and elf / micro_sam never
  # call into `affogato.learning`.
  postPatch =
    let dollar = "$";
    in ''
      substituteInPlace CMakeLists.txt \
        --replace-fail 'include(FindPythonPyEnv)' 'find_package(Python REQUIRED COMPONENTS NumPy Interpreter Development)' \
        --replace-fail 'find_package(NUMPY REQUIRED)' 'find_package(pybind11 CONFIG REQUIRED)' \
        --replace-fail 'find_package(pybind11 REQUIRED)' '# pybind11 already loaded above' \
        --replace-fail 'include_directories(${dollar}{NUMPY_INCLUDE_DIRS})' 'include_directories(${dollar}{Python_NumPy_INCLUDE_DIRS} ${dollar}{Python_INCLUDE_DIRS})'
      substituteInPlace src/python/lib/CMakeLists.txt \
        --replace-fail 'add_subdirectory(learning)' '# learning subdir disabled (malis.hxx fails to compile)'
    '';

  nativeBuildInputs = [
    cmake
    pybind11
  ];

  buildInputs = [
    boostPy
    xtensor
    xtl
    xtensor-python
    pybind11
    python
    numpy
  ];

  cmakeFlags = [
    # Force the python module install dir absolute (relative under
    # CMAKE_INSTALL_PREFIX) so cmake doesn't try to invoke distutils.
    "-DPYTHON_MODULE_INSTALL_DIR=${placeholder "out"}/${python.sitePackages}"
    # 0.3.3's CMakeLists.txt sets cmake_minimum_required(VERSION 2.8),
    # which cmake 4 refuses to honour. Pass the policy override.
    "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
  ];

  dependencies = [ numpy ];

  # The build system is plain cmake (BUILD_PYTHON=ON by default); skip the
  # python wheel-build phase that buildPythonPackage would normally invoke.
  dontUsePyprojectBuild = true;
  dontUsePypaInstall = true;
  dontUsePypaBuild = true;
  dontUseSetuptoolsBuild = true;
  dontUseSetuptoolsCheck = true;

  pythonImportsCheck = [ "affogato" "affogato.segmentation" "affogato.affinities" ];

  pythonRuntimeDepsCheck = false;
  dontCheckRuntimeDeps = true;

  meta = {
    description = "Mutex watershed / GASP affinity segmentation in C++ with python bindings.";
    homepage = "https://github.com/constantinpape/affogato";
    license = lib.licenses.mit;
  };
}
