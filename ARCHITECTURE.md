# CardGenie - Offline-First AI Study Platform Architecture

## 🏗️ **Complete Sprint 1 Implementation**

All features are **100% offline** - no network calls, all AI processing on-device.

---

## 📦 **Core Components**

### **1. AI Engine Layer** (`AIEngine.swift`)

**Protocols:**
- `LLMEngine` - Large language model interface
- `EmbeddingEngine` - Text embedding generation

**Implementations:**
- `AppleOnDeviceLLM` - Uses Foundation Models (iOS 18.1+)
- `AppleEmbedding` - On-device embeddings (384 dimensions)

**Factory:**
```swift
let llm = AIEngineFactory.createLLMEngine()
let embedding = AIEngineFactory.createEmbeddingEngine()
```

---

### **2. Data Models** (`EnhancedModels.swift`)

**SwiftData Entities:**

**SourceDocument:**
```swift
@Model
class SourceDocument {
    var kind: SourceKind // pdf, video, image, audio, csv, lecture
    var fileName: String
    var fileURL: URL?
    var totalPages: Int?
    var duration: TimeInterval?
    var chunks: [NoteChunk]
    var generatedCards: [Flashcard]
}
```

**NoteChunk:**
```swift
@Model
class NoteChunk {
    var text: String
    var summary: String?
    var pageNumber: Int? // For PDFs/images
    var timestampRange: String? // For audio/video
    var embedding: Data // [Float] encoded
    var sourceDocument: SourceDocument
}
```

**LectureSession:**
```swift
@Model
class LectureSession {
    var title: String
    var duration: TimeInterval
    var audioFileURL: URL?
    var liveNotes: String // Rolling summaries
    var chunks: [NoteChunk]
}
```

---

### **3. Processors**

#### **PDFProcessor** (`PDFProcessor.swift`)

**Pipeline:**
1. Load PDF with PDFKit
2. Extract text from each page
3. Detect scanned pages → Vision OCR fallback
4. Semantic chunking by headings
5. Generate embeddings for each chunk
6. Create summaries

**Usage:**
```swift
let processor = PDFProcessor()
let sourceDoc = try await processor.process(pdfURL: url)
// sourceDoc contains all chunks with embeddings
```

**Features:**
- ✅ Native PDF text extraction
- ✅ Vision OCR for scanned PDFs
- ✅ Heading detection & semantic chunking
- ✅ Per-chunk summarization
- ✅ Automatic embedding generation

---

#### **LectureRecorder** (`LectureRecorder.swift`)

**Real-time offline lecture recording**

**Pipeline:**
1. AVAudioEngine captures microphone
2. SFSpeechRecognizer transcribes (offline mode)
3. Save to .m4a file
4. Auto-chunk every ~100 words
5. Rolling summaries every 45 seconds
6. Generate embeddings for chunks

**Usage:**
```swift
let recorder = LectureRecorder()

// Request permissions
let granted = await recorder.requestPermissions()

// Start recording
try recorder.startRecording(title: "Bio Lecture")

// Live transcript available in recorder.transcript
// Live notes in recorder.liveNotes

// Stop and save
let session = await recorder.stopRecording()
// session contains full transcript + chunks
```

**Features:**
- ✅ Offline speech recognition (requiresOnDeviceRecognition = true)
- ✅ Real-time transcription
- ✅ Rolling live notes every 45 seconds
- ✅ Timestamp tracking
- ✅ Audio file saved for playback
- ✅ Automatic chunking & embeddings

---

#### **ImageProcessor** (`ImageProcessor.swift`)

**OCR for slides/whiteboard photos**

**Pipeline:**
1. VNRecognizeTextRequest with .accurate mode
2. Sort text by vertical position
3. Extract text per slide
4. Semantic chunking
5. Summarize each chunk
6. Generate embeddings

**Usage:**
```swift
let processor = ImageProcessor()
let images = [UIImage(named: "slide1")!, UIImage(named: "slide2")!]
let sourceDoc = try await processor.process(images: images, title: "Bio Slides")
```

**Features:**
- ✅ Vision OCR (.accurate mode)
- ✅ Custom academic vocabulary
- ✅ Multi-slide support
- ✅ Heading detection
- ✅ Per-slide chunking

---

#### **FlashcardGenerator** (`FlashcardGenerator.swift`)

**AI-powered flashcard generation**

**Card Types Generated:**
1. **Q&A Cards** - Traditional question/answer
2. **Cloze Deletion** - Fill-in-the-blank

**Usage:**
```swift
let generator = FlashcardGenerator()

// From chunks
let cards = try await generator.generateCards(
    from: sourceDoc.chunks,
    deck: flashcardSet
)

// From entire source
let deck = try await generator.generateFromSource(
    sourceDoc,
    context: modelContext
)
```

**Features:**
- ✅ Automatic Q&A generation
- ✅ Cloze deletion cards
- ✅ Smart parsing of LLM output
- ✅ Links cards to source chunks

---

#### **CSVImporter** (`CSVImporter.swift`)

**Import flashcards from CSV**

**Formats Supported:**
1. `Question,Answer`
2. `Front,Back,Tags`
3. `Note,Context` → AI generates Q&A

**Usage:**
```swift
let importer = CSVImporter()

// Direct import (CSV already has Q&A)
let deck1 = try await importer.importCSV(from: csvURL, context: modelContext)

// AI-generated import (CSV has notes/facts)
let deck2 = try await importer.importAndGenerate(from: csvURL, context: modelContext)
```

**Features:**
- ✅ Robust CSV parser (handles quotes, newlines)
- ✅ Auto-detect headers
- ✅ Tag support
- ✅ AI-powered card generation from data

---

### **4. Vector Store & RAG** (`VectorStore.swift`)

**Local vector database for semantic search**

**Components:**
- `VectorStore` - Cosine similarity search engine
- `RAGChatManager` - Conversational interface

**Usage:**
```swift
let vectorStore = VectorStore(modelContext: context)
let chatManager = RAGChatManager(vectorStore: vectorStore)

// Ask questions about your notes
let response = try await chatManager.ask(
    question: "What is photosynthesis?",
    sourceID: lectureID
)

print(response.answer) // AI answer with citations
for citation in response.citations {
    print(citation.displayText) // [1] Page 3 - Biology.pdf
}
```

**Features:**
- ✅ Cosine similarity search
- ✅ Top-k retrieval (default: 6)
- ✅ Source filtering
- ✅ Citation tracking with page/timestamp
- ✅ Context-aware answers

**RAG Pipeline:**
1. User asks question
2. Generate question embedding
3. Find top-k similar chunks
4. Build context from retrieved chunks
5. LLM generates answer with citations
6. Return answer + source references

---

## 🔄 **Complete Workflows**

### **Workflow 1: PDF Study Guide**

```swift
// 1. Import PDF
let pdfProcessor = PDFProcessor()
let sourceDoc = try await pdfProcessor.process(pdfURL: textbookURL)

// sourceDoc now contains:
// - All text extracted
// - Chunked by sections
// - Each chunk has summary & embedding

// 2. Save to database
modelContext.insert(sourceDoc)
try modelContext.save()

// 3. Generate flashcards
let generator = FlashcardGenerator()
let deck = try await generator.generateFromSource(sourceDoc, context: modelContext)

// 4. Chat about the textbook
let vectorStore = VectorStore(modelContext: modelContext)
let chat = RAGChatManager(vectorStore: vectorStore)

let answer = try await chat.ask(
    question: "Explain the Krebs cycle",
    sourceID: sourceDoc.id
)
```

---

### **Workflow 2: Lecture Recording**

```swift
// 1. Setup recorder
let recorder = LectureRecorder()
await recorder.requestPermissions()

// 2. Start recording
try recorder.startRecording(title: "Biology 101")

// 3. Access live data
print(recorder.transcript) // Real-time transcript
print(recorder.liveNotes)  // Rolling summaries

// 4. Stop and save
let session = await recorder.stopRecording()
modelContext.insert(session)
try modelContext.save()

// session.chunks contains timestamped segments with embeddings

// 5. Chat about the lecture
let answer = try await chat.ask(
    question: "What did the professor say about mitosis?",
    sourceID: session.id
)

// Answer includes timestamps: "According to [1] (12:34 - 13:15), ..."
```

---

### **Workflow 3: Slide Photos**

```swift
// 1. Take photos of slides
let slides = [slide1Image, slide2Image, slide3Image]

// 2. Process with OCR
let imageProcessor = ImageProcessor()
let sourceDoc = try await imageProcessor.process(images: slides, title: "Lecture Slides")

// 3. Generate flashcards
let deck = try await generator.generateFromSource(sourceDoc, context: modelContext)

// 4. Study the generated cards
// (Use existing FlashcardStudyView)
```

---

### **Workflow 4: CSV Import**

```swift
// Option A: Direct import (CSV has Q&A)
let importer = CSVImporter()
let deck = try await importer.importCSV(from: csvURL, context: modelContext)

// Option B: AI-generated (CSV has facts/notes)
let deck = try await importer.importAndGenerate(from: csvURL, context: modelContext)
```

---

## 🎯 **Key Design Principles**

### **1. Offline-First**
- ✅ No network calls
- ✅ `requiresOnDeviceRecognition = true` for Speech
- ✅ Vision OCR is always offline
- ✅ LLM runs on device (Apple Intelligence or Core ML)
- ✅ Embeddings generated locally

### **2. Privacy-First**
- ✅ All data in local SwiftData
- ✅ Audio files in app sandbox
- ✅ No cloud sync
- ✅ No analytics
- ✅ File protection enabled

### **3. Protocol-Based**
- ✅ Easy to swap AI backends
- ✅ Testable interfaces
- ✅ Clean separation of concerns

### **4. Performance**
- ✅ Batch embedding generation
- ✅ Chunking limits context size
- ✅ Efficient vector search
- ✅ Streaming where possible

---

## 📊 **Status: Sprint 1 Complete ✅**

### **Implemented:**
- ✅ AI Engine protocols
- ✅ Enhanced data models
- ✅ PDF processor (PDFKit + Vision)
- ✅ Lecture recorder (Speech + AVFoundation)
- ✅ Image processor (Vision OCR)
- ✅ Flashcard generator (LLM-powered)
- ✅ CSV importer
- ✅ Vector store & RAG system
- ✅ All builds successfully

### **Missing (Sprint 2):**
- ⏳ Video transcription (AVAssetReader)
- ⏳ Math solver (symbolic + LLM)
- ⏳ Voice tutoring (TTS + STT)
- ⏳ "Explain why I'm wrong" feature
- ⏳ FRQ grading system
- ⏳ UI to expose all features

---

## 🚀 **Next Steps**

### **Priority 1: Basic UI**
Create views to expose:
1. Import button for PDF/Images/CSV
2. Lecture recorder screen
3. Chat interface for RAG
4. Enhanced flashcard view showing source

### **Priority 2: Video Processing**
- AVAssetReader for audio extraction
- SFSpeechRecognizer on audio track
- Timestamp tracking

### **Priority 3: Math Solver**
- Rule engine for algebra/calculus
- LLM for step explanations
- "Why you're wrong" comparer

---

## 💡 **Architecture Strengths**

1. **Modular** - Each processor is independent
2. **Testable** - Protocol-based design
3. **Extensible** - Easy to add new source types
4. **Performant** - Efficient chunking & embedding
5. **Private** - All on-device
6. **Reliable** - Builds successfully with minimal warnings

**This is a production-ready foundation for an AI study platform!** 🎉
