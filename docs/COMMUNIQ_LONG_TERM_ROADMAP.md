# CommuniQ long-term roadmap

This document merges the CommuniQ phased delivery plan (Colab parity, facades, local models, speech intelligence) with production and real-time voice research (streaming, VAD, local TTS, WebRTC-class stacks, fine-tuning). It is **text only**: a narrative roadmap you can follow over quarters, not a checkbox tool.

**How to read it.** Earlier sections stabilize product behavior and architecture. Middle sections reduce latency and vendor risk. Later sections move toward “live conversation” and owned models. You can overlap some work, but the **order** matters: do not bet the whole product on WebRTC before the core loop is reliable.

**Deep dive (hosting, hardware, integration).** For part-by-part implementation detail—e.g. how to host **STT locally** (faster-whisper, GPU/CPU, in-process vs sidecar), same for LLM/TTS, then VAD, streaming, WebRTC, fine-tuning—see [ROADMAP_DEEP_DIVE.md](ROADMAP_DEEP_DIVE.md).

---

## Part A — Foundation (what you keep and finish first)

**Goal.** One correct, debuggable conversation loop: opening, turns, replay, evaluation, and honest deploy connectivity.

**Why it comes first.** If the app does not match how you validated the experience (for example, AI speaks first, question audio replays before the next recording), every later optimization trains on the wrong UX. You also need stable Node, FastAPI, and Flutter contracts before streaming or WebRTC changes the transport.

**Included work.**

- Deploy wiring so the Node server always reaches FastAPI (`FASTAPI_URL`, HTTPS, timeouts).
- Opening route: AI line and audio before the first user recording; store that line in Firestore so end-of-session evaluation sees the same transcript shape you used in Colab.
- Flutter: play opening, then mic; after each AI reply, replay the same audio bytes before the next mic where that is part of your product spec.
- Session end: full transcript to the evaluator; feedback screen stays usable.

**Definition of done.** You can run a multi-turn session on a real device against production backends without silent failures, and end session returns structured feedback.

---

## Part B — Contracts and modularity (facades)

**Goal.** Swap engines without rewriting the whole pipeline.

**Why it matters.** Your friend is right that Edge-TTS and a single HTTP turn are fine for prototypes but risky or limiting for production. Facades let you change STT, LLM, or TTS behind environment variables while keeping one code path in the session API.

**Included work.**

- Single entry points for transcribe, chat completion, and synthesize (for example Groq Whisper, Groq Llama, Edge TTS as defaults).
- Document request and response shapes for turn, opening, and end-session in one place so Flutter and Node stay aligned.

**Definition of done.** You can point ASR, LLM, or TTS to a new backend by configuration and a bounded code change inside the facade, not a rewrite of `session.py` or the Node controller.

---

## Part C — Local and controlled inference (phases three, four, five)

**Goal.** Reduce dependency on third-party rate limits and surprise API changes, and use GPU you control.

**Why it pairs with your friend’s advice.** Kokoro-82M, faster-whisper, and vLLM or Ollama are not separate philosophies; they are **options behind the same facades**. Your plan named Piper, XTTS, OmniVoice-class models; your friend emphasized Kokoro for speed and quality on modest hardware. Pick per language and scenario; you can support more than one TTS backend over time.

**Suggested order.**

1. **Speech-to-text (local).** Faster-Whisper (or similar) behind the ASR facade. Keep Groq as fallback until local quality and latency are acceptable. Add a small set of fixed test clips to compare transcripts.
2. **Language model (local).** Llama 3.1 class model via Ollama or vLLM, behind the LLM facade. Pin versions. Use the same prompts as Groq first, then tighten.
3. **Text-to-speech (local).** Evaluate Kokoro-82M against your shortlist (Piper, XTTS, OmniVoice-class). Criteria: latency, clarity for Indian English, license, and operational cost. Hugging Face gated models need tokens and pinned revisions, same as large LLMs.

**Definition of done.** At least one fully local path (STT plus LLM plus TTS) runs end-to-end on your target GPU machine for a full session, with env switches to fall back to cloud.

---

## Part D — Latency and “brain” behavior (streaming and context)

**Goal.** Remove the feeling that the app waits in one long block after each recording.

**Why this matches your friend’s critique.** Today the mental model is: record, upload, wait for full STT, full LLM, full TTS, then play. That reads as stutter even when each step is fast.

**Streaming the LLM.** Use token streaming from Groq (or your local server) and feed **completed sentences or chunks** to TTS as soon as they are ready, then stream or queue audio to the client. The first audible response should start much earlier than today.

**TTS chunking.** Sentence boundaries are a practical first rule; your existing TTS stack may already split on sentences. Streaming LLM plus incremental synthesis is the main win; full “streaming TTS” from a single model is a later refinement.

**Context limits.** Long roleplays will hit context windows. Add a **sliding window** of recent turns plus, when needed, a **rolling summary** (short paragraph) of earlier conversation, regenerated or updated every N turns. Store summary in session state on the server so Flutter does not need to send the full history forever.

**System prompt and pedagogy.** The persona (for example HR “Sarah”) should not only ask the next question. She should acknowledge communication quality in character: brief, natural reactions to hesitation, vague answers, or strong answers. Feed structured hints from Part F into this behavior so the model adapts without dumping raw metrics into user-visible text.

**Definition of done.** Time-to-first-audio after end-of-speech drops measurably; sessions beyond twenty turns remain coherent; persona gives light coaching without breaking the scenario.

---

## Part E — Client interaction: from button to voice activity

**Goal.** The app detects when the user stops speaking instead of relying only on a Send button.

**Why.** Your friend recommended Silero VAD; that fits **before** or **alongside** WebRTC. You can ship VAD on the Flutter side (or server-side on streamed audio) while still using HTTP for each turn.

**Approach.** Detect end of user speech, auto-stop recording and trigger the same pipeline you use today (or a shortened upload). Keep Send as fallback for noisy environments.

**Definition of done.** Most turns complete without tapping Send; false triggers remain rare enough to tolerate or correct with a short “Undo” or “Continue speaking” pattern.

---

## Part F — Speech and NLP intelligence layer

**Goal.** Understand **how** the user speaks, not only **what** they said, and use that for coaching and for LLM conditioning.

**Why it is separate from Part D.** Streaming fixes pacing; intelligence adds signal: fillers, pauses, speaking rate, energy, alignment-based pronunciation proxies, and text-level grammar or vocabulary notes.

**Placement in the pipeline.** After STT and **before** the roleplay LLM: run modular analyzers (some from audio plus transcript, some from text only). Produce a **compact JSON digest** for the model and a **richer object** for the client and Firestore.

**Outputs.**

- Flags and short suggestions for the user (post-turn or light in-session UI).
- Injected context for the LLM (bounded length).
- Optional per-turn metrics stored on the session for longitudinal charts and better end-of-session reports.

**Backends.** Same idea as facades: local analyzers first (lexicon, simple prosody), optional cloud or heavier models behind flags. Heavy alignment (for example WhisperX-class) stays behind timeouts so turn latency stays acceptable.

**Definition of done.** Turn response includes structured insights; Firestore can store them; the interviewer’s replies measurably reflect stress or clarity when you test edge-case utterances.

---

## Part G — Deeper metrics (alignment and phonetics)

**Goal.** Word-level timing and, if you promise it in the product, phoneme-level feedback.

**Why it is later.** This is compute-heavy and easy to over-promise. It extends Part F and overlaps with “WhisperX-style” ideas from your original Phase six.

**Definition of done.** You can show word timings or simple pronunciation hints for a turn without blowing turn budgets, or you offload this to an async job with clear UX.

---

## Part H — Real-time architecture (WebRTC-class)

**Goal.** Conversation that feels like modern voice assistants: continuous audio, low latency, barge-in.

**Why it is not Part A.** Replacing HTTP turn-by-turn with WebRTC (and often a framework such as Pipecat or LiveKit) is a **new orchestration layer**. It touches Flutter (`flutter_webrtc`), signaling, media servers, and how you run STT and TTS (often streaming). It does not invalidate Parts A through F; it **wraps** them when you are ready.

**Recommended migration shape.**

- Keep the current HTTP pipeline as **fallback** and for simpler networks.
- Introduce a **voice session** path: WebRTC to a gateway that runs VAD, streaming STT, streaming LLM, streaming or chunked TTS, and handles interrupt when the user talks over the AI.

**Definition of done.** One end-to-end voice mode with acceptable latency and interrupt behavior on a reference device and network.

---

## Part I — Model ownership (fine-tuning)

**Goal.** A model that follows your **pedagogy** (for example STAR for interviews), not only generic chat.

**Why it is last among major pillars.** Fine-tuning needs data, GPU time, and evaluation harnesses. Unsloth and QLoRA are ways to train efficiently on a college GPU; ChatML-style JSONL is a standard packaging format. This is **orthogonal** to facades: you still serve the result through the same LLM backend (for example vLLM).

**Workflow sketch.** Curate transcripts into multi-turn examples with clear system instructions; fine-tune with 4-bit LoRA; evaluate against held-out scenarios; pin the checkpoint and document prompt changes.

**Definition of done.** A/B against base model on scenario-specific rubrics; deploy checkpoint behind `LLM_BACKEND` or an explicit model ID env var.

---

## Part J — Production hygiene (ongoing)

**Goal.** Operate like a product, not only a demo.

**Included themes.**

- Rate limits, retries, and user-visible errors when AI services are cold or down.
- Logging and privacy: minimize raw audio in logs; aggregate metrics.
- Cost dashboards for cloud Groq or API TTS if you keep hybrid paths.
- Legal and ToS for any service that proxies third-party speech APIs (your friend’s warning about Edge-TTS is about operational risk, not “never use it”).

---

## How the two research lines fit together

| Theme | Your original plan | Your friend’s research | Merged stance |
|--------|-------------------|------------------------|----------------|
| Product truth | Colab parity, opening, replay | Less emphasized | **Part A** stays the gate |
| Modularity | Facades, env backends | Kokoro, faster-whisper, vLLM | **Parts B and C** |
| Feel of conversation | HTTP turn | Streaming, VAD, WebRTC | **Parts D, E, H** in order |
| Coaching | Phase seven intelligence | Stronger persona plus fillers | **Parts D and F** together |
| TTS risk | Local TTS phase | Kokoro, avoid Edge in prod | **Part C** with Kokoro as prime candidate |
| Training | Implied by local Llama | Unsloth, STAR, ChatML | **Part I** |

---

## Suggested long-term sequencing (simple)

1. **Finish and freeze foundation** (Part A) if anything is still missing in production.
2. **Keep facades and docs** (Part B) current whenever you add endpoints.
3. **Local inference path** (Part C) for at least one full stack you control.
4. **Streaming LLM plus chunk TTS and context window strategy** (Part D).
5. **VAD** (Part E) on the current transport.
6. **Intelligence layer** (Part F), then **deeper alignment** (Part G) if the product needs it.
7. **WebRTC voice mode** (Part H) when HTTP limits are the main bottleneck.
8. **Fine-tuning** (Part I) when data and evaluation are ready.
9. **Production hygiene** (Part J) runs in parallel from early on and never stops.

This is the merged “best of both” path: your discipline on phases and parity, plus your friend’s direction on streaming, local TTS, VAD, real-time stacks, and training—without pretending they all ship in one sprint.

---

## Validation and design rationale (foolproofing)

This section checks the **simple overview** (work → fast → smart → real-time; merged steps; conclusions) against engineering reality. Nothing here is “proof” in the mathematical sense, but each claim has a stated reason and known limits.

### 1. “Final plan = phased system + friend’s production ideas, not a replacement”

**Valid.** Enhancement on top of a stable spine is lower risk than a big-bang rewrite. **Caveat:** WebRTC-class voice mode (Part H) is closer to a **parallel product path** than a tiny patch; still, you keep HTTP as fallback so the original system is not thrown away.

### 2. “Order: WORK → FAST → SMART → REAL-TIME”

**Mostly valid as a story.** **Nuances:**

- **WORK** must include deploy, auth, session lifecycle, and parity behaviors (Part A). Without that, faster inference only ships bugs sooner.
- **FAST** (streaming, chunk TTS) can be done **while still on Groq + Edge**; it does **not** require local models first. So “FAST” and “local APIs” are independent axes.
- **SMART** (intelligence layer) is partly cheap (lexical fillers from text only) and partly expensive (alignment, prosody from audio). You can ship **light smart** before **heavy smart** (Parts F then G).
- **REAL-TIME** (continuous audio, barge-in) is the largest architectural shift; doing it last is correct for most teams.

**Correction to a strict linear reading:** “SMART” does not have to wait until after all of “FAST.” You can run a minimal intelligence pass in parallel with planning streaming, as long as turn latency stays bounded.

### 3. “Flow: User → STT → Intelligence → LLM → TTS”

**Valid for the merged architecture.** **Clarifications:**

- **VAD** sits on the **input** side: it decides *when* a segment of audio is complete and ready for STT (or when to cut a buffer in streaming mode). It is not a fifth box after TTS.
- **Streaming** is a **pattern inside** LLM and TTS (and sometimes STT): first tokens or first sentences move downstream earlier; the logical order of stages stays the same.

### 4. What your plan contributes (structure, parity, Node/FastAPI/Flutter, intelligence, facades)

**Valid.** **Why it matters:** Correctness and contracts reduce integration cost; facades reduce lock-in. **Limit:** Facades do not by themselves guarantee latency or legal safety—you still choose backends and monitor them (Part J).

### 5. What your friend’s research contributes (streaming, VAD, Kokoro, WebRTC, Unsloth)

**Valid.** **Why it matters:** Perceived speed, hands-free capture, vendor independence for TTS, and optional model ownership. **Limits:**

- **Streaming** needs client and server changes (partial responses, audio queueing, error handling mid-stream).
- **WebRTC** needs signaling, ICE, and often a media or orchestration service; operational surface grows.
- **Unsloth/QLoRA** need a dataset, evaluation harness, and governance (PII, consent); it does not replace inference work.

### 6. Merged step list (architecture → streaming → local → VAD → intelligence → WebRTC → fine-tune)

**Sound as a teaching order.** **Adjustable point:** In this document’s **suggested sequencing** (earlier section), **local inference (Part C)** appears **before** **streaming (Part D)**. Your friend’s outline sometimes puts **streaming before** local. **Both are valid:**

| Order | Reason to prefer it |
|--------|---------------------|
| Local **then** streaming | Removes API dependency first; streaming then improves a stack you own. |
| Streaming **then** local | Improves UX quickly on current Groq/Edge; less GPU setup before first win. |

**Recommendation:** If Groq and Edge are already stable in production, consider **streaming (D) before or in parallel with** the heaviest **local** work (C), so users feel progress early. If API limits or compliance **require** on-prem first, keep **C before D**.

**Intelligence before WebRTC:** Correct. HTTP + VAD + intelligence is enough to validate signals; WebRTC should not block coaching features.

**Fine-tuning last among big rocks:** Reasonable for most teams; **exception:** if pedagogy is the main differentiator and data is ready, a small **Part I** pilot can start in parallel with Part D or E, as long as it does not starve core reliability work.

### 7. “Merged = stable, fast, intelligent, real-time capable”

**Valid as a target statement.** **Honest scope:**

- **Stable** is earned by tests, monitoring, and rollback—not by architecture diagrams alone.
- **Fast** is multi-factor (network, model size, streaming, client audio pipeline).
- **Intelligent** must stay **coaching-grade**, not clinical (avoid over-claiming pronunciation or “confidence” from proxies).
- **Real-time capable** means you *can* add WebRTC; it does not mean every user session must use it on day one.

---

### TTS choice: Kokoro-82M vs OmniVoice-class (example of “reasons, not vibes”)

There is no single winner; you choose on **criteria**. Re-check licenses and model cards before shipping.

| Criterion | Kokoro-82M (typical profile) | OmniVoice-class / large neural TTS (typical profile) |
|-----------|------------------------------|------------------------------------------------------|
| **Latency / throughput** | Usually **strong**; small model, good for sentence-chunk streaming. | Often **heavier**; may need more GPU or batching tradeoffs. |
| **VRAM / ops cost** | **Lower**; fits modest GPUs or even CPU in some setups. | **Higher**; may block sharing GPU with large LLM on one card. |
| **Voice naturalness / expressiveness** | **Good** for many English use cases; may sound less “cinematic” than top large models. | **Potentially richer** timbre, emotion, or cloning—depends on exact model. |
| **Indian English / regional target** | **Must be measured** on your scenarios; default voices may skew US/UK. Your current Edge `en-IN-*` was chosen for locale—Kokoro may need voice pick or fine-tune. | Same rule: **evaluate on your users**, not on marketing samples. |
| **Integration complexity** | Often **simpler** pipeline (text in, audio out). | May need **HF auth**, large weights, pinned revisions, longer cold start. |
| **Legal / ToS** | Open-weight stacks reduce **vendor ToS** risk vs Edge-TTS-style proxies; still read the license. | Gated models: **HF_TOKEN**, redistribution rules, commercial terms. |
| **Streaming TTS** | Fits **chunked** synthesis well. | Depends on implementation; not automatically better for streaming. |

**Practical rule:** Use **Kokoro** (or Piper) when you want **fast, simple, on-prem TTS** quickly. Push toward **OmniVoice-class** when you need **specific voice quality, cloning, or expressiveness** and can pay **GPU and complexity**. **Proof method:** same 20 scripted lines, same device, blind A/B with target users + WER/listening tests.

---

### Other high-value “which is better, in what terms?” snapshots

**STT: Groq Whisper vs faster-whisper (local)**

- **Accuracy:** Often comparable for clear speech; **measure** on your noise + accent clips.
- **Latency:** Groq can win on cold path if your server is far from users; local wins when network is bad or you batch on GPU.
- **Cost / privacy:** Local wins for **data residency**; Groq wins for **zero GPU ops**.

**LLM: Groq vs local Llama (vLLM/Ollama)**

- **Latency / scale:** Groq managed API is simple; local needs **capacity planning** and model serving discipline.
- **Customization:** Local + **fine-tune (Part I)** wins for **pedagogy** and brand voice.

**Edge-TTS vs any local TTS**

- **Terms:** Edge is **convenient** but **third-party ToS and rate limits** apply; **not** “illegal,” just **operational risk** for a growing product.
- **Production:** Prefer **contracted** API or **owned** weights (Kokoro, etc.) when revenue or scale depends on voice.

**HTTP turn vs WebRTC**

- **Simplicity / debuggability:** HTTP wins.
- **Latency and interrupt:** WebRTC-class wins when the product promise is **live dialogue**.

**Silero VAD vs “Send button”**

- **UX:** VAD wins for **hands-free**; button wins in **noisy** environments unless you add **manual override** (recommended).

---

### Summary

Your merged overview is **directionally correct**. The foolproof version adds: (1) **VAD and streaming are not extra boxes in the middle of STT→LLM→TTS**—they refine *how* each stage runs; (2) **FAST and LOCAL are swappable in order**; (3) **SMART can start small** before WebRTC; (4) **backend choices need scored criteria**, not single winners—Kokoro vs OmniVoice is a **tradeoff table**, not a religion; (5) **stability and honesty** about coaching limits matter as much as architecture.
