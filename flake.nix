{
  description = "Nahual server wrap for micro-sam (Segment Anything for Microscopy).";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
    flake-utils.url = "github:numtide/flake-utils";
    flake-utils.inputs.systems.follows = "systems";
    nahual-flake.url = "github:afermg/nahual";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      systems,
      ...
    }@inputs:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          system = system;
          config = {
            allowUnfree = true;
            # GPU is required. micro-sam ships SAM weights that target CUDA;
            # CPU inference is impractically slow.
            cudaSupport = true;
          };
        };

        # Pin to the default python (3.13 on current unstable). vigra,
        # nifty, affogato all build their pybind11 modules against this
        # interpreter; bumping it forces a full C++ rebuild of all three.
        # We further override numba's pytestCheckPhase: turning on
        # cudaSupport flips the closure off the binary cache, so
        # nixpkgs would otherwise re-run numba's 30+ min serial test
        # suite on every dev shell.
        python = pkgs.python3.override {
          packageOverrides = pyfinal: pyprev: {
            numba = pyprev.numba.overridePythonAttrs (_: {
              doCheck = false;
              doInstallCheck = false;
              pytestCheckPhase = "true";
              installCheckPhase = "true";
            });
            # numbagg's pytest also takes ~15 min on the cuda-enabled
            # closure. Skip it -- our import path goes through
            # xarray->numbagg only at module-load time.
            numbagg = pyprev.numbagg.overridePythonAttrs (_: {
              doCheck = false;
              doInstallCheck = false;
              pytestCheckPhase = "true";
              installCheckPhase = "true";
            });
            # Same story for xarray: cudaSupport-enabled scope means we
            # rebuild it from scratch, and its pytest suite is huge
            # (and downloads test fixtures from the network in the
            # sandbox, which then hangs).
            xarray = pyprev.xarray.overridePythonAttrs (_: {
              doCheck = false;
              doInstallCheck = false;
              pytestCheckPhase = "true";
              installCheckPhase = "true";
            });
          };
        };

        ourPackages = pkgs.callPackage ./nix {
          python3Packages = python.pkgs;
          nahualSrc = inputs.nahual-flake;
        };
      in
      with pkgs;
      rec {
        formatter = pkgs.alejandra;

        # Re-pack as a simple attrset so `nix flake check` doesn't try to
        # treat passthru / override functions as derivations.
        packages = {
          inherit (ourPackages)
            nahual
            segment_anything
            vigra
            affogato
            nifty
            python-elf
            torch_em
            micro_sam
            ;
          default = ourPackages.micro_sam;
        };

        apps.default =
          let
            python_with_pkgs = python.withPackages (pp: [
              ourPackages.nahual
              ourPackages.micro_sam
              # micro_sam already depends on segment_anything / torch_em /
              # python-elf / nifty / vigra transitively. Listed here for
              # debuggability of `nix run` env.
            ]);
            runServer = pkgs.writeScriptBin "runserver.sh" ''
              #!${pkgs.bash}/bin/bash
              ${python_with_pkgs}/bin/python ${self}/server.py ''${@:-"ipc:///tmp/microsam.ipc"}
            '';
          in
          {
            type = "app";
            program = "${runServer}/bin/runserver.sh";
          };

        devShells = {
          default =
            let
              python_with_pkgs = python.withPackages (pp: [
                ourPackages.nahual
                ourPackages.micro_sam
                # Dev-only extras the basic_test / client examples touch.
                pp.tifffile
                pp.scikit-image
                pp.scikit-learn
                pp.pyyaml
              ]);
            in
            mkShell {
              packages = [
                python_with_pkgs
                pkgs.cudaPackages.cudatoolkit
              ];
              shellHook = ''
                export PYTHONPATH=${python_with_pkgs}/${python_with_pkgs.sitePackages}:$PYTHONPATH
              '';
            };
        };
      }
    );
}
