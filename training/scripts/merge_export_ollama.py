#!/usr/bin/env python3
"""
CP4: After training — merge LoRA into base weights, then GGUF + Ollama.

This script does not run heavy ML itself; it prints the exact commands to run
on a Linux machine with llama.cpp / your merge tooling installed.

Steps (manual):
  1) Merge adapters into base HF weights (Unsloth or PEFT merge script).
  2) Convert merged HF folder to GGUF with llama.cpp convert_hf_to_gguf.py
  3) ollama create communiq:8b -f Modelfile

Example merge (if you use PEFT):
  python -c "
from peft import PeftModel
from transformers import AutoModelForCausalLM, AutoTokenizer
import torch
base = AutoModelForCausalLM.from_pretrained('BASE', torch_dtype=torch.float16, device_map='auto')
m = PeftModel.from_pretrained(base, 'out/lora')
merged = m.merge_and_unload()
merged.save_pretrained('communiq-merged')
AutoTokenizer.from_pretrained('BASE').save_pretrained('communiq-merged')
"

Then follow https://github.com/ggerganov/llama.cpp for GGUF conversion.
"""

from __future__ import annotations

import argparse


def main() -> None:
    p = argparse.ArgumentParser(description="Print CP4 merge / GGUF / Ollama commands")
    p.add_argument("--merged-hf-dir", default="communiq-merged", help="HF folder after LoRA merge")
    p.add_argument("--gguf-out", default="communiq-8b-q4.gguf")
    p.add_argument("--ollama-model", default="communiq:8b")
    args = p.parse_args()

    print(
        f"""
# 1) Produce merged HuggingFace weights at ./{args.merged_hf_dir}/

# 2) Convert to GGUF (llama.cpp; paths vary by install):
#    python convert_hf_to_gguf.py ./{args.merged_hf_dir} --outfile {args.gguf_out}

# 3) Ollama (see training/Modelfile.communiq.example):
#    ollama create {args.ollama_model} -f Modelfile

# 4) Pipecat worker + ai-server .env:
#    LLM_MODEL={args.ollama_model}
#    OLLAMA_MODEL={args.ollama_model}
"""
    )


if __name__ == "__main__":
    main()
