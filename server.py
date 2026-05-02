"""Nahual server for micro-sam (Segment Anything for Microscopy).

Loads a Segment Anything model fine-tuned for light microscopy via micro-sam's
``automatic_segmentation`` API and exposes it as a Nahual ``Rep0`` server.

`setup` constructs the SAM predictor + automatic instance segmentation
generator (AIS by default for ``vit_b_lm`` since the model ships a decoder).
`process` accepts a 5-D ``NCZYX`` numpy array and returns an instance label
map ``(N, H, W)``.

Run with:
    nix run --impure . -- ipc:///tmp/microsam.ipc
or:
    python server.py ipc:///tmp/microsam.ipc

Notes:
- We avoid importing ``napari`` / ``micro_sam.sam_annotator`` here since they
  pull in Qt and would force a heavy GUI stack into the dev shell. The
  ``micro_sam.automatic_segmentation`` entry point only imports napari
  conditionally inside the ``annotate=True`` branch, which we never use.
- SAM weights are downloaded by ``pooch`` to ``$MICROSAM_CACHEDIR`` (or
  ``~/.cache/micro_sam`` by default) on first call to ``get_sam_model``;
  warmup adds 10-20s for the ``vit_b_lm`` checkpoint (~370 MB).
"""

import sys
from functools import partial
from typing import Callable

import numpy
import pynng
import torch
import trio
from nahual.server import responder

# server.py captures argv[1] at import time; basic_test.py injects a
# placeholder before importing this module.
address = sys.argv[1]


def setup(
    model_type: str = "vit_b_lm",
    device: int | None = None,
    checkpoint: str | None = None,
    segmentation_mode: str | None = None,
    is_tiled: bool = False,
) -> tuple[Callable, dict]:
    """Load the micro-sam predictor + segmenter and return ``(processor, info)``.

    The ``info`` dict is JSON-serialized back to the client. It always
    contains a ``device`` key so the user can confirm GPU placement.
    """
    # Local import: importing micro_sam at module top would fan out into
    # nifty / vigra / torch_em which is acceptable, but we still keep it
    # inside setup so the basic_test placeholder for argv works first.
    from micro_sam.automatic_segmentation import (
        automatic_instance_segmentation,
        get_predictor_and_segmenter,
    )

    if device is None:
        device = 0
    if torch.cuda.is_available():
        torch_device = torch.device(int(device) if isinstance(device, int) else device)
    else:
        torch_device = torch.device("cpu")

    predictor, segmenter = get_predictor_and_segmenter(
        model_type=model_type,
        checkpoint=checkpoint,
        device=torch_device,
        segmentation_mode=segmentation_mode,
        is_tiled=is_tiled,
    )

    info = {
        "device": str(torch_device),
        "model_type": model_type,
        "segmentation_mode": segmentation_mode or "auto",
        "is_tiled": is_tiled,
    }

    processor = partial(
        process,
        predictor=predictor,
        segmenter=segmenter,
        run=automatic_instance_segmentation,
    )
    return processor, info


def process(
    pixels: numpy.ndarray,
    predictor,
    segmenter,
    run: Callable,
    **generate_kwargs,
) -> numpy.ndarray:
    """Run automatic instance segmentation per image.

    Accepts a 5-D ``NCZYX`` numpy array. Z is squeezed (we expect singleton),
    each (C, H, W) image is collapsed across channels (mean) before being
    passed to micro-sam — the underlying SAM expects a 2-D / 3-D image.

    Returns
    -------
    numpy.ndarray
        Instance label map of shape ``(N, H, W)``.
    """
    if pixels.ndim != 5:
        raise ValueError(f"Expected NCZYX (5D) array, got shape {pixels.shape}")

    n, c, z, h, w = pixels.shape
    if z != 1:
        # Squeeze any singleton; otherwise pick the first plane.
        pixels = pixels[:, :, 0, :, :]
    else:
        pixels = pixels[:, :, 0, :, :]

    out = numpy.zeros((n, h, w), dtype=numpy.int32)
    for i in range(n):
        img = pixels[i]  # (C, H, W)
        # SAM expects either single-channel 2D or RGB 3D in HWC layout.
        if c == 1:
            img2d = img[0]
        elif c == 3:
            img2d = numpy.transpose(img, (1, 2, 0))
        else:
            # Collapse arbitrary channel counts to a single greyscale plane.
            img2d = img.mean(axis=0)

        instances = run(
            predictor=predictor,
            segmenter=segmenter,
            input_path=img2d,
            ndim=2,
            verbose=False,
            **generate_kwargs,
        )
        out[i] = instances.astype(numpy.int32)

    return out


async def main():
    with pynng.Rep0(listen=address, recv_timeout=300) as sock:
        print(f"micro-sam server listening on {address}", flush=True)
        async with trio.open_nursery() as nursery:
            nursery.start_soon(partial(responder, setup=setup), sock)


if __name__ == "__main__":
    try:
        trio.run(main)
    except KeyboardInterrupt:
        pass
