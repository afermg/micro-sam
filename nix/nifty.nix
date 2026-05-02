{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  cmake,
  python,
  numpy,
  scikit-image,
  boost,
  xtensor,
  xtl,
  xtensor-python,
  pybind11,
  nlohmann_json,
  # `vigra` here resolves to *our* `nix/vigra.nix` (the python-bindings-
  # enabled override), so we get the vigra C++ headers + libraries
  # needed by nifty's RAG / watershed includes.
  vigra,
}:
# nifty: graph-based segmentation primitives (multicut, lifted multicut,
# RAGs, mutex watershed plumbing). C++ headers + pybind11 module under
# `nifty.*`. We disable the optional solvers (CPLEX/Gurobi/GLPK) and
# storage backends (HDF5/Z5/fastfilters) -- micro_sam only uses the core
# graph + tools modules.
let
  boostPy = boost.override {
    enablePython = true;
    inherit python;
  };
in
buildPythonPackage rec {
  # 1.2.3 is the last release that uses the old `xtensor/x*.hpp`
  # include paths; 1.2.4 (and master) jumped to `xtensor/containers/...`,
  # which only exists in xtensor >= 0.27. We pin xtensor 0.25, so stay
  # one minor behind.
  pname = "nifty";
  version = "1.2.3";
  format = "other";

  src = fetchFromGitHub {
    owner = "DerThorsten";
    repo = "nifty";
    rev = "v${version}";
    sha256 = "sha256-+OrkU2rUBQfR1NWS/ZzUYg9iAgxdQJqdekMksy+LyKQ=";
  };

  # Same impossible Python_SITELIB install path as affogato. Redirect the
  # final install destination to a relative `python.sitePackages` so it
  # lands under `$out/lib/python3.X/site-packages/nifty/`.
  # Same `${Python_SITELIB}` install-path issue as affogato -- redirect to
  # an $out-relative sitePackages so the python module lands inside our
  # store path. Use a let-bound `$` to dodge nix's triple-quote close
  # marker collision.
  postPatch =
    let dollar = "$";
    in ''
      substituteInPlace src/python/CMakeLists.txt \
        --replace-fail '${dollar}{Python_SITELIB})' '"${placeholder "out"}/${python.sitePackages}")'
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
    nlohmann_json
    vigra
  ];

  cmakeFlags = [
    # 1.2.3's CMakeLists sets cmake_minimum_required(VERSION 3.1).
    "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
    "-DBUILD_NIFTY_PYTHON=ON"
    "-DBUILD_PYTHON_TEST=OFF"
    "-DBUILD_CPP_TEST=OFF"
    "-DBUILD_CPP_EXAMPLES=OFF"
    "-DBUILD_DOCS=OFF"
    "-DBUILD_PYTHON_DOCS=OFF"
    "-DWITH_HDF5=OFF"
    "-DWITH_Z5=OFF"
    "-DWITH_QPBO=OFF"
    "-DWITH_LP_MP=OFF"
    "-DWITH_GUROBI=OFF"
    "-DWITH_CPLEX=OFF"
    "-DWITH_GLPK=OFF"
    "-DWITH_FASTFILTERS=OFF"
  ];

  dependencies = [
    numpy
    scikit-image
  ];

  dontUsePyprojectBuild = true;
  dontUsePypaInstall = true;
  dontUsePypaBuild = true;
  dontUseSetuptoolsBuild = true;
  dontUseSetuptoolsCheck = true;

  pythonImportsCheck = [
    "nifty"
    "nifty.tools"
    "nifty.graph"
    "nifty.graph.rag"
    "nifty.ground_truth"
    "nifty.ufd"
  ];

  pythonRuntimeDepsCheck = false;
  dontCheckRuntimeDeps = true;

  meta = {
    description = "Graph-based segmentation algorithms (multicut, lifted multicut, mutex watershed) with python bindings.";
    homepage = "https://github.com/DerThorsten/nifty";
    license = lib.licenses.mit;
  };
}
