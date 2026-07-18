# see-through-layer-compositor-cog

The smallest useful Replicate [cog](https://github.com/replicate/cog) model
built from a real piece of [See-Through](https://github.com/weftspun/see-through)
(SIGGRAPH 2026): its alpha-compositing ops, `blend_over` and `alpha_floor`
(`see-through-cpp/src/see_through.cpp`), used to reassemble the paper's
decomposed anime-character layers back into a final image.

Ported to [Nx](https://hexdocs.pm/nx)/[EXLA](https://hexdocs.pm/exla) (CUDA)
in `lib/see_through_compositor/tensor_ops.ex`, exposed as an
[MCP](https://modelcontextprotocol.io) tool (`composite_layers`) via
[ex_mcp](https://github.com/weftspun/ex_mcp), and packaged for Replicate via
`cog.yaml`. No external model weights — this is pure tensor math, so there's
nothing to download and nothing blocked on a model-serving API (unlike the
full decomposition pipeline, which needs the still-unresolved Bumblebee
model-loading API — see `see-through-burrito/BLOCKERS.md`).

## Run directly (Elixir)

```sh
export XLA_TARGET=cuda12   # GPU-mandatory: no CPU fallback
mix deps.get
mix run --no-halt
```

MCP endpoint: `http://localhost:5244/mcp` (`PORT` to change). Health check:
`GET /health`.

## Run via cog

```sh
cog build
cog predict -i background=@bg.png -i foreground=@layer.png -i alpha_threshold=0.06
```

`run.py` starts the compiled Elixir release, waits for `/health`, then
proxies both images to the `composite_layers` MCP tool and returns the
composited result.
