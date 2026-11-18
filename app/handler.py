"""Lambda handler that reports GPU visibility and benchmarks matrix multiplication on CPU and GPU."""

import os
import time

import torch

# 呼び出し元はIAMで認可されるが、巨大な値でメモリを使い切らないよう上限を設ける。
MAX_SIZE = 8192
MAX_REPEAT = 50


def _driver_version():
    """Return the NVIDIA driver version string exposed by the host, if any."""
    try:
        with open("/proc/driver/nvidia/version") as f:
            return f.readline().strip()
    except OSError:
        return None


def _gpu_info():
    """Return properties of the first visible CUDA device, or None when no GPU is visible."""
    if not torch.cuda.is_available():
        return None
    props = torch.cuda.get_device_properties(0)
    return {
        "name": props.name,
        "device_count": torch.cuda.device_count(),
        "total_memory_gib": round(props.total_memory / 1024**3, 2),
        "compute_capability": f"{props.major}.{props.minor}",
    }


def _benchmark(device, size, repeat):
    """Measure the average time of a float32 square matrix multiplication on the given device."""
    a = torch.randn(size, size, device=device)
    b = torch.randn(size, size, device=device)
    # 初回はカーネルのロードなどが入るので計測から外す。
    torch.matmul(a, b)
    if device == "cuda":
        torch.cuda.synchronize()
    start = time.perf_counter()
    for _ in range(repeat):
        torch.matmul(a, b)
    # GPUの演算は非同期なので、完了を待ってから時間を取る。
    if device == "cuda":
        torch.cuda.synchronize()
    seconds = (time.perf_counter() - start) / repeat
    return {
        "device": device,
        "size": size,
        "repeat": repeat,
        "seconds_per_matmul": round(seconds, 6),
        "tflops": round(2 * size**3 / seconds / 1e12, 3),
    }


def handler(event, context):
    """Return GPU information and CPU/GPU matmul benchmark results."""
    if not isinstance(event, dict):
        event = {}
    size = max(1, min(int(event.get("size", 4096)), MAX_SIZE))
    repeat = max(1, min(int(event.get("repeat", 10)), MAX_REPEAT))

    benchmarks = [_benchmark("cpu", size, max(1, repeat // 5))]
    if torch.cuda.is_available():
        benchmarks.append(_benchmark("cuda", size, repeat))

    return {
        "torch_version": torch.__version__,
        "cuda_runtime_version": torch.version.cuda,
        "cuda_available": torch.cuda.is_available(),
        "driver_version": _driver_version(),
        "gpu": _gpu_info(),
        "cpu_count": os.cpu_count(),
        # Dockerfileで USER を指定していないため、どのユーザーで実行されるかを確認する。
        "uid": os.getuid(),
        "env": {k: os.environ.get(k) for k in ("NVIDIA_VISIBLE_DEVICES", "CUDA_VISIBLE_DEVICES", "NVIDIA_DRIVER_CAPABILITIES")},
        "benchmarks": benchmarks,
    }
