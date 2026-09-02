#!/usr/bin/env python3
"""
CP4: QLoRA fine-tune with Unsloth (run on Linux CUDA or Colab).

  pip install unsloth bitsandbytes
  python training/train_qlora_unsloth.py --train data/split/train.jsonl --output-dir out/lora

Requires Hugging Face access to the base model (accept license on the hub).
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def load_jsonl_messages(path: Path) -> list[dict]:
    rows: list[dict] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        obj = json.loads(line)
        if isinstance(obj, dict) and "messages" in obj:
            rows.append(obj)
    return rows


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--train", type=Path, required=True, help="train.jsonl (messages format)")
    p.add_argument("--output-dir", type=Path, default=Path("out/lora"))
    p.add_argument(
        "--base-model",
        default="meta-llama/Meta-Llama-3.1-8B-Instruct",
        help="Pin a specific revision on the hub for reproducibility.",
    )
    p.add_argument("--max-seq-length", type=int, default=4096)
    p.add_argument("--epochs", type=float, default=1.0)
    p.add_argument("--batch-size", type=int, default=2)
    p.add_argument("--lora-r", type=int, default=16)
    p.add_argument("--lora-alpha", type=int, default=16)
    args = p.parse_args()

    try:
        from unsloth import FastLanguageModel  # type: ignore  # noqa: PLC0415
        from trl import SFTTrainer  # type: ignore  # noqa: PLC0415
        from transformers import TrainingArguments  # noqa: PLC0415
        from datasets import Dataset  # noqa: PLC0415
    except ImportError as e:
        raise SystemExit(
            "Install training deps on a CUDA machine: pip install unsloth trl datasets transformers accelerate bitsandbytes\n"
            f"Import error: {e}"
        ) from e

    records = load_jsonl_messages(args.train)
    if not records:
        raise SystemExit("No training rows found.")
    dataset = Dataset.from_list(records)

    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name=args.base_model,
        max_seq_length=args.max_seq_length,
        load_in_4bit=True,
    )

    model = FastLanguageModel.get_peft_model(
        model,
        r=args.lora_r,
        target_modules=[
            "q_proj",
            "k_proj",
            "v_proj",
            "o_proj",
            "gate_proj",
            "up_proj",
            "down_proj",
        ],
        lora_alpha=args.lora_alpha,
        lora_dropout=0.05,
        use_gradient_checkpointing=True,
    )

    def formatting_prompts_func(examples):
        texts = []
        for messages in examples["messages"]:
            # Llama 3.1 chat template
            texts.append(
                tokenizer.apply_chat_template(
                    messages,
                    tokenize=False,
                    add_generation_prompt=False,
                )
            )
        return {"text": texts}

    dataset = dataset.map(
        formatting_prompts_func,
        batched=True,
        remove_columns=dataset.column_names,
    )

    use_bf16 = _cuda_bf16_supported()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    trainer = SFTTrainer(
        model=model,
        tokenizer=tokenizer,
        train_dataset=dataset,
        dataset_text_field="text",
        max_seq_length=args.max_seq_length,
        packing=False,
        args=TrainingArguments(
            output_dir=str(args.output_dir),
            per_device_train_batch_size=args.batch_size,
            gradient_accumulation_steps=4,
            num_train_epochs=args.epochs,
            warmup_ratio=0.06,  # unlike train_colab.ipynb's old hardcoded warmup_steps=10,
                                # this scales with dataset size automatically
            learning_rate=2e-4,
            fp16=not use_bf16,
            bf16=use_bf16,
            logging_steps=10,
            save_strategy="epoch",
            optim="adamw_8bit",
        ),
    )
    trainer.train()
    model.save_pretrained(str(args.output_dir))
    tokenizer.save_pretrained(str(args.output_dir))
    print(f"Adapters saved to {args.output_dir}")


def _cuda_bf16_supported() -> bool:
    try:
        import torch  # noqa: PLC0415

        return bool(torch.cuda.is_available() and torch.cuda.is_bf16_supported())
    except Exception:
        return False


if __name__ == "__main__":
    main()
