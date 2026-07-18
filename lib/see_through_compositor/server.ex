defmodule SeeThroughCompositor.Server do
  @moduledoc """
  MCP server exposing `composite_layers`: alpha-composite a foreground RGBA
  layer over a background RGBA layer on the GPU, via
  `SeeThroughCompositor.TensorOps.composite/3` (ported from See-Through's
  `blend_over` / `alpha_floor`).
  """

  use ExMCP.Server.Handler
  use ExMCP.Server.DSL, name: "see-through-layer-compositor-mcp"

  alias SeeThroughCompositor.TensorOps

  tool "composite_layers",
       "Alpha-composite a foreground RGBA layer over a background RGBA layer on the GPU" do
    param(:background, :string,
      required: true,
      description: "Base64-encoded background image (any format; alpha added if missing)"
    )

    param(:foreground, :string,
      required: true,
      description: "Base64-encoded foreground RGBA image, same dimensions as background"
    )

    param(:alpha_threshold, :number,
      required: false,
      description: "Foreground alpha values below this (0-1) are zeroed before blending (default 15/255)"
    )

    run(fn args, state ->
      threshold = Map.get(args, :alpha_threshold) || Map.get(args, "alpha_threshold") || 15.0 / 255.0
      bg_b64 = Map.get(args, :background) || Map.get(args, "background")
      fg_b64 = Map.get(args, :foreground) || Map.get(args, "foreground")

      with {:ok, bg_tensor} <- load_rgba(bg_b64),
           {:ok, fg_tensor} <- load_rgba(fg_b64),
           :ok <- check_same_shape(bg_tensor, fg_tensor) do
        composited =
          TensorOps.composite(to_float(bg_tensor), to_float(fg_tensor), threshold)
          |> from_float()

        case Image.from_nx(composited) do
          {:ok, out_image} ->
            {:ok, out_bytes} = Image.write(out_image, :memory, suffix: ".png")
            data = Base.encode64(out_bytes)
            {:ok, %{content: [ExMCP.Content.image(data, "image/png")]}, state}

          {:error, reason} ->
            {:error, "Failed to encode composited image: #{inspect(reason)}", state}
        end
      else
        {:error, reason} -> {:error, "Composite failed: #{inspect(reason)}", state}
      end
    end)
  end

  defp load_rgba(b64) do
    with {:ok, bytes} <- decode_image(b64),
         {:ok, image} <- Image.from_binary(bytes),
         {:ok, rgba_image} <- ensure_alpha(image),
         {:ok, tensor} <- Image.to_nx(rgba_image) do
      {:ok, tensor}
    end
  end

  defp ensure_alpha(image) do
    if Image.has_alpha?(image) do
      {:ok, image}
    else
      Image.add_alpha(image)
    end
  end

  defp check_same_shape(a, b) do
    if Nx.shape(a) == Nx.shape(b) do
      :ok
    else
      {:error, {:shape_mismatch, Nx.shape(a), Nx.shape(b)}}
    end
  end

  defp to_float(u8_tensor), do: Nx.divide(Nx.as_type(u8_tensor, :f32), 255.0)

  defp from_float(f32_tensor),
    do: f32_tensor |> Nx.multiply(255.0) |> Nx.clip(0, 255) |> Nx.as_type(:u8)

  defp decode_image("data:" <> rest) do
    case String.split(rest, ",", parts: 2) do
      [_header, data] -> Base.decode64(data)
      _ -> {:error, :invalid_data_url}
    end
  end

  defp decode_image(b64) when is_binary(b64), do: Base.decode64(b64)
  defp decode_image(_), do: {:error, :missing_image}
end
