# /usr/bin/env python
"""
This example uses a server within the environment defined on `https://github.com/afermg/micro-sam.git`.

Run `nix run github:afermg/micro-sam -- ipc:///tmp/microsam.ipc` from any directory,
or `nix develop --command bash -c "python server.py ipc:///tmp/microsam.ipc"` from
the root of that repository.

micro-sam is "micro_sam" — Segment Anything for Microscopy. The default
``vit_b_lm`` checkpoint runs automatic instance segmentation (AIS) using
SAM's decoder; expect a ~370 MB weight download on first server start.
"""

import numpy

from nahual.process import dispatch_setup_process

# microsam isn't in nahual's built-in registry yet — pass the signature
# explicitly so dispatch builds the right (dict, numpy) RPC pair.
setup, process = dispatch_setup_process("microsam", signature=("dict", "numpy"))
address = "ipc:///tmp/microsam.ipc"

# %% Load model server-side
parameters = {
    # Override defaults if you want; e.g. "model_type": "vit_b", "device": 1.
}
response = setup(parameters, address=address)
print(response)
# Expected:
# {'device': 'cuda:0', 'model_type': 'vit_b_lm', 'segmentation_mode': 'auto', 'is_tiled': False}

# %% Define custom data — 5-D NCZYX (Z is squeezed server-side).
tile_size = 256
numpy.random.seed(seed=42)
data = numpy.random.random_sample((1, 1, 1, tile_size, tile_size)).astype("float32")
result = process(data, address=address)
print(f"Shape: {result.shape}, Max: {result.max()}")
# Expected: Shape: (1, 256, 256), Max: <small int> (random noise rarely yields instances)
