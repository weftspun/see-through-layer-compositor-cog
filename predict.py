"""Cog predictor: launches the compiled Elixir MCP release and proxies
predict() calls to its `composite_layers` MCP tool over HTTP."""

import base64
import subprocess
import tempfile
import time
from pathlib import Path as PyPath

import requests
from cog import BasePredictor, Input, Path

RELEASE_BIN = "/app/_build/prod/rel/see_through_compositor/bin/see_through_compositor"
BASE_URL = "http://localhost:5244"


class Predictor(BasePredictor):
    def setup(self):
        self.proc = subprocess.Popen([RELEASE_BIN, "start"])
        self._wait_healthy(timeout=60)

    def _wait_healthy(self, timeout):
        deadline = time.time() + timeout
        while time.time() < deadline:
            try:
                r = requests.get(f"{BASE_URL}/health", timeout=2)
                if r.status_code == 200:
                    return
            except requests.RequestException:
                pass
            time.sleep(1)
        raise RuntimeError("see-through-layer-compositor-mcp server did not become healthy in time")

    def predict(
        self,
        background: Path = Input(description="Background layer image"),
        foreground: Path = Input(description="Foreground RGBA layer image (composited on top)"),
        alpha_threshold: float = Input(
            description="Foreground alpha values below this (0-1) are zeroed before blending",
            default=15.0 / 255.0,
            ge=0.0,
            le=1.0,
        ),
    ) -> Path:
        bg_b64 = base64.b64encode(PyPath(background).read_bytes()).decode()
        fg_b64 = base64.b64encode(PyPath(foreground).read_bytes()).decode()

        resp = requests.post(
            f"{BASE_URL}/mcp",
            json={
                "jsonrpc": "2.0",
                "id": 1,
                "method": "tools/call",
                "params": {
                    "name": "composite_layers",
                    "arguments": {
                        "background": bg_b64,
                        "foreground": fg_b64,
                        "alpha_threshold": alpha_threshold,
                    },
                },
            },
            headers={"Content-Type": "application/json", "Accept": "application/json"},
            timeout=120,
        )
        resp.raise_for_status()
        result = resp.json()

        if "error" in result:
            raise RuntimeError(f"composite_layers failed: {result['error']}")

        content = result["result"]["content"]
        image_part = next(c for c in content if c.get("type") == "image")
        out_bytes = base64.b64decode(image_part["data"])

        out_path = PyPath(tempfile.mkdtemp()) / "output.png"
        out_path.write_bytes(out_bytes)
        return Path(out_path)
