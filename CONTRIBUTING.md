# Contributing to Denizen AI SDK

Thank you for your interest in contributing to the **Denizen AI SDK**! We welcome contributions to help make on-device, privacy-first AI accessible to developers worldwide.

---

## 🛠️ Repository Architecture

Denizen AI follows an **open-core** model:
* **The Dart SDK (`lib/`)**: 100% open-source under the [MIT License](LICENSE). This covers session management (`DenizenSession`), vector RAG pipelines (`DenizenRagSession`), GBNF grammar compilation (`DenizenGrammar`), and tool-calling orchestrations.
* **The Native Engine**: Distributed as precompiled runtime binaries under the [Denizen AI Native Runtime License](LICENSE-NATIVE.md).

---

## 🚀 Getting Started

1. **Prerequisites**:
   * Flutter SDK (3.22.0+)
   * Dart SDK (3.3.0+)
   * Android Studio / VS Code

2. **Clone and Install**:
   ```bash
   git clone https://github.com/Ubuntu-Edge/denizen_ai_os.git
   cd denizen_ai_os
   flutter pub get
   ```

3. **Running the Example App**:
   ```bash
   cd example
   flutter run
   ```

4. **Running Tests**:
   ```bash
   flutter test
   ```

---

## 📝 Pull Request Guidelines

1. **Keep it focused**: PRs should address a specific issue or feature.
2. **Include tests**: Add unit or integration tests under `test/` for new functionality.
3. **Follow Dart style guidelines**: Run `dart format .` and `flutter analyze` prior to submitting.
4. **Preserve documentation**: Update docstrings and markdown guides when changing public APIs.

---

## 💬 Community & Support

* **Issues & Discussions**: Use GitHub Issues for bug reports and feature requests.
* **Security Disclosures**: Please report security vulnerabilities privately to [security@ubuntuedge.io](mailto:security@ubuntuedge.io).
