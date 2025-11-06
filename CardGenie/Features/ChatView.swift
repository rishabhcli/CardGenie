//
//  ChatView.swift
//  CardGenie
//
//  AI Chat interface with streaming responses.
//  Main chat view for conversational AI assistance.
//

import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var engine = ChatEngine()

    // Input state
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Chat messages
                messageList

                Divider()

                // Input area
                inputArea
                    .padding()
            }
            .navigationTitle(engine.currentSession?.title ?? "AI Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            Task {
                                engine.endSession()
                                try? await engine.startSession()
                            }
                        } label: {
                            Label("New Chat", systemImage: "plus.message")
                        }

                        Button {
                            engine.clearConversation()
                        } label: {
                            Label("Clear Messages", systemImage: "trash")
                        }

                        Button(role: .destructive) {
                            engine.endSession()
                        } label: {
                            Label("End Session", systemImage: "xmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Error", isPresented: .constant(engine.errorMessage != nil)) {
                Button("OK") {
                    engine.errorMessage = nil
                }
            } message: {
                if let error = engine.errorMessage {
                    Text(error)
                }
            }
        }
        .task {
            do {
                try await engine.startSession()
            } catch {
                engine.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if engine.messages.isEmpty && !engine.isProcessing {
                    // Empty state
                    emptyStateView
                } else {
                    // Messages
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(engine.messages) { message in
                            if message.role != .system {
                                MessageBubbleView(message: message)
                                    .id(message.id)
                            }
                        }

                        // Streaming response
                        if engine.isProcessing && !engine.streamingResponse.isEmpty {
                            MessageBubbleView(
                                message: ChatMessage(role: .assistant, content: engine.streamingResponse)
                            )
                            .id("streaming")
                        }

                        // Processing indicator
                        if engine.isProcessing && engine.streamingResponse.isEmpty {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Thinking...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .id("processing")
                        }
                    }
                    .padding()
                }
            }
            .onChange(of: engine.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: engine.streamingResponse) { _, _ in
                withAnimation {
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }
            .onChange(of: engine.isProcessing) { _, isProcessing in
                if isProcessing {
                    withAnimation {
                        proxy.scrollTo("processing", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "message.badge.waveform")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 8) {
                Text("AI Study Assistant")
                    .font(.title.bold())

                Text("Ask me anything about your studies")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Quick start suggestions
            VStack(alignment: .leading, spacing: 12) {
                Text("Try asking:")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                QuickStartButton(icon: "questionmark.circle.fill", text: "Explain photosynthesis") {
                    inputText = "Explain photosynthesis in simple terms"
                    isInputFocused = true
                }

                QuickStartButton(icon: "lightbulb.fill", text: "Help me understand calculus") {
                    inputText = "Help me understand basic calculus concepts"
                    isInputFocused = true
                }

                QuickStartButton(icon: "book.fill", text: "Quiz me on biology") {
                    inputText = "Quiz me on cellular biology"
                    isInputFocused = true
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)

            Spacer()
        }
        .padding()
    }

    // MARK: - Input Area

    private var inputArea: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // Text input
            TextField("Ask me anything...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                .lineLimit(1...5)
                .focused($isInputFocused)
                .disabled(engine.isProcessing)

            // Send button
            Button {
                sendMessage()
            } label: {
                Image(systemName: inputText.isEmpty ? "arrow.up.circle" : "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(inputText.isEmpty ? .gray : .blue)
            }
            .disabled(inputText.isEmpty || engine.isProcessing)
        }
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""

        Task {
            await engine.sendMessage(text)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessage = engine.messages.last else { return }
        withAnimation {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}

// MARK: - Message Bubble View

struct MessageBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // Message content
                Text(message.content)
                    .padding(12)
                    .background(backgroundColor)
                    .foregroundStyle(textColor)
                    .cornerRadius(16)
                    .textSelection(.enabled)

                // Timestamp
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 300, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .assistant {
                Spacer()
            }
        }
    }

    private var backgroundColor: Color {
        message.role == .user ? .blue : Color(.systemGray5)
    }

    private var textColor: Color {
        message.role == .user ? .white : .primary
    }
}

// MARK: - Quick Start Button

struct QuickStartButton: View {
    let icon: String
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                Text(text)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ChatView()
        .modelContainer(for: [ChatSession.self, ChatMessage.self])
}
