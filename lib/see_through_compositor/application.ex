defmodule SeeThroughCompositor.Application do
  @moduledoc """
  OTP application: starts a Cowboy endpoint serving the GPU (EXLA) layer
  compositor MCP server over HTTP.

  Runtime env:

    * `PORT` — listen port (default `5244`).
  """

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    port = String.to_integer(System.get_env("PORT", "5244"))

    Logger.info("see-through-layer-compositor-mcp listening on 0.0.0.0:#{port}")

    children = [
      {Plug.Cowboy,
       scheme: :http,
       plug: SeeThroughCompositor.Router,
       options: [port: port, ip: {0, 0, 0, 0}]}
    ]

    Supervisor.start_link(children,
      strategy: :one_for_one,
      name: SeeThroughCompositor.Supervisor
    )
  end
end
