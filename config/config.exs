import Config

# GPU-mandatory: no CPU fallback. Compilation fails unless XLA_TARGET names a
# CUDA target.
unless System.get_env("XLA_TARGET", "") |> String.starts_with?("cuda") do
  raise """
  GPU required: XLA_TARGET is not set to a CUDA target.

    export XLA_TARGET=cuda12   # or cuda13

  See cog.yaml for how the container sets this.
  """
end

config :nx,
  default_backend: EXLA.Backend,
  default_defn_options: [compiler: EXLA]

config :exla,
  clients: [cuda: [platform: :cuda]],
  default_client: :cuda
