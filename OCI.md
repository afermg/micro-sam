# micro-sam Nahual OCI image

Build the reproducible archive and load it into Podman or Docker:

```console
nix build .#oci-image
podman load < result                         # or: docker load < result
```

The image is tagged `nahual/microsam:local` and listens on TCP port 5555. The
pretrained `vit_b_lm` checkpoint is downloaded on first setup, so persist
`/tmp/nahual` as a model cache:

```console
podman run --rm --device nvidia.com/gpu=all -p 5555:5555 \
  -v nahual-microsam-cache:/tmp/nahual nahual/microsam:local
```

For Docker, replace the CDI device option with `--gpus all`. CPU operation is
supported but substantially slower than GPU inference. With Nahual and NumPy
installed on the host, run pretrained end-to-end segmentation with:

```console
NAHUAL_DEVICE=cpu python oci/smoke_test.py
```

Additional micro-sam model types or a mounted custom checkpoint can be selected
through the Nahual setup parameters.
