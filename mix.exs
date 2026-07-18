defmodule SeeThroughCompositor.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :see_through_compositor,
      version: @version,
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        see_through_compositor: [
          include_executables_for: [:unix],
          steps: [:assemble, &Burrito.wrap/1],
          burrito: [
            # The cog GPU base image is Ubuntu 22.04 x86_64 (glibc), so
            # only that target is built — Burrito otherwise defaults to
            # building for every OS/arch it supports.
            #
            # custom_erts pins Burrito to the build machine's own ERTS
            # instead of its default "universal" precompiled ERTS, which
            # gets its portability across glibc versions by patching the
            # extracted beam.smp's ELF interpreter to a bundled musl libc
            # shim. That shim doesn't consult glibc's ld.so.cache, so it
            # can't resolve EXLA's precompiled (glibc-linked) CUDA XLA
            # extension's runtime deps (NVSHMEM, NVRTC, libcuda) — the
            # release must therefore be built inside a container matching
            # the cog base image (Ubuntu 22.04 / glibc 2.35), not on an
            # arbitrary dev machine.
            targets: [
              linux_x86_64: [
                os: :linux,
                cpu: :x86_64,
                custom_erts: System.get_env("BURRITO_CUSTOM_ERTS", "/usr/local/lib/erlang")
              ]
            ]
          ]
        ]
      ],
      description:
        "MCP server exposing See-Through's GPU (EXLA) alpha-compositing ops (blend_over / alpha_floor) as a Replicate cog model",
      source_url: "https://github.com/weftspun/see-through-layer-compositor-cog"
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {SeeThroughCompositor.Application, []}
    ]
  end

  defp deps do
    [
      {:nx, "~> 0.12"},
      # Pinned to the 0.12.x line: 0.13.0 (released 2026-07-17) ships a
      # broken CUDA custom_calls build (OutputBuffer() called with the
      # wrong arity in runtime_callback_cuda.cc).
      {:exla, "~> 0.12.0"},
      {:image, "~> 0.71"},
      # weftspun's fork (not the Hex release): the Hex-published ex_mcp
      # 0.12.0 has no ExMCP.Server.DSL module (the `tool`/`param`/`run`
      # DSL this server uses only exists in the fork's lib/ex_mcp/server/dsl.ex).
      {:ex_mcp, github: "weftspun/ex_mcp", ref: "fd535127e0ef198a974469a7a38325ee49dce531"},
      {:plug_cowboy, "~> 2.7"},
      {:jason, "~> 1.4"},
      {:burrito, "~> 1.0"}
    ]
  end
end
