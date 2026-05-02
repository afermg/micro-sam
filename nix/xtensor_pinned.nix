{
  lib,
  pkgs,
  python3Packages,
}:
# Pin the xtensor stack to 0.25.x / xtl 0.7.x / xtensor-python 0.27.x
# (the same combo nixos-24.11 carries). nixos-unstable jumped to xtensor
# 0.27.1 which removed the `svector(begin, end)` constructor that
# affogato + nifty rely on, and additionally introduced C++20 `concept`
# usage in `utils/xutils.hpp` that breaks downstream C++17 builds.
#
# Rather than trying to forward-port affogato / nifty to the new API
# (PRs are still pending upstream), we hold the xtensor stack one
# minor behind. This is purely a *header* change; no rebuild storm.
let
  # Each old release ships a CMakeLists with `cmake_minimum_required(VERSION 3.0)`
  # which cmake 4 rejects -- pass `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` to all
  # three overrides so the configure step succeeds.
  policyFlag = "-DCMAKE_POLICY_VERSION_MINIMUM=3.5";

  xtl = pkgs.xtl.overrideAttrs (old: {
    version = "0.7.7";
    src = pkgs.fetchFromGitHub {
      owner = "xtensor-stack";
      repo = "xtl";
      rev = "0.7.7";
      hash = "sha256-f8qYh8ibC/ToHsUv3OF1ujzt3fUe7kW9cNpGyLqsgqw=";
    };
    # 0.7.7 enables BUILD_TESTS by default and pulls in doctest -- skip.
    cmakeFlags = [ "-DBUILD_TESTS=OFF" policyFlag ];
    doCheck = false;
  });
  xtensor = (pkgs.xtensor.override { inherit xtl; }).overrideAttrs (old: {
    version = "0.25.0";
    src = pkgs.fetchFromGitHub {
      owner = "xtensor-stack";
      repo = "xtensor";
      rev = "0.25.0";
      hash = "sha256-hVfdtYcJ6mzqj0AUu6QF9aVKQGYKd45RngY6UN3yOH4=";
    };
    # Upstream's nixpkgs derivation passes `-DBUILD_TESTS=ON` (it expects
    # newer xtensor where this is harmless). 0.25 actually walks into the
    # test/ subdir and demands doctest -- override it off.
    cmakeFlags = [
      "-DBUILD_TESTS=OFF"
      "-DXTENSOR_ENABLE_ASSERT=OFF"
      "-DXTENSOR_CHECK_DIMENSION=OFF"
      policyFlag
    ];
    doCheck = false;
  });
  xtensor-python =
    (python3Packages.xtensor-python.override {
      inherit xtensor;
    }).overrideAttrs (old: {
      version = "0.27.0";
      src = pkgs.fetchFromGitHub {
        owner = "xtensor-stack";
        repo = "xtensor-python";
        rev = "0.27.0";
        hash = "sha256-Cy/aXuiriE/qxSd4Apipzak30DjgE7jX8ai1ThJ/VnE=";
      };
      cmakeFlags = [
        "-DBUILD_TESTS=OFF"
        policyFlag
      ];
      doCheck = false;
    });
in
{
  inherit xtl xtensor xtensor-python;
}
