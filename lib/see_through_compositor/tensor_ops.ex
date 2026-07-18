defmodule SeeThroughCompositor.TensorOps do
  @moduledoc """
  Alpha-compositing ops from the See-Through pipeline
  (see-through-cpp/src/see_through.cpp), ported to Nx/EXLA.

  Both functions operate on `{h, w, 4}` RGBA float tensors in `[0, 1]`.
  """

  import Nx.Defn

  @doc """
  Alpha-blend `src_rgba` over `dst_rgba` ("blend_over"):
  `out = src * src.alpha + dst * (1 - src.alpha)`, alpha channels composited
  the same way.
  """
  defn alpha_blend(dst_rgba, src_rgba) do
    h = Nx.axis_size(src_rgba, 0)
    w = Nx.axis_size(src_rgba, 1)

    src_alpha = Nx.slice(src_rgba, [0, 0, 3], [h, w, 1])
    src_rgb = Nx.slice(src_rgba, [0, 0, 0], [h, w, 3])
    dst_rgb = Nx.slice(dst_rgba, [0, 0, 0], [h, w, 3])
    dst_alpha = Nx.slice(dst_rgba, [0, 0, 3], [h, w, 1])

    blended_rgb =
      Nx.add(
        Nx.multiply(src_rgb, src_alpha),
        Nx.multiply(dst_rgb, Nx.subtract(1.0, src_alpha))
      )

    blended_alpha = Nx.add(src_alpha, Nx.multiply(dst_alpha, Nx.subtract(1.0, src_alpha)))

    Nx.concatenate([blended_rgb, blended_alpha], axis: 2)
  end

  @doc """
  Zero out alpha below `threshold` ("alpha_floor") — removes soft-mask noise
  from layer edges before compositing.
  """
  defn alpha_floor(rgba_tensor, threshold \\ 15.0 / 255.0) do
    h = Nx.axis_size(rgba_tensor, 0)
    w = Nx.axis_size(rgba_tensor, 1)

    alpha = Nx.slice(rgba_tensor, [0, 0, 3], [h, w, 1])
    floored_alpha = Nx.select(Nx.less(alpha, threshold), Nx.tensor(0.0), alpha)
    rgb = Nx.slice(rgba_tensor, [0, 0, 0], [h, w, 3])

    Nx.concatenate([rgb, floored_alpha], axis: 2)
  end

  @doc "alpha_floor(src) then alpha_blend(dst, src) — the two ops as used together in the pipeline."
  defn composite(dst_rgba, src_rgba, threshold \\ 15.0 / 255.0) do
    alpha_blend(dst_rgba, alpha_floor(src_rgba, threshold))
  end
end
