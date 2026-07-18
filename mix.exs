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
        see_through_compositor: [include_executables_for: [:unix]]
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
      # Hex release (not the git fork): our tool is a single fast GPU tensor
      # pass, so the hex release's 10s tools/call timeout — too short for
      # easy-diffusion-mcp's slow SD inference — isn't a concern here.
      {:ex_mcp, "~> 0.12"},
      {:plug_cowboy, "~> 2.7"},
      {:jason, "~> 1.4"}
    ]
  end
end
