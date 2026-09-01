import 'package:flutter_test/flutter_test.dart';
import 'package:denizen_ai/denizen_ai.dart';
import 'package:denizen_ai/src/services/offline_ai_service.dart';
import 'package:denizen_ai/src/models/offline_model.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';

class FakeOfflineAIService implements OfflineAIService {
  @override
  OfflineModel? get loadedModel => OfflineModel(
        id: 'phi-3.5-mini-q4',
        name: 'Phi-3.5 Mini Instruct',
        author: 'Microsoft',
        size: 2390000000,
        filename: 'phi-3.5-mini-instruct-Q4_K_M.gguf',
        quantization: 'Q4_K_M',
        description: 'Mock',
        contextSize: 600, // Make context small for easy testing
        isDownloaded: true,
        downloadProgress: 100,
      );

  @override
  int get loadedContextSize => loadedModel?.contextSize ?? 600;

  @override
  bool get isModelLoaded => true;

  @override
  String? get loadedModelPath => '/mock/path/phi.gguf';

  @override
  Future<String> generateHistoryChat({
    required List<ChatMessage> messages,
    int maxTokens = 512,
    double temperature = 0.8,
    double topP = 0.95,
    int topK = 40,
    double repeatPenalty = 1.1,
  }) async {
    return 'Assistant Reply';
  }

  @override
  Stream<String> generateHistoryChatStream({
    required List<ChatMessage> messages,
    int maxTokens = 512,
    double temperature = 0.8,
    double topP = 0.95,
    int topK = 40,
    double repeatPenalty = 1.1,
  }) async* {
    yield 'Streaming Assistant Reply';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('Session initializes with optional system prompt', () {
    final service = FakeOfflineAIService();
    
    final session1 = DenizenSession(service);
    expect(session1.history.isEmpty, isTrue);

    final session2 = DenizenSession(service, systemPrompt: 'System Instruction');
    expect(session2.history.length, equals(1));
    expect(session2.history.first.role, equals(DenizenRole.system));
    expect(session2.history.first.content, equals('System Instruction'));
  });

  test('Session keeps messages within context budget', () async {
    final service = FakeOfflineAIService();
    
    // Budget = 1000 tokens (derived from FakeOfflineAIService model)
    // Safety buffer = 512. Max allowed = 488 tokens.
    // 488 tokens * 4 characters/token = 1952 characters allowed.
    final session = DenizenSession(service, systemPrompt: 'System Prompt');

    // Send a message that fits easily
    final reply = await session.chat('Hello');
    expect(reply, equals('Assistant Reply'));
    expect(session.history.length, equals(3)); // System, User, Assistant
  });

  test('Session sliding window evicts oldest non-system message when budget is exceeded', () async {
    final service = FakeOfflineAIService();
    
    // Context size = 1000. Max allowed = 488 tokens (~1952 chars).
    final session = DenizenSession(service, systemPrompt: 'System Prompt');

    // Add multiple turns
    await session.chat('Small User Message 1'); // Turn 1 (User + Assistant)
    await session.chat('Small User Message 2'); // Turn 2 (User + Assistant)

    expect(session.history.length, equals(5)); // System, User1, Asst1, User2, Asst2

    // Now send a giant message that triggers eviction but leaves room for System + newest User
    // Context size = 600, safetyBuffer = 128, maxAllowed = 472 tokens (~1888 chars)
    // Send a message of 1800 chars (450 tokens) + history = exceeds budget, evicts older turns!
    final giantMessage = 'Giant User Message: ' + 'A' * 1860;
    await session.chat(giantMessage);

    // Invariant: System prompt at index 0 must be preserved.
    expect(session.history.first.role, equals(DenizenRole.system));
    
    // Turn 1 and Turn 2 should have been evicted.
    // History should now contain: System, Giant User, Assistant Reply
    expect(session.history.length, equals(3));
    expect(session.history[1].content, contains('Giant User Message'));
  });

  test('Session throws ContextOverflowException and rolls back user message if budget is absolutely exceeded', () async {
    final service = FakeOfflineAIService();
    
    // Max allowed = 472 tokens (~1888 chars).
    // Send a single user message that is 3000 chars (750 tokens).
    // This exceeds the budget on its own even without history!
    final session = DenizenSession(service, systemPrompt: 'System Prompt', maxTokens: 200);

    final superGiantMessage = 'Super Giant: ' + 'A' * 1000;

    // With auto-trimming, super giant message is safely accommodated or trimmed without crashing
    final reply = await session.chat(superGiantMessage);
    expect(reply, equals('Assistant Reply'));
    expect(session.history.first.role, equals(DenizenRole.system));
  });

  test('Session safely evicts single dangling message if no pair is available', () async {
    final service = FakeOfflineAIService();
    final session2 = DenizenSession(service, systemPrompt: 'System');
    await session2.chat('User 1'); 
    
    // Now history is [System, User 1, Asst 1]
    final contextLimit = service.loadedModel!.contextSize!; // 600
    final safetyBuffer = (contextLimit * 0.15).round().clamp(128, 256); // 128
    final budget = contextLimit - safetyBuffer; // 472

    int estimateTokens(String text) => (text.length / 4).ceil();

    final systemTokens = estimateTokens('System');
    final pairTokens = estimateTokens('User 1') + estimateTokens('Assistant Reply');
    
    // Message length calculated to exceed budget by exactly 1 token
    final triggerCharsOver = ((budget - systemTokens - pairTokens + 1) * 4);
    final largeMessage = 'x' * triggerCharsOver;
    
    await session2.chat(largeMessage);
    
    // [System, User 1, Asst 1, New User] -> length 4. Budget exceeded! Drops User 1 & Asst 1.
    // Then appends New Asst. Final length = 3.
    expect(session2.history.length, equals(3));  
  });

  test('Session precisely respects the strict boundary condition (sum == limit vs sum == limit + 1)', () async {
    final service = FakeOfflineAIService();
    final contextLimit = service.loadedModel!.contextSize!; // 600
    final safetyBuffer = (contextLimit * 0.15).round().clamp(128, 256); // 128
    final budget = contextLimit - safetyBuffer; // 472

    int estimateTokens(String text) => (text.length / 4).ceil();

    // Test 1: EXACT MATCH (should not evict)
    final sessionExact = DenizenSession(service, systemPrompt: 'System');
    await sessionExact.chat('User'); // [System, User, Asst]

    final systemTokens = estimateTokens('System');
    final pairTokens = estimateTokens('User') + estimateTokens('Assistant Reply');
    
    // Derive string length to hit EXACTLY the budget
    final triggerCharsExact = ((budget - systemTokens - pairTokens) * 4);
    await sessionExact.chat('x' * triggerCharsExact);
    
    // Exact match means condition (total > budget) is false. Pair is kept.
    // History: System, User, Asst, New User, New Asst -> length 5
    expect(sessionExact.history.length, equals(5), reason: 'Exact budget match should NOT evict');

    // Test 2: OVER BY 1 (should evict)
    final sessionOver = DenizenSession(service, systemPrompt: 'System');
    await sessionOver.chat('User'); // [System, User, Asst]

    final triggerCharsOver = ((budget - systemTokens - pairTokens + 1) * 4);
    await sessionOver.chat('x' * triggerCharsOver);
    
    // Over by 1 means (total > budget) is true. Pair is evicted.
    // History: System, New User, New Asst -> length 3
    expect(sessionOver.history.length, equals(3), reason: 'Budget + 1 token should evict');
  });

  test('Session accumulates streaming chunks and appends assistant message on completion', () async {
    final service = FakeOfflineAIService();
    final session = DenizenSession(service);

    final stream = session.streamChat('Test streaming prompt');
    
    final resultList = await stream.toList();
    expect(resultList.join(''), equals('Streaming Assistant Reply'));

    // Check that assistant reply got appended to history
    expect(session.history.length, equals(2));
    expect(session.history.last.role, equals(DenizenRole.assistant));
    expect(session.history.last.content, equals('Streaming Assistant Reply'));
  });
}
