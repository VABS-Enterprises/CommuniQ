# CP4 — Fine-tuning workflow (CommuniQ)

Offline training on a **college GPU** or **Colab**; inference stays on Ollama or vLLM.

## 1. Export conversations from Firestore

Export session documents (or a JSON array you dump from admin tools). Each item should include:

- `systemPrompt` or a fixed scenario system string
- `turns`: list of `{ "role": "user"|"assistant", "transcript": "..." }` (map `ai` → `assistant` if needed)

## 2. Convert to ChatML JSONL

```bash
python training/scripts/firestore_turns_to_chatml.py --input sessions.json --output data/chatml.jsonl
```

## 3. Scrub PII

```bash
python training/scripts/scrub_pii.py < data/chatml.jsonl > data/chatml_scrubbed.jsonl
```

Review samples before training.

## 4. Train / validation split

```bash
python training/scripts/split_train_val.py --input data/chatml_scrubbed.jsonl --out-dir data/split --val-ratio 0.1
```

## 5. QLoRA (Unsloth)

Run on Linux/CUDA or Colab:

```bash
pip install unsloth
python training/train_qlora_unsloth.py --train data/split/train.jsonl --output-dir out/lora
```

## 6. Merge + GGUF + Ollama

See `training/scripts/merge_export_ollama.py` and `training/Modelfile.communiq.example`.

Set Pipecat / ai-server:

- `OLLAMA_MODEL=communiq:8b` (or your tag)
- `LLM_MODEL` in worker `.env` to the same

## Pinning

Record `base_model_revision`, dataset hash, and adapter path in your experiment log for reproducibility.
