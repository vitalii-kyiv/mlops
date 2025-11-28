import argparse
from pathlib import Path

import torch
from torchvision.models import MobileNet_V2_Weights, mobilenet_v2


def export_torchscript_model(output_path: Path, device: str = "cpu") -> None:
    weights = MobileNet_V2_Weights.IMAGENET1K_V1
    model = mobilenet_v2(weights=weights).to(device)
    model.eval()

    example = torch.randn(1, 3, 224, 224, device=device)
    traced = torch.jit.trace(model, example)
    traced.save(str(output_path))
    print(f"Saved TorchScript model to {output_path}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Export MobileNetV2 to TorchScript")
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parent / "model.pt",
        help="Output path for TorchScript model",
    )
    parser.add_argument(
        "--device",
        default="cpu",
        choices=["cpu", "cuda"],
        help="Device for tracing (default: cpu)",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    export_torchscript_model(args.output, args.device)

