# Changelog

All notable changes to the `denizen_ai` SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.1.0-dev.1] - 2026-09-01

### Added
- **Core Engine & Architecture**: On-device Small Language Model (SLM) inference loop with ARM64 NEON acceleration for GGUF models.
- **Stateful Chat Sessions (`DenizenSession`)**:
  - Memory-safe sliding context window eviction with heuristic token budgeting.
  - Asynchronous sequential request queue (`AsyncSequentialQueue`) for race-free multi-turn conversations.
  - Streaming token responses (`Stream<String>`) and rollback safety on generation failure.
- **Offline Vector RAG Pipeline (`DenizenRagSession`)**:
  - 384-dimensional on-device vector embedding generation (`TFLiteEmbeddingProvider` + `WordPieceTokenizer`).
  - Transactional hardware-accelerated vector similarity search powered by `sqlite-vec` C-FFI.
  - Background isolate offloading (`Isolate.run`) for PDF/DOCX/TXT text extraction and token chunking with a 100-chunk safety cap.
- **Structured Tool Calling & GBNF Grammar (`DenizenToolSession`)**:
  - JSON Schema to GBNF grammar compiler (`DenizenGrammar`) for deterministic JSON function calling.
  - Autonomous multi-turn function execution loops.
- **Voice & Vision Subsystems**:
  - Real-time offline Speech-To-Text (Whisper) + local Text-To-Speech loop (`DenizenVoiceSession`).
  - Multimodal vision analysis interface for visual projectors (`DenizenVisionSession`).
- **Resilient Model Downloader (`DenizenModelManager`)**:
  - Resumable streaming downloads via native `HttpClient` with HTTP Range headers.
  - LRU storage eviction with resident model pinning.
  - Built-in model catalog for Google Gemma 2 2B Instruct, Qwen 2.5 (0.5B/1.5B/3B), and Llama 3.2 (1B/3B).
