{
  lib,
  pkgs,
  boost,
  python,
  numpy,
}:
# nixpkgs' vigra builds the C++ library and *would* install vigranumpy
# (its CMakeLists already passes -DVIGRANUMPY_INSTALL_DIR pointing at the
# python sitePackages), but the boost in `buildInputs` is built without
# python support, so cmake silently disables the bindings. We rebuild it
# with a python-enabled boost and expose it as a Python module.
let
  boostPy = boost.override {
    enablePython = true;
    inherit python;
  };
  vigraWithPython = pkgs.vigra.override {
    boost = boostPy;
    python3 = python;
  };
in
python.pkgs.toPythonModule (
  vigraWithPython.overrideAttrs (old: {
    pname = "vigra";
    propagatedBuildInputs = (old.propagatedBuildInputs or [ ]) ++ [ numpy ];
    doCheck = false;
    meta = old.meta // {
      description = "Vigra image-processing library + Python bindings (vigranumpy).";
    };
  })
)
