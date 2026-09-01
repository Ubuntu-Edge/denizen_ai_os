# Offline AI Architecture — Technical Deep-Dive

This document explains the internal workings of the offline AI architecture so developers can understand, extend, and integrate it.

## Data Flow

The complete lifecycle of an offline AI interaction (including standard LLM chats, RAG document-augmented queries, and offline voice sessions) follows this pipeline:

```
 User Query / Audio Input / Document Upload
                     │
                     ▼
        ┌─────────────────────────┐     ┌─────────────────────────────────┐
        │  ChatProvider / Voice   │────▶│ Smart Routing Decision           │
        │  (Orchestrator)         │     │ 1. Is mode == offline?           │
        └────────────┬────────────┘     │ 2. Is offline model loaded?      │
                     │                  │ 3. Is internet available?         │
                     │                  │ 4. Can we fall back?             │
                     │                  └───────────┬─────────────────────┘
                     │                              │
                     │              ┌───────────────┼───────────────┐
                     │              ▼                               ▼
                     │     ┌──────────────┐                ┌──────────────┐
                     │     │ Online Path  │                │ Offline Path │
                     │     │ (AIService)  │                │(OfflineAI)   │
                     │     └──────┬───────┘                └──────┬───────┘
                     │            │                               │
                     │            ▼                               ▼
                     │     ┌──────────────┐                ┌──────────────┐
                     │     │ HuggingFace  │                │ llama.cpp    │
                     │     │ API Call     │                │ Direct Path  │
                     │     │ (medgemma)   │                │ Inference    │
                     │     └──────┬───────┘                └──────┬───────┘
                     │            │                               │
                     │            ▼                               │
        ┌────────────┴────────────┐                               │
        ▼                         ▼                               │
┌──────────────┐          ┌──────────────┐                        │
│ Offline Voice│          │ Vector / RAG │                        │
│ Session      │          │ Pipeline     │                        │
│(SpeechToText)│          │ (Isolate.run)│                        │
└───────┬──────┘          └───────┬──────┘                        │
        │                         │                               │
        ▼                         ▼                               │
┌──────────────┐          ┌──────────────┐                        │
│ Processed    │          │ Context      │                        │
│ Transcripts  │          │ Injection    │                        │
└───────┬──────┘          └───────┬──────┘                        │
        │                         │                               │
        └─────────────────────────┼───────────────────────────────┘
                                  │
                                  ▼
                         ┌────────────────┐
                         │ Reset KV Cache │
                         │ Clamp Context  │
                         └───────┬────────┘
                                 │
                                 ▼
                         ┌────────────────┐
                         │ Raw token      │
                         │ stream to UI   │
                         └───────┬────────┘
                                 │
                                 ▼
                         ┌────────────────┐
                         │ processOffline │
                         │ Response       │
                         │ (Safety Filter)│
                         └───────┬────────┘
                                 │
                                 ▼
                         ┌────────────────┐
                         │ Final Safe     │
                         │ Response       │
                         └────────────────┘
```

## Smart Routing Logic

The `ChatProvider.sendMessage()` method implements intelligent routing:

```
if mode == ONLINE:
    if internet available:
        try online API
        on failure (network error) AND offline model loaded:
            fall back to offline  ← Smart fallback
        on failure (other error):
            show error
    else if offline model loaded:
        use offline  ← Auto-switch
    else:
        show "no internet, no model" error

if mode == OFFLINE:
    if offline model loaded:
        use offline
    else:
        show "download a model" guidance
```

Key design decisions:
- **User controls the mode** — no auto-switching from offline→online
- **Smart fallback only** — online→offline fallback is automatic when network fails
- **Mode persisted** — user's choice survives app restart via SharedPreferences

## Retrieval-Augmented Generation (RAG) Architecture

The offline RAG pipeline allows the application to analyze local documents without internet access:

### 1. Document Ingestion Pipeline (`DocumentIngestionService`)
- **Isolate Offloading (`Isolate.run`):** Document text extraction, cleaning, and text chunking are executed inside background Flutter isolates. This prevents main-thread blockages and UI frame drops during large file imports.
- **Safety Cap:** Ingestion enforces a hard safety limit of **100 chunks** per document to prevent memory exhaustion on resource-constrained mobile hardware.

### 2. Transactional Vector Storage (`VectorStorageService`)
- **Batch Processing:** Document vectors are inserted using transactional batch operations (`insertChunkBatch`) for atomic disk writes and speed.
- **Document Cleanup:** Supports targeted document removal (`deleteDocumentByTitle`) to synchronize vector store indices when documents are deleted or updated.
- **Embeddings:** Text chunks are embedded locally using ONNX / TFLite embeddings prior to vector similarity retrieval during queries.

## Inference Engine & KV Cache Management

The `llama_flutter_android` JNI layer manages state integrity and memory during execution:

### 1. KV Cache Clearing (`clearKvCache()`)
- Between completion requests and turn transitions, the native inference engine explicitly calls `clearKvCache()`.
- **Purpose:** Prevents cross-turn token contamination, prompt bleeding, and context degradation during long chat conversations.

### 2. Prompt Token Clamping & Template Formatting
- **Token Clamping:** Input tokens are clamped to the model's target context boundary prior to native invocation to eliminate low-level memory out-of-bounds crashes.
- **Gemma BOS Normalization:** Prevents duplicate `Beginning-Of-Sequence` (`<bos>`) tokens when formatting prompts for Google Gemma and ChatML templates.

### 3. Zero-Copy Direct Path Loading
- Eliminates legacy main-thread GGUF file copying on model instantiation.
- Models are initialized directly via `targetPath`, loading GGUF binaries straight from storage into memory.

## Model Download & CDN Resiliency Pipeline

```
downloadModel(url, modelId, fileName)
     │
     ▼
 Native HttpClient Stream Initialized
     │
     ├── Direct CDN streaming without HEAD compression probing
     └── Automatic HTTP Range resume support
     │
     ▼
 Stream download with progress tracking
     │
     ▼
 Extract gzip with progress (if compressed .gguf.gz)
     │
     ▼
 Resilient Model Lookup Resolution (_lookUpModel)
     │
     ▼
 Persist local path & state to SharedPreferences
```

### Download Architecture Key Improvements:
- **Native `HttpClient` Streaming:** Uses Flutter native `HttpClient` for stable downloads from Hugging Face and custom CDNs.
- **Disabled Compression Probing:** Bypasses HTTP HEAD probing to fix progress hangs caused by Hugging Face CDN headers.
- **Resilient Fallback Lookup:** `_lookUpModel()` includes fallback resolution logic to match downloaded GGUF files even if exact metadata tag casing differs.

### Storage Strategy

```dart
// Android: External storage (survives app updates)
getExternalStorageDirectory()
  → /storage/emulated/0/Android/data/com.app/files/models/

// Fallback: Internal storage
getApplicationDocumentsDirectory()
  → /data/data/com.app/app_flutter/models/
```

Why external storage? Large GGUF models (1-3 GB) shouldn't need re-downloading when the app updates. External storage persists across updates while internal storage may be cleared.

## Safety Filter Pipeline

The `AIService` implements a 3-stage safety pipeline that processes both online and offline responses:

### Stage 1: `_cleanResponse(raw)`
- Strips markdown formatting (asterisks, hashtags, brackets)
- Normalizes whitespace
- Converts bullet points to dashes

### Stage 2: `_reformatToSections(cleaned)`
Enforces a strict 3-section format:
```
Assessment: [1-2 sentences, no diagnosis]
Action:
- [first action]
- [second action]
Important: [when to seek professional care]
```

Parsing logic:
1. Skip intro fluff ("Okay, I understand...", "Here's what...")
2. Extract bullet points as Action items
3. Detect closing "seek doctor" sentences as Important
4. Provide safe defaults if sections are missing

### Stage 3: `_applySafetyFilter(structured)`
Scans for blocked medical terms:
- Drug names: `amoxicillin`, `ibuprofen`, `paracetamol`
- Diagnostic terms: `cancer`, `HIV`, `tuberculosis`
- Dangerous advice: `rush to hospital`, `emergency`

If any trigger is found, replaces entire response with a safe fallback message.

## Device-Adaptive Configuration

The `OfflineContextParams` class provides presets for different device capabilities:

| Parameter | Low-End (<4GB) | Mid-Range (4-8GB) | High-End (8GB+) |
|-----------|---------------|-------------------|-----------------|
| Context | 1024 tokens | 2048 tokens | 4096 tokens |
| Threads | 2 | 4 | 6 |
| Batch Size | 128 | 256 | 512 |
| GPU Layers | 0 | 20 | 99 |

## Model Auto-Detection & Catalog

When `OfflineModelProvider.initialize()` runs, it performs filesystem scanning:

1. Get storage directory (external → internal fallback)
2. Recursively list all `.gguf` files
3. Match filenames against known models in `DefaultOfflineModels` (including Google Gemma 2 2B Instruct, Qwen 2.5, SmolLM2)
4. Update model state (`isDownloaded`, `localPath`)
5. Persist updated state to SharedPreferences

### Supported Models Catalog Highlight:
- **Google Gemma 2 2B Instruct (`gemma-2-2b-it`):** Recommended model for high-accuracy local RAG, logical reasoning, and structured output generation.
- **Qwen 2.5 1.5B / SmolLM2:** Lightweight models optimized for low-end mobile devices.

## Offline Voice Architecture (`DenizenVoiceSession`)

The offline speech & audio subsystem provides real-time voice processing:
- **`OfflineAudioService`:** Handles local audio recording, STT (Speech-To-Text) decoding, and audio stream buffer management.
- **`DenizenVoiceSession`:** Manages stateful voice interactions, connecting transcribed audio directly to `OfflineAIService` and playing back responses via TTS without requiring network connectivity.

## Extension Points

### Adding New Models

Edit `default_offline_models.dart`:

```dart
OfflineModel(
  id: 'gemma-2-2b-it',
  name: 'Gemma 2 2B Instruct',
  author: 'Google',
  size: 1630000000, // bytes
  downloadUrl: 'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf',
  filename: 'gemma-2-2b-it-Q4_K_M.gguf',
  quantization: 'Q4_K_M',
  description: 'High accuracy RAG and logical reasoning',
  tags: ['medical', 'rag', 'gemma'],
  contextSize: 4096,
),
```

### Custom Prompt Templates

The `OfflineAIService.formatChatPrompt()` method generates prompt templates per model architecture (e.g. ChatML, Gemma, or Llama `[INST]...[/INST]`).

### Custom Safety Rules

Modify `_applySafetyFilter()` in `ai_service.dart` to add/remove blocked terms.
Modify `_reformatToSections()` to change the output structure.

### Adding Persistence

The `ChatProvider` supports persistence plug-ins:
- SQLite via `drift` or `sqflite`
- Hive for key-value storage
- Firebase for cloud sync

### Adding New Languages

The `AIService._detectLanguage()` method currently supports English and Kiswahili. Add new languages by:
1. Adding word lists to the detection method
2. Adding system prompt translations in `_buildMessages()`
3. Adding safety filter fallback messages

## Dependencies Graph

```
llama_flutter_android (native plugin with KV cache reset & zero-copy direct path)
  └── OfflineAIService
        ├── OfflineModelProvider
        │     └── ChatProvider → UI
        └── DenizenVoiceSession (Offline Voice)

connectivity_plus (platform plugin)
  └── ConnectivityService
        └── ChatProvider → UI

DocumentIngestionService (Isolate.run)
  └── VectorStorageService (insertChunkBatch / deleteDocumentByTitle)
        └── OfflineAIService (RAG context injection)

http / HttpClient (native streaming)
  ├── AIService (online API)
  └── ModelDownloadService (resilient downloads)

shared_preferences (platform plugin)
  ├── OfflineModelProvider (model state)
  ├── ChatProvider (mode persistence)
  └── ModelDownloadService (download state)

provider (Dart package)
  └── All UI screens

path_provider (platform plugin)
  ├── OfflineModelProvider (model paths)
  └── ModelDownloadService (storage dir)
```

## Performance Notes

- **Model loading**: 5-30 seconds depending on model size and device (optimized via direct targetPath load)
- **Token generation**: 4-15 tokens/second on mid-range Android
- **RAG Ingestion**: Fast Isolate execution with 100-chunk cap ensuring zero UI stutter
- **Memory usage**: Model size + ~500MB overhead (clamped to context limit)
- **Download**: Stable HttpClient streaming with resume support
- **Storage**: External storage preferred (survives app updates)
