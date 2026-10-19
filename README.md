# Denizen AI Engine 🚀

> **Privacy-first, On-Device Multimodal AI Engine & Orchestrator for Flutter**  
> Run local LLMs, Vector RAG search, Structured Tool Calling, Conversational Voice, and Vision analysis 100% offline with zero cloud API fees and zero telemetry.

---

## 📊 Feature Matrix

| Feature | Release | Status | Details |
|---|---|---|---|
| 🧠 **Model Download & Lifecycle Management** | **v1.0** | 🟢 **Production Ready** | Resumable chunked GGUF downloading, pre-pushed import, LRU storage eviction, and memory management. |
| 💬 **Prompting & Streaming Q&A** | **v1.0** | 🟢 **Production Ready** | Stateful chat sessions (`DenizenSession`), token streaming, sliding context window eviction, and rollback safety. |
| 🔍 **Offline Vector RAG Engine** | **v1.0** | 🟢 **Production Ready** | TF-Lite embedding extraction + `sqlite-vec` local vector database for PDF document reasoning. |
| 🛠️ **Structured Tool Calling** | **v1.0** | 🟢 **Production Ready** | GBNF context grammar constraints for guaranteed JSON function calling (`DenizenToolSession`). |
| 🎙️ **Conversational Voice** | **v1.0** | 🟢 **Production Ready** | Real-time offline Speech-to-Text (Whisper) + Text-to-Speech (TTS) loop (`DenizenVoiceSession`). |
| 👁️ **Multimodal Vision** | **v2.0 Preview** | 🟡 **Experimental** | Abstract API ready (`DenizenVisionSession`); native C++ `clip.h` projector binding in progress. |

---

## 📱 Supported Platforms

| Platform | Native Inference Engine | Vector RAG (`sqlite-vec`) | Voice (STT/TTS) | Status |
|---|---|---|---|---|
| **Android (ARM64-v8a)** | 🟢 Full (`llama.cpp` NEON) | 🟢 Embedded C Extension | 🟢 Whisper / Native TTS | **Primary Production Target** (API 24+) |
| **Android (x86_64)** | 🟢 Full (SSE/AVX) | 🟢 Embedded C Extension | 🟢 Whisper / Native TTS | Emulator & Chromebook support |
| **Windows (x64)** | 🟡 Dev / Mock Engine | 🟢 Bundled `vec0.dll` C-FFI | 🟡 System TTS | Development, testing & CI |
| **iOS / macOS / Linux** | 📋 Roadmap | 📋 Roadmap | 📋 Roadmap | Planned for upcoming releases |

---

## 🏗️ Denizen AI System Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Denizen Orchestrator                            │
│ ┌──────────────────┐  ┌───────────────────┐  ┌───────────────────────┐ │
│ │  DenizenAI       │  │ DocumentIngestion │  │   DenizenToolSession  │ │
│ │  (Singleton SDK) │  │   Service (RAG)   │  │ (Tool Calling & GBNF) │ │
│ └────────┬─────────┘  └─────────┬─────────┘  └───────────┬───────────┘ │
├──────────┼──────────────────────┼────────────────────────┼─────────────┤
│          ▼                      ▼                        ▼             │
│                 Multimodal & Native Hardware Layer                     │
│ ┌──────────────────┐  ┌───────────────────┐  ┌───────────────────────┐ │
│ │DenizenVoiceSess. │  │DenizenVisionSess. │  │  VectorStorageService │ │
│ │  • Offline STT   │  │  • Image Analysis │  │  • TFLite Embeddings  │ │
│ │  • Offline TTS   │  │  • Experimental   │  │  • sqlite-vec DB      │ │
│ └────────┬─────────┘  └─────────┬─────────┘  └───────────┬───────────┘ │
└──────────┼──────────────────────┼────────────────────────┼─────────────┘
           │                      │                        │
           ▼                      ▼                        ▼
┌────────────────────────────────────────────────────────────────────────┐
│                    Pre-Compiled Native C++ Binaries                    │
│    • libllama.so (Android ARM64 NEON)    • vec0.dll (Windows x64)     │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 📦 Installation

Add `denizen_ai` to your Flutter project's `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter

  denizen_ai:
    git:
      url: https://github.com/Ubuntu-Edge/denizen_ai_os.git
      ref: main

  path_provider: ^2.1.5
```

Run in your terminal:
```bash
flutter pub get
```

📖 **Complete Guide**: Check out our [Getting Started Guide](doc/GETTING_STARTED.md) for full step-by-step documentation, recommended GGUF model links, and platform setup.

---

## 🚀 Quickstart

### 1. Initialize Engine & Stream Local LLM Responses

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:denizen_ai/denizen_ai.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sdk = DenizenAI();

  // Load a model by ID (downloads if not cached, or loads from disk)
  await sdk.models.load(
    'qwen2.5-0.5b',
    onProgress: (progress) {
      print('Download progress: ${progress.percent.toStringAsFixed(1)}%');
    },
  );

  // Or load directly from a local File:
  // await sdk.models.loadFromFile(File('/path/to/model.gguf'));

  // Create stateful conversation session
  final session = sdk.createSession(
    systemPrompt: 'You are a concise, helpful assistant.',
  );

  // Stream tokens in real time
  final tokenStream = session.streamChat('Explain quantum computing in 2 short sentences.');
  await for (final token in tokenStream) {
    stdout.write(token);
  }
}
```

---

### 2. Offline Vector RAG (Document Ingestion & Query)

```dart
import 'package:denizen_ai/denizen_ai.dart';

Future<void> runRagDemo(DenizenAI sdk) async {
  final storage = VectorStorageService();
  final embedder = TFLiteEmbeddingProvider();
  final ingestion = DocumentIngestionService(
    storage: storage,
    embeddingProvider: embedder,
  );

  // Ingest local document into vector store
  await ingestion.ingestDocument(filePath: '/path/to/handbook.pdf');

  // Create RAG session combining on-device LLM with vector store
  final ragSession = sdk.createRagSession(
    storage: storage,
    embedder: embedder,
  );

  final answer = await ragSession.chat('What is our emergency response protocol?');
  print('AI: $answer');
}
```

---

### 3. Parallel Tool Calling with GBNF Constraints

```dart
import 'package:denizen_ai/denizen_ai.dart';

Future<void> runToolDemo(DenizenAI sdk) async {
  final registry = DenizenToolRegistry();

  // Register a custom function with JSON Schema validation
  registry.registerTool(
    name: 'get_weather',
    description: 'Fetches current weather for a city',
    parameters: {
      'type': 'object',
      'properties': {
        'city': {'type': 'string'},
      },
      'required': ['city'],
    },
    handler: (args) async => 'Weather in ${args['city']} is 24°C, Sunny',
  );

  final toolSession = sdk.createToolSession(registry: registry);

  // Engine executes function loop & returns final synthesized response
  final result = await toolSession.chat('What is the weather in Nairobi?');
  print(result);
}
```

---

### 4. Conversational Voice Session

```dart
import 'package:denizen_ai/denizen_ai.dart';

Future<void> runVoiceDemo(DenizenAI sdk) async {
  final voiceSession = sdk.createVoiceSession();

  await voiceSession.startListening(
    onSpeechRecognized: (userText) => print('User said: $userText'),
    onResponseGenerated: (aiReply) => print('AI replied: $aiReply'),
  );
}
```

---

## 📂 Repository Structure

```
staging_denizen_ai_os/
├── android/                           ← Android native plugin & JNI bindings (ARM64 NEON)
├── assets/models/                     ← Default model configs and catalogs
├── doc/                               ← In-depth architecture & integration documentation
│   ├── FLUTTER_INTEGRATION.md         ← Step-by-step Flutter setup & privacy guarantees
│   ├── GETTING_STARTED.md             ← Quickstart & recommended model selection
│   ├── models_guide.md                ← GGUF quantization & memory budgeting
│   └── developer_experience_medical_chw.md
├── example/                           ← Working Flutter showcase application
├── lib/                               ← Core Denizen AI SDK Source
│   ├── denizen_ai.dart                ← Main entry export & public API
│   └── src/
│       ├── audio/                     ← Offline STT / TTS Voice Sessions
│       ├── config/                    ← Platform configuration hooks
│       ├── grammar/                   ← GBNF Schema Compiler
│       ├── llama/                     ← Llama Controller & bindings
│       ├── models/                    ← Offline Model Definitions
│       ├── orchestrator/              ← Denizen Orchestrator
│       ├── rag/                       ← TF-Lite Embeddings & Vector Storage
│       ├── services/                  ← Hardware, Download, and Offline AI Services
│       ├── tools/                     ← Parallel Tool Calling & Sessions
│       └── vision/                    ← Multimodal Vision Analysis (Experimental)
├── src/                               ← C/C++ SQLite-Vec vector extension source
├── test/                              ← Automated test suite (67 unit & integration tests)
└── windows_deps/                      ← Windows development binaries
```

---

## 📄 License & Distribution

- **Dart SDK Source Code**: Licensed under the open-source **[MIT License](LICENSE)**.
- **Native Runtime Binaries**: Precompiled native inference binaries are distributed under the **[Denizen AI Native Runtime License](LICENSE-NATIVE.md)**.
- **Third-Party Open Source**: Upstream attributions for `llama.cpp`, `sqlite-vec`, `whisper.cpp`, and `TensorFlow Lite` are provided in **[NATIVE_THIRD_PARTY_NOTICES.md](NATIVE_THIRD_PARTY_NOTICES.md)**.
