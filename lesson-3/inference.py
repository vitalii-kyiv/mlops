import argparse
from pathlib import Path
from typing import List

import torch
from PIL import Image
from torchvision.models import MobileNet_V2_Weights


def load_labels() -> List[str]:
    return MobileNet_V2_Weights.IMAGENET1K_V1.meta["categories"]


def preprocess_image(image_path: Path, device: torch.device) -> torch.Tensor:
    weights = MobileNet_V2_Weights.IMAGENET1K_V1
    transforms = weights.transforms()
    image = Image.open(image_path).convert("RGB")
    tensor = transforms(image).unsqueeze(0).to(device)
    return tensor


def run_inference(model_path: Path, image_path: Path, top_k: int = 3, device: str = "cpu") -> None:
    dev = torch.device(device)
    model = torch.jit.load(model_path, map_location=dev)
    model.eval()

    inputs = preprocess_image(image_path, dev)
    with torch.inference_mode():
        logits = model(inputs)
        probabilities = torch.nn.functional.softmax(logits, dim=1)

    top_prob, top_idx = torch.topk(probabilities, top_k, dim=1)
    labels = load_labels()

    print(f"Top-{top_k} predictions for {image_path}:")
    for prob, idx in zip(top_prob[0], top_idx[0]):
        label = labels[idx]
        print(f"  {label:<30} {prob.item():.4f}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run TorchScript MobileNetV2 inference")
    parser.add_argument("--model", type=Path, default=Path(__file__).with_name("model.pt"), help="Path to TorchScript model")
    parser.add_argument("--image", type=Path, required=True, help="Path to input image")
    parser.add_argument("--top-k", type=int, default=3, help="How many predictions to show")
    parser.add_argument("--device", choices=["cpu", "cuda"], default="cpu", help="Device for inference")
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    run_inference(args.model, args.image, args.top_k, args.device)

