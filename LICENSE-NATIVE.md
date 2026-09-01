# Denizen AI Native Runtime License

This license applies **only** to the precompiled native binaries (`.so`, `.aar`, `.dll`, `.dylib`, or equivalent compiled artifacts) distributed with the Denizen AI SDK — specifically, the compiled inference engine including JNI bindings, hardware-accelerated kernels, and native memory management routines.

It does **not** apply to the Dart SDK source code in this repository, which is licensed separately under the **MIT License** (see [LICENSE](LICENSE)).

---

### 1. Grant of Use
Subject to the terms and conditions of this Agreement, Denizen AI ("Licensor") grants you a non-exclusive, non-transferable, royalty-free, worldwide license to:
1. Use the precompiled native runtime binaries as distributed, unmodified, as an embedded component of software applications built using the Denizen AI Dart SDK.
2. Distribute the precompiled native runtime binaries solely as an integrated, bundled component of your compiled consumer or enterprise application (e.g., inside an Android APK/AAB, Windows executable, or iOS app build).

---

### 2. Restrictions
Unless expressly authorized by a separate written commercial agreement with the Licensor, you shall NOT:
1. **No Reverse Engineering:** Decompile, reverse-engineer, disassemble, or attempt to derive the source code of the native runtime binaries, except to the extent that applicable law expressly prohibits this restriction.
2. **No Standalone Redistribution:** Distribute, sublicense, rent, lease, or host the native runtime binaries as a standalone product, shared library, or as part of a competing developer SDK or AI runtime tool.
3. **No Modification:** Modify, patch, adapt, or create derivative works of the native binary artifacts.
4. **No Extraction:** Extract the underlying C++ symbols, JNI bridges, or compiled kernels for independent redistribution.

---

### 3. Source Code Access & Enterprise Licensing
Source code access to the native inference engine (for custom hardware backends, specialized NPU acceleration, or self-hosted enterprise compilation) is available under a separate commercial license agreement. Contact [contact@ubuntuedge.io](mailto:contact@ubuntuedge.io) for licensing inquiries.

---

### 4. Disclaimer of Warranty
THE NATIVE RUNTIME IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NONINFRINGEMENT. IN NO EVENT SHALL THE LICENSOR OR ITS CONTRIBUTORS BE LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT, OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

---

### 5. Termination
This license terminates automatically without notice if you fail to comply with any of the terms or restrictions described in Section 2. Upon termination, you must immediately cease all distribution and usage of the native runtime binaries.

---

### 6. Third-Party Open Source Components
The native runtime incorporates third-party open-source components, including `llama.cpp` (MIT), `sqlite-vec` (Apache 2.0 / MIT), `whisper.cpp` (MIT), and `TensorFlow Lite` (Apache 2.0). Attribution notices for these components are provided in [NATIVE_THIRD_PARTY_NOTICES.md](NATIVE_THIRD_PARTY_NOTICES.md). Nothing in this Agreement limits rights granted to you under the respective upstream open-source licenses.
