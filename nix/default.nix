{
  lib,
  pkgs,
  python3Packages,
}:
# Aggregate package set: each call uses the merged scope so that downstream
# packages (python-elf, torch_em, micro_sam) pick up our derivations rather
# than the missing-or-stub versions in nixpkgs.
let
  # Pin xtensor / xtl / xtensor-python to a working combo for affogato +
  # nifty (see nix/xtensor_pinned.nix for the rationale).
  xtensorOverlay = import ./xtensor_pinned.nix { inherit lib pkgs python3Packages; };

  scope = pkgs // python3Packages // xtensorOverlay // packages;
  callPackage = lib.callPackageWith scope;
  packages = {
    nahual = callPackage ./nahual.nix { };
    segment_anything = callPackage ./segment_anything.nix { };
    vigra = callPackage ./vigra.nix { };
    affogato = callPackage ./affogato.nix { };
    nifty = callPackage ./nifty.nix { };
    python-elf = callPackage ./python_elf.nix { };
    torch_em = callPackage ./torch_em.nix { };
    micro_sam = callPackage ./micro_sam.nix { };
  };
in
packages
