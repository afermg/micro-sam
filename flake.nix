{
  description = "Nahual server wrap for micro-sam (Segment Anything for Microscopy)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
    flake-utils.url = "github:numtide/flake-utils";
    flake-utils.inputs.systems.follows = "systems";
    nahual-flake.url = "github:afermg/nahual";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  } @ inputs:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            cudaSupport = true;
          };
        };
        python = pkgs.python3.override {
          packageOverrides = pyfinal: pyprev: {
            numba = pyprev.numba.overridePythonAttrs (_: {
              doCheck = false;
              doInstallCheck = false;
              pytestCheckPhase = "true";
              installCheckPhase = "true";
            });
            numbagg = pyprev.numbagg.overridePythonAttrs (_: {
              doCheck = false;
              doInstallCheck = false;
              pytestCheckPhase = "true";
              installCheckPhase = "true";
            });
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
        python_with_pkgs = python.withPackages (pp: [
          ourPackages.nahual
          ourPackages.micro_sam
        ]);
        runServer = pkgs.writeScriptBin "nahual-microsam" ''
          #!${pkgs.bash}/bin/bash
          export PYTHONSAFEPATH=1
          : "''${MICROSAM_CACHEDIR:=''${XDG_CACHE_HOME:-$HOME/.cache}/micro_sam}"
          export MICROSAM_CACHEDIR
          mkdir -p "$MICROSAM_CACHEDIR"
          exec ${python_with_pkgs}/bin/python ${self}/server.py \
            "''${1:-tcp://0.0.0.0:5555}"
        '';
        microsamApp = {
          type = "app";
          program = "${runServer}/bin/nahual-microsam";
        };
      in
        with pkgs; rec {
          formatter = pkgs.alejandra;
          packages =
            {
              inherit
                (ourPackages)
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
            }
            // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
              oci-image = import ./nix/oci-image.nix {
                inherit pkgs;
                name = "microsam";
                title = "Nahual micro-sam";
                description = "Segment Anything for Microscopy served through Nahual";
                source = "https://github.com/afermg/micro-sam";
                revision = self.rev or self.dirtyRev or "unknown";
                server = runServer;
                entrypoint = microsamApp.program;
              };
            };
          inherit python_with_pkgs;
          scripts.runServer = runServer;
          apps = rec {
            microsam = microsamApp;
            default = microsam;
          };
          devShells.default = mkShell {
            packages = [
              python_with_pkgs
              pkgs.cudaPackages.cudatoolkit
              python.pkgs.tifffile
              python.pkgs.scikit-image
              python.pkgs.scikit-learn
              python.pkgs.pyyaml
            ];
            shellHook = ''
              export PYTHONSAFEPATH=1
              : "''${MICROSAM_CACHEDIR:=''${XDG_CACHE_HOME:-$HOME/.cache}/micro_sam}"
              export MICROSAM_CACHEDIR
            '';
          };
        }
    );
}
