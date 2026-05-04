"""Standalone smoke test for micro-sam.

Loads the model the same way ``server.py`` does and runs a forward pass on a
small synthetic input. Does NOT spin up the IPC server -- the goal here is to
verify the dev shell + model assembly without the network plumbing.

Run from the repo root:
    nix develop --impure --command python basic_test.py

Expected output:
    setup info dict (with cuda:0)
    type and shape of process() result.
"""

import os
import sys

# server.py reads sys.argv[1] at import time; inject a placeholder so
# importing it from this file doesn't crash.
if len(sys.argv) < 2:
    sys.argv.append("ipc:///tmp/microsam_basic_test.ipc")

# PYTHONSAFEPATH=1 (set in flake's runServer/devShell) keeps Python from
# prepending the script's directory to sys.path (which would let the
# in-tree `micro_sam/` source tree shadow the nix-built package). We still
# want `server.py` to be importable, so APPEND the script dir at the tail
# — nix-store packages keep priority.
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

import numpy  # noqa: E402
from server import setup  # noqa: E402


def main() -> None:
    processor, info = setup()
    print(f"setup: {info}")
    assert "cuda" in info["device"], (
        f"Not on GPU! info['device']={info['device']!r}"
    )

    # NCZYX with a single 256x256 greyscale image. SAM warmup is non-trivial,
    # so keep the input small.
    numpy.random.seed(0)
    data = numpy.random.random_sample((1, 1, 1, 256, 256)).astype(numpy.float32)
    out = processor(data)
    print(f"process: {type(out).__name__} {out.shape} dtype={out.dtype} "
          f"max_label={int(out.max())}")


if __name__ == "__main__":
    main()
