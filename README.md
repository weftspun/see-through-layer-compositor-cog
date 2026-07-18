# see-through-layer-compositor-cog

A real piece of [See-Through](https://github.com/weftspun/see-through)
(SIGGRAPH 2026): its alpha-compositing ops, `blend_over` and `alpha_floor`
(`see-through-cpp/src/see_through.cpp`), used to reassemble the paper's
decomposed anime-character layers back into a final image.

Ported to [Nx](https://hexdocs.pm/nx)/[EXLA](https://hexdocs.pm/exla) (CUDA)
in `lib/see_through_compositor/tensor_ops.ex`, exposed as an
[MCP](https://modelcontextprotocol.io) tool (`composite_layers`) via
[ex_mcp](https://github.com/weftspun/ex_mcp) (weftspun's fork — see mix.exs).
No external model weights — this is pure tensor math, so there's nothing to
download and nothing blocked on a model-serving API (unlike the full
decomposition pipeline, which needs the still-unresolved Bumblebee
model-loading API — see `see-through-burrito/BLOCKERS.md`).

Packaged as a **bootc appliance image** — boots directly on bare metal as a
single-purpose GPU "factory machine" rather than running as a general
server. See `Containerfile`.

## Run directly (Elixir)

```sh
export XLA_TARGET=cuda12   # GPU-mandatory: no CPU fallback
mix deps.get
mix run --no-halt
```

MCP endpoint: `http://localhost:5244/mcp` (`PORT` to change). Health check:
`GET /health`.

## Build the release binary

The image doesn't compile Elixir/CUDA itself — it fetches a prebuilt,
self-contained executable (bundled via
[Burrito](https://github.com/burrito-elixir/burrito)) published as a GitHub
release asset. To rebuild that asset after a `lib/` or `mix.exs` change:

```sh
# Build inside a container matching the deployment base's glibc (EL9) —
# Burrito's default "universal" ERTS uses a musl loader shim that can't
# resolve EXLA's glibc-linked CUDA runtime deps; see mix.exs for why
# custom_erts + skip_nifs are set.
XLA_TARGET=cuda12 MIX_ENV=prod mix release --overwrite
gh release upload v0.1.0 burrito_out/see_through_compositor_linux_x86_64 --clobber
```

## Build the appliance image

```sh
podman build -t see-through-compositor-bootc -f Containerfile .
```

This fetches the release binary above plus four pinned NVIDIA CUDA runtime
libraries EXLA's precompiled CUDA XLA extension needs (NVSHMEM, NVRTC,
NCCL, cuDNN — versions pinned by `deps/xla`'s `HERMETIC_*_VERSION` for the
`cuda12` target; see `Containerfile` for exact versions and why they're
needed beyond what the base image's CUDA toolkit ships), and enables
`systemd/see-through-compositor.service`.

To produce an actual bootable image (ISO / raw disk) from this container
image, use
[bootc-image-builder](https://github.com/osbuild/bootc-image-builder) — not
yet done/tested here; NVIDIA GPU driver installation on the target hardware
(via the standard dnf/CUDA-repo path) is also not yet validated end-to-end.

## Base image: why AlmaLinux 9, not CentOS Stream 9

Both are EL9 (glibc 2.34) and behave identically for this build, but their
support lifecycles differ a lot: CentOS Stream 9 tracks RHEL 9's
*development* stream and ends around 2027, while AlmaLinux 9 is a 1:1 RHEL 9
rebuild with the full ~10-year RHEL lifecycle — the relevant one for
long-running industrial/appliance hardware. AlmaLinux's own bootc images are
labeled "currently experimental" as of this writing, a real tradeoff against
RHEL's own (subscription-gated) production-grade bootc support.

This also happens to align with where the [ASWF VFX Reference
Platform](https://vfxplatform.com/) is headed: its CY2027 draft moves to
glibc 2.34, "which effectively mandates that everyone should be on an EL9
Linux OS (or equivalent)."
