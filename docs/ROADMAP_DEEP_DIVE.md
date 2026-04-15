# CommuniQ roadmap — implementation deep dive

This document expands each part of [COMMUNIQ_LONG_TERM_ROADMAP.md](COMMUNIQ_LONG_TERM_ROADMAP.md) with **practical hosting, hardware, software, and integration** detail. It is written so you can take **one part at a time** and know what to build or buy.

**CommuniQ’s default topology today (for reference).** The Flutter app talks only to **Node**. Node talks to **Firebase** and to **FastAPI** (`FASTAPI_URL`). FastAPI holds Groq Whisper, Groq LLM, and Edge-TTS (or facades pointing at them). Local inference usually means **running extra software on the same machine as FastAPI** or on a **private GPU server** that FastAPI calls over HTTP on your VPC.

**Optional path (student / lab budget).** [Part K — College workstation hybrid](#part-k-college-workstation-hybrid) is an end-to-end recipe: **GPU box at college** runs STT + LLM + TTS behind **FastAPI**, exposed via **Cloudflare Tunnel**, with **Supabase / R2 / Vercel** as a lean persistence and web layer. It does not replace Parts A–J; it **instantiates** Part C + Part I on hardware you already have and solves “no static IP / firewall” without opening inbound ports on the campus router.

---

## Part A — Foundation

**What this part is.** Correct product behavior and reliable cloud plumbing—not local ML yet.

### What runs where

| Piece | Typical hosting | Who calls it |
|--------|-----------------|--------------|
| Flutter app | User’s phone (Play Store / App Store builds) | End user |
| Node API | Managed host (e.g. Render, Fly.io, Cloud Run, VPS) | Flutter over HTTPS |
| Firebase | Google-managed | Node via Admin SDK |
| FastAPI (ai-server) | Same or second managed host / GPU VM | **Only Node** (never Flutter directly) |

### What you need

- **Accounts:** Firebase project, Groq API key, hosting for Node + FastAPI.
- **Secrets:** `FIREBASE_*`, `GROQ_API_KEY`, `FASTAPI_URL` on Node; `GROQ_API_KEY` on FastAPI.
- **Networking:** FastAPI URL must be **HTTPS** in production; timeouts on Node large enough for cold starts (often 60–120 s for a turn).
- **Mobile:** mic permissions, background rules (iOS/Android) for recording.

### Local hosting for Part A?

**No local STT/LLM/TTS required.** “Local” here only means **your laptop** for development: run Node + FastAPI + Firebase emulator optional. Production stays cloud until you choose Part C.

### Definition of done (operations)

One real device can complete opening → several turns → end session without silent failures; `FASTAPI_URL` misconfiguration shows a clear user-visible error, not a generic crash.

---

## Part B — Contracts and modularity (facades)

**What this part is.** Code structure so you swap engines without rewriting routes.

### What runs where

Everything still runs **inside the FastAPI process** (or the same container). Facades are Python modules; no separate server is **required**.

### What you need

- **Discipline:** `ASR_BACKEND`, `LLM_BACKEND`, `TTS_BACKEND` (or equivalent) read in one config module.
- **Documentation:** One doc (e.g. `docs/API_CONTRACTS.md`) describing JSON bodies for opening, turn, end.

### Optional: split services later

If one GPU cannot hold LLM + ASR + TTS at once, you might run **separate containers** (e.g. `asr-service:8081`, `llm-service:8082`) and have FastAPI call them with HTTP. That is still “facade-friendly”: the facade targets a URL instead of an in-process library.

---

## Part C — Local and controlled inference (STT, LLM, TTS)

This is where **local hosting** matters most. Below: **STT first** (your example), then LLM, then TTS.

---

### Part C.1 — Speech-to-text (STT) hosted locally

**Goal.** Transcribe user audio on **your** machine (or your VPC) instead of Groq Whisper API.

#### Recommended stack (common choice)

- **Library:** `faster-whisper` (uses **CTranslate2** under the hood; efficient CPU/GPU inference).
- **Models:** OpenAI Whisper weights in CTranslate2 format — sizes from **tiny** to **large-v3**. Larger = better accuracy, more VRAM/RAM and slower.

#### Hardware

| Setup | Rough expectation |
|--------|-------------------|
| **NVIDIA GPU + CUDA** | Best experience. **~4–6 GB VRAM** for **small** or **medium** models at reasonable batch; **large-v3** often wants **8–12+ GB** for comfortable headroom. |
| **CPU only** | Works for **tiny/base** and light traffic; latency per turn can be **several seconds** for longer audio. Fine for dev, tight for production UX. |
| **Apple Silicon** | Possible via CPU path or Metal-backed paths depending on stack version; verify current `faster-whisper` / `ctranslate2` notes for your OS. |

#### Software requirements

- **OS:** Linux is the smoothest for CUDA in production; Windows WSL2 works for dev; macOS for dev without NVIDIA.
- **Python:** Match your ai-server version (e.g. 3.10–3.12).
- **CUDA toolkit + driver** (if GPU): versions must match what **ctranslate2** wheels expect (document the combo you pin).
- **FFmpeg:** Often needed to decode **m4a/webm** from phones into wav/pcm for the model (your app already sends wav in many cases—still keep FFmpeg for robustness).

#### How you “host” it in CommuniQ

**Option 1 — In-process (simplest).**  
Load `WhisperModel` once at FastAPI startup inside the same app that handles `/session/turn`. The `asr_facade` branch for `ASR_BACKEND=local` calls `model.transcribe(audio)`.

- **Pros:** One deployable, no extra network hop.  
- **Cons:** STT shares RAM/VRAM with LLM/TTS in the same process; risk of OOM if everything is huge.

**Option 2 — Sidecar microservice.**  
A small FastAPI/Flask app that only transcribes; your main ai-server POSTs audio bytes to `http://localhost:8081/transcribe`.

- **Pros:** Scale or restart STT independently; can put STT on a **cheaper GPU box**.  
- **Cons:** Extra latency, networking, and deployment work.

**Option 3 — GPU VM dedicated to “AI worker”.**  
Same as sidecar but on another machine in the cloud; main ai-server’s `FASTAPI` internal URL points to it.

#### Integration with Node / Flutter

- **Unchanged.** Flutter → Node → FastAPI. Only FastAPI’s **inside** changes from “call Groq” to “call local Whisper.”
- **Security:** Never expose the STT service publicly without auth; only Node-trusted network should reach it.

#### Operational checklist

- Pin **model name and revision**; cache model files on disk so cold start only hits disk once.
- Set **max audio length** and **concurrency** (one Whisper job per GPU is typical unless you batch carefully).
- Add **regression clips** (your Indian English samples) and compare WER or human review vs Groq before flipping production traffic.

---

### Part C.2 — Language model (LLM) hosted locally

**Goal.** Run Llama-class chat **on your GPU** (or strong CPU server) instead of Groq API.

#### Common stacks

| Stack | What it is | Typical use |
|--------|------------|-------------|
| **Ollama** | Daemon + CLI; pulls GGUF models; exposes HTTP API | Fastest to try locally; good for single-machine dev |
| **vLLM** | High-throughput inference server; OpenAI-compatible optional | Production when you need many concurrent requests |
| **text-generation-inference (TGI)** | Hugging Face server | Alternative to vLLM in some orgs |
| **llama.cpp server** | Very efficient on CPU/GPU for smaller quants | Good when VRAM is tight |

#### Hardware

- **Llama 3.1 8B** in **4-bit**: often **~6–10 GB VRAM** depending on framework and context length; **8k+ context** and batching increase demand.
- **Same GPU as Whisper + TTS:** Often **too tight**; you may **serialize** (run STT, unload, run LLM) or use **two GPUs** or **two machines**.

#### How you host it

- **Docker** image with CUDA + vLLM or Ollama is typical on a Linux GPU VM.
- **llm_facade** for `LLM_BACKEND=local` should call **HTTP** to `http://127.0.0.1:11434` (Ollama) or your vLLM base URL with the same **chat message schema** you use for Groq.

#### What you need

- **Model files:** Large downloads; store on fast SSD; pin versions.
- **Auth:** If the LLM port is on a network, protect it with firewall or API key.
- **Prompt parity:** Same system prompt as Groq first; then tune temperature / max tokens for local quirks.

---

### Part C.3 — Text-to-speech (TTS) hosted locally

**Goal.** Synthesize AI replies without Edge-TTS or external SaaS.

#### Options (short)

| Engine | Size / speed | Notes |
|--------|----------------|------|
| **Piper** | Very small, fast | Great baseline; robotic but predictable |
| **Kokoro-82M** | Small, fast | Strong open-source candidate for naturalness vs size |
| **XTTS / Coqui-class** | Larger | More expressive; more VRAM/setup |
| **OmniVoice-class** | Often large / gated | Check HF license, token, VRAM |

#### Hardware

- Many small TTS models run on **CPU** or **small GPU slice**; **XTTS-class** may need **several GB VRAM**.

#### How you host it

- **In-process:** Python calls Kokoro/Piper inside FastAPI (like today’s `edge_tts` path).
- **Sidecar:** Separate TTS HTTP service if VRAM contention with LLM.

#### Audio format

- Your app expects **MP3 bytes** (base64) today. Local engines may output wav; **transcode to mp3** (e.g. pydub + lame) or change client to accept wav—coordinate with Flutter.

---

## Part D — Latency (streaming LLM + chunk TTS + context window)

**What this part is.** Mostly **application protocol** changes, not a new box—unless local LLM streaming server differs.

### Streaming LLM

- **Groq:** Use the SDK’s **streaming** chat API; accumulate tokens until a **sentence boundary**, then push that string to TTS.
- **vLLM / Ollama:** Both support streaming HTTP responses; your FastAPI route may become a **StreamingResponse** or WebSocket to Node, and Node may need **SSE or chunked transfer** to Flutter—or you buffer on server until first sentence and still return one JSON if you want minimal client change at first.

### What you need

- **Sentence splitter** (regex or lightweight NLP) to avoid cutting mid-word.
- **Back-pressure:** If TTS is slower than LLM, queue chunks.
- **Failure mid-stream:** User-visible retry or partial playback policy.

### Context window (sliding window + summary)

- **Where state lives:** Prefer **server-side** session store (Redis, Firestore field, or in-memory with sticky sessions) holding `recent_turns` + `rolling_summary`.
- **Summary job:** Every N turns, call a **small LLM** or the same LLM with a tight prompt: “Summarize prior conversation in 120 words for continuation.”
- **What Flutter sends:** Eventually only **sessionId** + latest audio; server fetches history. Short term you can keep sending history but cap length.

### Hosting

- **Redis** (managed or container) if multiple FastAPI replicas need shared session state.
- **Firestore** already there—optional field `conversationSummary` on session doc (watch write costs and size).

---

## Part E — Voice activity detection (VAD)

**What this part is.** Detect **end of user speech** to auto-trigger upload/STT.

### Where VAD runs

| Location | Pros | Cons |
|----------|------|------|
| **On device (Flutter)** | Low latency; no audio streaming until segment done | Model packaging (ONNX/TFLite); device variance |
| **On server** | Easier to upgrade model | Must stream audio or send chunks; more bandwidth |

### Common model: Silero VAD

- **Form:** ONNX weights; run with **onnxruntime** on mobile/desktop or Python server.
- **Requirements:** Small; CPU-friendly; tune **threshold** and **min silence ms** for Indian ambient noise.

### What you need

- **Fallback:** Keep **Send** button for noisy cafes.
- **Integration:** On silence detected → stop `record` → same file path as today’s `_onSend`.

### Hosting

- **None** if purely on Flutter.  
- **Optional** Python sidecar if you move to streamed audio in Part H.

---

## Part F — Speech and NLP intelligence layer

**What this part is.** Extra **analysis** after transcript (and optionally audio) **before** the roleplay LLM.

### Typical components

| Component | Often runs | Needs |
|-----------|------------|--------|
| Lexical fillers / regex | Python in FastAPI | Word list aligned with evaluator |
| Prosody (pauses, energy, rate) | Python + **librosa** / scipy | Decode wav; sample rate known |
| Light grammar / vocab | **spaCy** or **LanguageTool** HTTP | English model download; LT JVM or public API (careful with privacy) |
| “Mini” LLM for structure | Same Groq/local LLM | Extra token budget; cache prompts |

### Hosting

- **Default:** Same FastAPI process, **asyncio.gather** for parallel light tasks.
- **Heavy** alignment (Part G) behind timeout or **background job** (Celery/RQ + Redis) if turn latency explodes.

### Storage

- Extend Firestore **user turn** with optional `intelligence` JSON blob (size limits ~1 MiB per doc—stay well under).

---

## Part G — Deeper metrics (alignment / phonetics)

**What this part is.** Word-level timestamps; optional phoneme alignment.

### Typical stack

- **WhisperX** or similar: Whisper + alignment pass; **GPU** usually expected; **extra VRAM** beyond plain ASR.
- **Montreal Forced Aligner (MFA):** Phoneme-level; heavier setup (lexicon, corpus).

### Hosting

- Often a **separate GPU job** or **async worker** because it can take **longer than real time** on long clips.
- **Not** recommended in the **critical path** of every turn until optimized.

### Requirements

- Same audio + transcript; pinned conda/docker env for C++ aligner deps sometimes.

---

## Part H — Real-time architecture (WebRTC-class)

**What this part is.** Continuous bidirectional audio + **barge-in**; different from HTTP multipart per turn.

### Typical components

| Piece | Role |
|--------|------|
| **WebRTC** | Low-latency audio transport Flutter ↔ server |
| **Signaling** | Exchange SDP/ICE (WebSocket server or Firebase RTDB—choose one pattern) |
| **TURN server** | Relays when P2P fails (e.g. **coturn** on VPS) |
| **Media / orchestration** | **LiveKit**, **Pipecat**, or custom Python reading RTP |

### Hosting

- **LiveKit open source:** Deploy server + configure **API keys**; Flutter uses LiveKit SDK.
- **Pipecat:** Often runs as a **worker** that connects to LiveKit or Daily rooms and pipes audio to **Deepgram / Whisper / Azure** STT and to TTS.
- **Cost:** You pay for **VMs**, **bandwidth**, and **TURN** egress—not just API calls.

### Relationship to FastAPI

- You may **keep FastAPI** for session CRUD, auth proxy, and evaluation, while **voice media** goes to LiveKit/Pipecat.
- Or gradually **merge** orchestration into one service—team-dependent.

---

## Part I — Fine-tuning (Unsloth / QLoRA)

**What this part is.** **Training** job, not the same as **inference** hosting.

### Where it runs

- **College GPU / workstation:** Jupyter or CLI; **Unsloth** accelerates LoRA training.
- **Artifacts:** LoRA adapters or merged weights saved to disk / HF Hub.

### Requirements

- **Dataset:** ChatML JSONL; PII scrubbing; consent.
- **VRAM during training:** Often **similar or less** than full fine-tune thanks to 4-bit base + adapters; still **plan headroom**.
- **After training:** Export for **vLLM / Ollama**; **pin** revision in production.

### Hosting inference of your fine-tuned model

- Same as **Part C.2** — you replace the **base model ID** with your **merged checkpoint** or load **adapter** in a server that supports it.

---

## Part J — Production hygiene

**What this part is.** Cross-cutting; not one server type.

### You need

- **Secrets management:** Not plain `.env` in images; use host secrets or vault.
- **Logging:** Structured logs; **no raw audio** in production logs by default.
- **Retention:** How long you keep audio if you ever store it (often you should **not** store raw audio without policy).
- **Rate limits:** On Node `/sessions/turn` (already partially there).
- **Health checks:** FastAPI `/health` including **GPU OOM** signal if local models.
- **Legal:** Edge-TTS, Groq, HF gated models—**ToS** and **data processing** text in privacy policy.

---

## Part K — College workstation hybrid

**Scope.** Local **GPU** for STT + LLM + TTS, **Cloudflare Tunnel** for HTTPS reachability without campus inbound ports, optional **Supabase + R2 + Vercel** for auth, scores, blobs, and web.

**What this part is.** A **concrete, phased** way to use a **college or lab GPU workstation** as the heavy compute for CommuniQ while keeping **affordable** cloud pieces for reachability and data you do not want on a shared PC. It is optimized for **low recurring API cost** and **privacy on the inference path**, at the cost of **depending on a machine you do not fully control** (power, reboots, lab policy).

**Prerequisites (map to earlier parts).**

| You need | See |
|----------|-----|
| Stable session API shapes and facades | **Part B** |
| Local STT / LLM / TTS choices and VRAM reality | **Part C.1–C.3** |
| Fine-tune as a separate job from inference | **Part I** |
| Logging, secrets, rate limits, no audio in logs | **Part J** |

**Important alignment with CommuniQ today.** Production CommuniQ is designed as **Flutter → Node → FastAPI**. Part K can still follow that: **Cloudflare Tunnel** terminates on **Node** (public) or on **FastAPI** (simpler for experiments). **Recommended for anything beyond a demo:** tunnel to **Node**, set `FASTAPI_URL` to the **private** GPU box (VPN, split tunnel, or same host if Node and FastAPI colocate). **Direct Flutter → tunneled FastAPI** is possible only if you add **auth, HTTPS, abuse controls**, and accept bypassing Node—otherwise you duplicate security work.

---

### K.0 — Assumptions and risks (read once)

| Topic | What to decide |
|--------|----------------|
| **Lab policy** | Tunneling and inbound services may need **IT approval**. Treat the GPU PC as **untrusted for long-term storage** of user audio. |
| **Availability** | Reboots, updates, or another user on the machine **will** interrupt service unless you automate recovery (**K.5**). |
| **VRAM budget** | Llama 3.1 8B + faster-whisper + Kokoro may **not** all fit comfortably on one consumer GPU; use **Part C** options (smaller Whisper, CPU TTS, or **serialize** / **sidecar**). |
| **Firebase vs Supabase** | The **default app** uses **Firebase**. Part K’s **Supabase** stack is an **alternative** for auth + Postgres scores; migrating is a **product decision**, not a one-line config change. |

---

### Phase 1 — Prepare the “brain” (local API server)

**Goal.** The college machine becomes a **high-performance, HTTP-accessible** pipeline: audio in → text → LLM → speech out, without per-token cloud bills for the core loop.

#### 1.1 Fine-tune (training, not inference)

- **Where:** Same **NVIDIA GPU** you will use for inference, or a **separate** training slot if the lab allows—training and inference **should not** fight for the same GPU in production hours if you can avoid it.
- **Tooling:** **Unsloth** accelerates **QLoRA / LoRA** fine-tunes on Llama-class bases (e.g. **Llama 3.1 8B**). Expect **roughly under an hour** for small, well-prepared datasets on a mid-range datacenter GPU; **your** time depends on dataset size, max steps, and GPU model.
- **Artifacts:** LoRA adapters or **merged** weights on **fast disk**; version with **git tags + dataset hash + base model revision**.
- **Dataset:** ChatML-style JSONL; **PII scrubbing** and **consent** (same discipline as **Part I**).

#### 1.2 Export for the inference server you chose

| Inference target | Typical artifact / action |
|--------------------|---------------------------|
| **Ollama** | **GGUF** (or a model Ollama can import). Training in Unsloth produces **HF-style** checkpoints; you **convert / quantize** to GGUF with the toolchain your team pins (e.g. **llama.cpp**-compatible exporters). Treat “export to GGUF” as a **documented build step**, not a single magic Unsloth flag—verify the exact recipe for your base model. |
| **vLLM** | Often **Hugging Face** model directory or compatible weights; **continuous batching** for **many concurrent** users. Better **throughput** than Ollama for multi-tenant production; **more setup** than `ollama serve`. |

#### 1.3 Serve the LLM

| Option | When to use | Notes |
|--------|-------------|--------|
| **Ollama** | Fastest path to a **local HTTP API** (`http://127.0.0.1:11434` by default). | Great for **single machine**, few concurrent sessions, demos. |
| **vLLM** | **Several simultaneous** users or stricter latency under load. | Exposes an OpenAI-compatible or custom HTTP API; run **beside** FastAPI on the same host or another GPU node. |

**Security:** Bind LLM ports to **localhost** (or a **private** interface). Only **FastAPI** (or Node on a trusted path) should call them—**never** expose raw Ollama/vLLM on the public hostname the tunnel creates.

#### 1.4 FastAPI orchestrator (“glue”)

- **Role:** One **FastAPI** app (your **ai-server** or a slim variant) that:
  1. Accepts **audio** (same contract as **Part B** / `docs/API_CONTRACTS.md` where possible).
  2. Runs **STT** — **faster-whisper** on GPU/CPU (**Part C.1**).
  3. Sends transcript + session context to **Ollama or vLLM** (**Part C.2**).
  4. Runs **TTS** — e.g. **Kokoro-82M** in-process or sidecar (**Part C.3**).
  5. Returns **audio + metadata** in the shape your **Node** and **Flutter** expect (e.g. MP3/base64—coordinate with **Part C.3**).
- **Why not only vLLM?** vLLM is **text-in / text-out**. FastAPI remains the **orchestrator** for Whisper + chat + TTS and for **one** stable external contract.

---

### Phase 2 — The tunnel (secure public reachability)

**Problem.** Campus **firewalls** and **no static IP** block direct access from phones on cellular/Wi‑Fi.

**Approach.** **Cloudflare Tunnel** (`cloudflared`): an **outbound** persistent connection from the workstation to Cloudflare. You publish a **hostname** (your domain or one you control) that proxies to **localhost** on the box—**no** router port-forward, **TLS** terminated at the edge.

**High-level steps (verify against current Cloudflare docs when you implement).**

1. Install **cloudflared** on the **same machine** that runs the service users must reach (often **FastAPI** port, e.g. `8000`, or **Node** if the tunnel terminates there).
2. Authenticate and create a **named tunnel** (e.g. `communiq-server`).
3. Define **ingress** rules mapping `https://api.yourdomain.example` → `http://127.0.0.1:8000` (or your Node port).
4. Run the tunnel as a **daemon** (**K.5**): `cloudflared tunnel run <tunnel-name>` with a **config file**—do not rely on ad-hoc commands alone in production.

**Note on “quick” tunnels.** `cloudflared tunnel --url http://localhost:8000` is useful for **minutes-long tests**; **named tunnels + DNS** are what you want for a **stable** `https://api…` endpoint.

**What the tunnel does *not* do.** It does **not** replace **authentication**, **rate limiting**, or **input validation**. Those stay in **Node** and/or **FastAPI** (**Part A**, **Part J**).

---

### Phase 3 — Memory and identity (lean cloud layer)

**Goal.** The GPU does **compute**; user accounts, scores, and durable objects live in **managed** services you can afford on a student budget.

| Layer | Suggested service | Role | Cost angle |
|-------|-------------------|------|------------|
| **Auth + structured data** | **Supabase** (Postgres + Auth) | Sign-up / login, roleplay scores, profiles | Generous free tier; **Flutter SDK** exists. **Alternative:** keep **Firebase** and use R2 only for blobs—stay consistent with **Part A**. |
| **Object storage (audio)** | **Cloudflare R2** | Upload **.wav** / artifacts from **Node** or **FastAPI** with **pre-signed URLs**; avoid hoarding raw audio on the lab PC | **No egress** to bill like **S3**-style egress-heavy patterns—still account for **operations** and **ingress**. |
| **Web / admin** | **Vercel** (or similar) | **Flutter Web** build or a small **admin dashboard** | Static / serverless pricing; not required for the mobile loop if you only ship native apps. |

**Privacy.** If audio goes to R2, document **retention**, **encryption**, and **who can decrypt** in your policy (**Part J**).

---

### Phase 4 — Integration (Flutter and backends)

| Step | Action |
|------|--------|
| **Base URL** | Point the app (or **Node**’s env) at the **public HTTPS** origin from Phase 2—not Groq/Colab URLs—for the path you decided (tunnel → Node vs tunnel → FastAPI). |
| **Audio** | Continue using **`record`** (or your existing capture) to produce **WAV** (or agreed format); **POST** multipart/json per your **API contract**. |
| **Timeouts** | Local turns can be **slow** under load; align **Flutter**, **Node**, and **reverse proxy** timeouts (**Part A**). |

**Future:** Streaming and barge-in (**Part D**, **Part H**) are **easier to experiment with** when you are **not** paying per second of vendor API—still **hard engineering**, not automatic.

---

### K.5 — Shared machine: auto-restart and “who logged out?”

**Yes—you should plan for restarts.** If the PC **reboots**, **sleeps**, or a **session ends**, **cloudflared**, **Ollama/vLLM**, and **FastAPI** must come back **without manual SSH**.

| OS / context | Practical approach |
|--------------|-------------------|
| **Linux (typical lab GPU)** | **systemd** units for `cloudflared`, `ollama` (or vLLM), and **uvicorn/gunicorn** FastAPI; `Restart=always`, sensible `StartLimitInterval`. |
| **Windows** | **Task Scheduler** “At startup” + “on failure restart” for the same three processes, or **NSSM** / **Windows Service** wrappers. |
| **Someone else uses the GPU** | You cannot fully prevent contention; mitigate with **smaller models**, **scheduled** demo windows, or **coordination** with lab admins. |

**Logout vs reboot:** A **systemd user session** may stop when the interactive user logs out—**system-wide** services are more reliable for a **headless** “server” role. Confirm lab policy before running 24/7 daemons.

---

### K.6 — Cost summary (illustrative)

Figures are **order-of-magnitude** and **tier-dependent**; verify current vendor pricing.

| Layer | Component | Typical student / lab angle | Why it helps |
|-------|-----------|-----------------------------|--------------|
| **Compute** | College **GPU** (Llama 3.1 8B + local STT/TTS) | **₹0** marginal per inference vs cloud tokens | No **per-token** bill; **privacy** on that hop; **policy** and **uptime** are the tradeoffs. |
| **Connectivity** | **Cloudflare Tunnel** | **₹0** on free/hobby patterns for many setups | **HTTPS** + **no** static IP + **no** campus inbound holes. |
| **Database + auth** | **Supabase** (if chosen) | **₹0** within free-tier limits | **Postgres + Auth** in one place; compare with staying on **Firebase**. |
| **STT / TTS** | **faster-whisper + Kokoro** (local) | **₹0** API fees | **VRAM** and **ops time** are the real costs. |

---

### K.7 — Why this architecture fits CommuniQ

- **Long practice sessions** without a **large monthly** Groq/OpenAI-style token bill, as long as the **lab machine is available**.
- **Tunnel** makes the phone app reach a **private** network without **NAT tricks**.
- **R2** (or similar) avoids treating the **shared PC disk** as the **system of record** for user audio.
- **Real-time / interruptible voice** (**Part H**) is **research-grade** either way; local inference removes **some** vendor cost barriers so you can **prototype** streaming stacks longer.

### K.8 — Mental model (one paragraph)

CommuniQ’s **orchestrator** is **FastAPI**: it runs **Whisper-class STT**, calls **Ollama or vLLM** for **text generation**, then **Kokoro-class TTS**, and returns audio to the client path you configured. **vLLM** is the **engine** for batched LLM inference, not a replacement for that orchestration. **Cloudflare Tunnel** exposes **only** the HTTP surface you configure (ideally **Node** or a hardened FastAPI)—it forwards to **localhost**, where the **GPU** work happens. **Supabase** and **R2** hold **identity and durable blobs** so a **reimaged lab PC** does not erase your product’s memory.

---

## Quick reference — who hosts what (end state if everything is local)

| Function | Typical host | Flutter talks to |
|----------|--------------|------------------|
| Auth, sessions, Firestore | Node + Firebase | Node |
| STT, LLM, TTS, intelligence | FastAPI (+ maybe sidecars) | Still only Node (recommended) |
| Real-time voice (optional) | LiveKit / Pipecat worker | Signaling + media SDK |
| Training | Offline GPU | N/A (not runtime) |

### Quick reference — college hybrid (Part K)

| Function | Typical host | Client / tunnel notes |
|----------|--------------|------------------------|
| STT + LLM + TTS + orchestration | **GPU workstation** (FastAPI + local models) | Reachable via **Cloudflare Tunnel** (or VPN); **do not** expose Ollama/vLLM ports publicly. |
| Auth + scores (if using Supabase) | **Supabase** | Flutter uses Supabase SDK **only if** you adopt this stack; else **Firebase + Node** remains the source of truth. |
| Audio blobs (optional) | **Cloudflare R2** | Upload from **Node** or FastAPI with **presigned URLs**; define **retention** policy. |
| Web / admin (optional) | **Vercel** | Not on the hot path for native-only mobile. |

---

## Suggested reading order

1. Read **Part A** if deploy is still flaky.  
2. Read **Part C.1** when you first wire **local STT**.  
3. Read **C.2 / C.3** when GPU planning.  
4. Read **D / E** for UX latency.  
5. Read **F / G** before promising pronunciation scores.  
6. Read **H** only when HTTP is clearly the bottleneck.  
7. Read **I** when you have a dataset.  
8. Read **Part K** when you are placing **inference on a college/lab GPU** and need **tunnel + lean cloud** in one flow.  
9. Keep **J** open as a checklist forever.

For tradeoffs (e.g. Kokoro vs OmniVoice, Groq vs local), see **Validation and design rationale** in [COMMUNIQ_LONG_TERM_ROADMAP.md](COMMUNIQ_LONG_TERM_ROADMAP.md).
