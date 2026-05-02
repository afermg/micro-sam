{
  description = "Nahual server wrap for micro-sam (Segment Anything for Microscopy).";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
    flake-utils.url = "github:numtide/flake-utils";
    flake-utils.inputs.systems.follows = "systems";
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
      in
      with pkgs;
      rec {
        # micro-sam pulls in conda-forge-only deps (nifty, vigra Python
        # bindings, torch_em, python-elf) that have no PyPI distribution
        # and would each need significant Nix packaging. We bootstrap a
        # conda environment via micromamba on first run and cache it under
        # ``$XDG_CACHE_HOME/micro-sam/envs``. Subsequent runs reuse it.
        apps.default =
          let
            envYaml = ./nix/env-server.yaml;
            runServer = pkgs.writeScriptBin "runserver.sh" ''
              #!${pkgs.bash}/bin/bash
              set -euo pipefail

              export MAMBA_ROOT_PREFIX="''${MAMBA_ROOT_PREFIX:-$HOME/.cache/micro-sam/mamba}"
              ENV_NAME="micro_sam_server"
              ENV_PREFIX="$MAMBA_ROOT_PREFIX/envs/$ENV_NAME"

              # CUDA libs must be visible to torch's nvrtc / cudnn loader at
              # runtime. /run/opengl-driver/lib carries the NixOS-managed
              # NVIDIA driver libs (libcuda.so etc.) — without it the
              # conda-forge pytorch reports torch.cuda.is_available() == False
              # despite the GPU being present.
              export CUDA_PATH="${pkgs.cudaPackages.cudatoolkit}"
              export LD_LIBRARY_PATH="/run/opengl-driver/lib:${pkgs.cudaPackages.cudatoolkit}/lib:${pkgs.cudaPackages.cudnn}/lib:''${LD_LIBRARY_PATH:-}"

              if [ ! -d "$ENV_PREFIX" ]; then
                echo "[micro-sam] First run: creating conda env at $ENV_PREFIX (one-time, ~10 min cold)..." >&2
                ${pkgs.micromamba}/bin/micromamba create -y -n "$ENV_NAME" -f "${envYaml}"
              fi

              # micro_sam itself lives in the source tree of this flake; expose it.
              export PYTHONPATH="${self}:''${PYTHONPATH:-}"
              # Don't let pooch get confused by per-user XDG_CACHE_HOME redirects.
              export MICROSAM_CACHEDIR="''${MICROSAM_CACHEDIR:-$HOME/.cache/micro_sam}"

              exec ${pkgs.micromamba}/bin/micromamba run -n "$ENV_NAME" \
                python ${self}/server.py "''${@:-ipc:///tmp/microsam.ipc}"
            '';
          in
          {
            type = "app";
            program = "${runServer}/bin/runserver.sh";
          };

        formatter = pkgs.alejandra;

        packages = {
          # Provided so the Nix dev shell exposes `nahual` for tooling.
          # The runtime install happens via pip inside the conda env.
          nahual = pkgs.python3.pkgs.callPackage ./nix/nahual.nix {
            pynng = pkgs.python3Packages.pynng or null;
          };
        };

        devShells = {
          # Dev shell mirrors the runtime: micromamba bootstraps the conda env
          # on entry, then exposes its python3 + the source tree on PATH.
          default =
            let
              envYaml = ./nix/env-server.yaml;
              activate = pkgs.writeShellScriptBin "microsam-activate" ''
                set -e
                export MAMBA_ROOT_PREFIX="''${MAMBA_ROOT_PREFIX:-$HOME/.cache/micro-sam/mamba}"
                ENV_NAME="micro_sam_server"
                ENV_PREFIX="$MAMBA_ROOT_PREFIX/envs/$ENV_NAME"
                if [ ! -d "$ENV_PREFIX" ]; then
                  ${pkgs.micromamba}/bin/micromamba create -y -n "$ENV_NAME" -f "${envYaml}"
                fi
                eval "$(${pkgs.micromamba}/bin/micromamba shell hook -s bash)"
                micromamba activate "$ENV_NAME"
                exec "$@"
              '';
            in
            mkShell {
              packages = [
                pkgs.micromamba
                pkgs.cudaPackages.cudatoolkit
                pkgs.cudaPackages.cudnn
                pkgs.bashInteractive
                activate
              ];
              shellHook = ''
                export MAMBA_ROOT_PREFIX="''${MAMBA_ROOT_PREFIX:-$HOME/.cache/micro-sam/mamba}"
                export CUDA_PATH="${pkgs.cudaPackages.cudatoolkit}"
                # /run/opengl-driver/lib supplies libcuda.so on NixOS;
                # without it conda-forge pytorch sees no GPU.
                export LD_LIBRARY_PATH="/run/opengl-driver/lib:${pkgs.cudaPackages.cudatoolkit}/lib:${pkgs.cudaPackages.cudnn}/lib:''${LD_LIBRARY_PATH:-}"
                export PYTHONPATH="$PWD:''${PYTHONPATH:-}"
                export MICROSAM_CACHEDIR="''${MICROSAM_CACHEDIR:-$HOME/.cache/micro_sam}"

                ENV_NAME="micro_sam_server"
                ENV_PREFIX="$MAMBA_ROOT_PREFIX/envs/$ENV_NAME"
                if [ ! -d "$ENV_PREFIX" ]; then
                  echo "[micro-sam] Bootstrapping conda env at $ENV_PREFIX (one-time)..." >&2
                  ${pkgs.micromamba}/bin/micromamba create -y -n "$ENV_NAME" -f "${./nix/env-server.yaml}"
                fi
                eval "$(${pkgs.micromamba}/bin/micromamba shell hook -s bash)"
                micromamba activate "$ENV_NAME"
              '';
            };
        };
      }
    );
}
