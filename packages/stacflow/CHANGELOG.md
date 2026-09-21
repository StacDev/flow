## 0.1.0

- First release: `StacFlowChat`, the chat controller, and `StacFlowChatView`, the ready-made screen built on flow_ui, with streaming, stop, retry, regenerate, edit-and-resend, image attachments, copy, feedback and a model selector.
- `GeminiProvider`, `OpenAIProvider` (Chat Completions, with `baseUrl` for Ollama, Groq, OpenRouter, LM Studio and vLLM) and `AnthropicProvider`, each streaming replies and taking image input, all called with the developer's own key.
- `AgentConfig` for instructions and sampling, `FlowStrings` for every string the SDK shows, `ChatError` for failed turns.
- Tools: `Tool` registered with `StacFlowChat(tools:)`, run by the pure-Dart `runToolLoop` with results fed back to the model; permission classes `read`, `write` and `destructive`, the confirmation card for gated calls, a tool card per call, `toolBodyBuilder` on the view, `ChatState.toolCalls`, `respondToToolCall`, `maxToolRounds` and the new `FlowStrings` for approvals and tool failures. Calls and results are replayed to the model in later turns.
- Adapters emit the wire `SseEvent` union, tool calls included; `TurnTransport`, `TurnRequest` and the wire types are public for custom providers.
