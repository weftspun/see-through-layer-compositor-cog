# bootc appliance image: boots directly on bare metal (via bootc-image-builder)
# instead of running as an ordinary container. Base is AlmaLinux 9 — a 1:1
# RHEL 9 rebuild with a full ~10-year lifecycle (unlike CentOS Stream 9,
# whose lifecycle tracks RHEL 9's *development* stream and ends ~2027).
# Same glibc 2.34 / EL9 as CentOS Stream, matching the ASWF VFX Reference
# Platform's CY2027 direction: https://vfxplatform.com/. AlmaLinux's own
# bootc images are labeled "currently experimental" as of this writing —
# a real caveat for a factory-floor deployment, weighed against RHEL
# itself requiring a subscription.
FROM quay.io/almalinuxorg/almalinux-bootc:9

# Self-contained executable (bundles ERTS/BEAM via Burrito) built and
# published from this repo — see mix.exs's `burrito` release config and
# README.md for how to rebuild it. No Elixir/Erlang/build toolchain needed
# in this image.
RUN curl -fsSL -o /opt/see_through_compositor \
      https://github.com/weftspun/see-through-layer-compositor-cog/releases/download/v0.1.0/see_through_compositor_linux_x86_64 && \
    chmod +x /opt/see_through_compositor

# EXLA's precompiled CUDA XLA extension needs four runtime libs this base
# image doesn't ship — NVSHMEM, NVRTC builtins, NCCL, and cuDNN — each
# pinned to a specific version by deps/xla's HERMETIC_*_VERSION for the
# cuda12 target (see deps/xla/lib/xla.ex). All ship as PyPI NVIDIA wheels;
# `pip` here is just used as a zip-extraction convenience (these are
# regular shared libraries, not a Python runtime dependency of the app).
RUN dnf install -y python3-pip && \
    pip3 install --no-deps --target /opt/cuda-extra-libs \
      nvidia-nvshmem-cu12==3.3.9 \
      nvidia-cuda-nvrtc-cu12==12.9.86 \
      nvidia-nccl-cu12==2.27.7 \
      nvidia-cudnn-cu12==9.8.0.87 && \
    dnf remove -y python3-pip && \
    dnf clean all

# NVIDIA GPU driver: installed via the standard dnf/CUDA-repo path (the
# documented, RHEL-recommended mechanism for RHEL-family GPU hosts —
# see NVIDIA's CUDA installation guide for RHEL9/EL9), not baked into this
# image. The GPU Operator / a build-time driver layer builds the kernel
# module against this image's own bundled kernel; see README.md.

COPY systemd/see-through-compositor.service /usr/lib/systemd/system/see-through-compositor.service
RUN systemctl enable see-through-compositor.service
