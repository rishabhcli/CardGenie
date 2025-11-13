# CardGenie TODO Analysis & Roadmap

**Last Updated:** 2025-11-13
**Status:** Active Development

---

## Recently Completed ✅

### VoiceAssistant Test Suite (COMPLETED)
- **File:** `CardGenieTests/Unit/Intelligence/VoiceAssistantEngineTests.swift`
- **Impact:** 327 → 905 lines (+578 lines, +177%)
- **Coverage:** 60+ comprehensive unit tests
- **Commit:** `0f43a78`
- **Date:** 2025-11-13

### StudyStreakManager Test Suite (COMPLETED)
- **File:** `CardGenieTests/Unit/Data/StudyStreakManagerTests.swift`
- **Impact:** 0 → 446 lines (NEW FILE)
- **Coverage:** 30+ comprehensive unit tests
- **Commit:** `beb748c`
- **Date:** 2025-11-13

### FlashcardExporter Test Suite (COMPLETED)
- **File:** `CardGenieTests/Unit/Data/FlashcardExporterTests.swift`
- **Impact:** 0 → 624 lines (NEW FILE)
- **Coverage:** 35+ comprehensive unit tests (JSON/CSV export, import, round-trip)
- **Commit:** `44b3794`
- **Date:** 2025-11-13

---

## Critical TODOs (High Priority)

### 1. LectureRecorder Test Suite ⭐⭐⭐
**Priority:** HIGH
**Effort:** Large (4-6 hours)
**File:** `CardGenie/Processors/LectureProcessors.swift` (445 lines)

**Why Critical:**
- Complex audio recording and transcription logic
- Real-time processing with multiple delegates
- Integration with Speech framework and AVFoundation
- Error handling for permissions and hardware

**Test Coverage Needed:**
- Recording lifecycle (start/stop/pause)
- Transcript chunk generation
- On-device transcription integration
- Audio file management
- Error handling (no permissions, hardware failure)
- Memory management during long recordings
- Delegate callback ordering
- Rolling summary generation
- Timestamp accuracy

**Estimated Tests:** 40-50 tests

---

### 2. SpacedRepetitionManager Edge Cases ⭐⭐
**Priority:** MEDIUM-HIGH
**Effort:** Medium (2-3 hours)
**File:** `CardGenie/Data/SpacedRepetitionManager.swift` (existing tests: 13445 lines)

**Why Important:**
- Core learning algorithm
- Current tests exist but may miss edge cases
- Critical for retention accuracy

**Additional Test Coverage Needed:**
- Boundary conditions (easeFactor limits)
- Long-term retention (very high intervals)
- Recovery from incorrect responses after mastery
- Concurrent review scheduling
- Edge case: 1000+ consecutive correct answers
- Edge case: Alternating correct/incorrect patterns

**Estimated Tests:** 15-20 additional tests

---

## Medium Priority TODOs

### 3. VectorStore Test Suite ⭐
**Priority:** MEDIUM
**Effort:** Medium (2-3 hours)
**File:** `CardGenie/Data/VectorStore.swift` (216 lines)

**Why Important:**
- Experimental RAG feature
- Embedding generation and similarity search
- Currently marked as experimental

**Test Coverage Needed:**
- Embedding generation
- Similarity search accuracy
- Vector storage and retrieval
- Dimensionality handling
- Edge cases (empty queries, large documents)

**Estimated Tests:** 20-25 tests

---

### 6. MagicEffects Test Suite ⭐
**Priority:** LOW-MEDIUM
**Effort:** Medium (2-3 hours)
**File:** `CardGenie/Design/MagicEffects.swift` (459 lines)

**Why Useful:**
- UI polish and user experience
- Particle effects and animations
- Lower priority than core features

**Test Coverage Needed:**
- Particle system initialization
- Animation timing and curves
- Performance under load
- Memory cleanup after effects
- Particle count limits

**Estimated Tests:** 15-20 tests

---

## Integration Tests (High Value)

### 7. Voice Assistant Integration Tests ⭐⭐⭐
**Priority:** HIGH
**Effort:** Large (4-5 hours)
**Prerequisites:** Requires device with microphone and Apple Intelligence

**Test Coverage Needed:**
- End-to-end conversation flow
- Context injection (study content → AI response)
- Interruption during active speech
- Airplane Mode (100% offline verification)
- Speech recognition with real audio
- TTS streaming verification
- Multi-turn context preservation
- Fallback behavior when AI unavailable

**Estimated Tests:** 10-15 integration tests

---

### 8. Flashcard Study Session Integration Tests ⭐⭐
**Priority:** MEDIUM-HIGH
**Effort:** Medium (3-4 hours)

**Test Coverage Needed:**
- Complete study session flow
- Spaced repetition scheduling after session
- Statistics updates
- Session interruption and resume
- Performance with large decks (1000+ cards)

**Estimated Tests:** 12-15 integration tests

---

### 9. Photo Scanning End-to-End Tests ⭐⭐
**Priority:** MEDIUM
**Effort:** Medium (2-3 hours)

**Test Coverage Needed:**
- Complete scan → extract → generate flow
- OCR accuracy benchmarks
- Handwriting recognition
- PDF processing pipeline
- Error recovery

**Estimated Tests:** 10-12 integration tests

---

## Documentation TODOs

### 10. Architecture Decision Records (ADRs) ⭐
**Priority:** MEDIUM
**Effort:** Small (1-2 hours)

**Create ADRs for:**
- Why MVVM architecture
- Why SwiftData over Core Data
- Spaced repetition algorithm choice (SM-2)
- Offline-first design philosophy
- iOS 26+ minimum version rationale

---

### 11. API Integration Guide ⭐
**Priority:** LOW
**Effort:** Small (1 hour)

**Document:**
- How to replace placeholder Foundation Models code
- Real iOS 26 SDK integration steps
- Testing with Apple Intelligence Beta

---

## Performance Optimization TODOs

### 12. Large Dataset Performance Tests ⭐⭐
**Priority:** MEDIUM
**Effort:** Small (1-2 hours)

**Test Scenarios:**
- 10,000+ flashcards performance
- 1,000+ conversation messages
- Large PDF processing (100+ pages)
- Memory usage profiling

---

### 13. Battery Usage Optimization ⭐
**Priority:** LOW
**Effort:** Medium (2-3 hours)

**Areas to Investigate:**
- Voice assistant power consumption
- Background audio recording efficiency
- Neural Engine usage patterns

---

## Future Feature TODOs

### 14. Collaboration Features ⭐⭐
**Priority:** LOW (Future)
**Effort:** Large (10+ hours)

**Features to Implement:**
- Live lecture collaboration (multiple users)
- Shared flashcard sets
- Study group sessions
- Real-time highlighting sync

---

### 15. Advanced AI Features ⭐
**Priority:** LOW (Future)
**Effort:** Large (8+ hours)

**Features to Consider:**
- Custom AI tutor personalities
- Multi-language support
- Advanced quiz generation
- Concept mapping improvements

---

## Test Coverage Summary

### Current Coverage (Estimated)

| Component | Lines | Test Coverage | Status | Change |
|-----------|-------|---------------|--------|--------|
| VoiceAssistant | 500+ | 90%+ ✅ | Excellent | +90% ⬆️ |
| **StudyStreakManager** | 76 | **95%+ ✅** | **Excellent** | **+95% ⬆️** |
| **FlashcardExporter** | 190 | **90%+ ✅** | **Excellent** | **+90% ⬆️** |
| SpacedRepetition | 100+ | 80%+ ✅ | Good | - |
| Store | 150+ | 70%+ ✅ | Good | - |
| PhotoScanning | 300+ | 60%+ ⚠️ | Fair | - |
| LectureRecorder | 445 | 0% ❌ | None | - |
| VectorStore | 216 | 0% ❌ | None | - |
| MagicEffects | 459 | 0% ❌ | None | - |

**Overall Coverage:** ~60% → **~72%** (Target: 75%+)
**Session Progress:** +12% coverage, 3 components from 0% → 90%+

### Target Coverage Goals
- **Critical Components:** 90%+ coverage
- **Important Components:** 75%+ coverage
- **UI Components:** 50%+ coverage
- **Experimental Features:** 40%+ coverage

---

## Recommended Next Steps

### Immediate (This Week)
1. ✅ **COMPLETE:** VoiceAssistant test suite expansion (905 lines, 60+ tests)
2. ✅ **COMPLETE:** FlashcardExporter test suite (624 lines, 35+ tests)
3. ✅ **COMPLETE:** StudyStreakManager test suite (446 lines, 30+ tests)
4. **NEXT:** LectureRecorder test suite (HIGH priority, LARGE effort)

### Short Term (Next 2 Weeks)
5. Voice Assistant integration tests (HIGH priority, LARGE effort)
6. SpacedRepetitionManager edge cases (MEDIUM-HIGH priority)
7. VectorStore test suite (MEDIUM priority)

### Medium Term (Next Month)
7. VectorStore test suite
8. Flashcard Study Session integration tests
9. Performance optimization tests
10. Architecture Decision Records

### Long Term (3+ Months)
11. Advanced integration test suite
12. Performance profiling and optimization
13. Battery usage optimization
14. Future feature exploration

---

## Effort vs Impact Matrix

```
HIGH IMPACT, LOW EFFORT (Do First!)
┌─────────────────────────────────┐
│ • StudyStreakManager tests      │
│ • FlashcardExporter tests       │
└─────────────────────────────────┘

HIGH IMPACT, HIGH EFFORT (Schedule)
┌─────────────────────────────────┐
│ • LectureRecorder tests         │
│ • Voice integration tests       │
│ • SpacedRepetition edge cases   │
└─────────────────────────────────┘

LOW IMPACT, LOW EFFORT (Nice to Have)
┌─────────────────────────────────┐
│ • ADR documentation             │
│ • API integration guide         │
└─────────────────────────────────┘

LOW IMPACT, HIGH EFFORT (Defer)
┌─────────────────────────────────┐
│ • MagicEffects tests            │
│ • Advanced collaboration        │
│ • Custom AI personalities       │
└─────────────────────────────────┘
```

---

## Success Metrics

### Code Quality
- [ ] Overall test coverage > 75%
- [ ] Critical components > 90% coverage
- [ ] Zero flaky tests
- [ ] All tests run < 60 seconds

### Documentation
- [ ] All major components documented
- [ ] ADRs for key decisions
- [ ] Integration guides complete
- [ ] CLAUDE.md up to date

### Performance
- [ ] App launch < 2 seconds
- [ ] Flashcard review < 100ms latency
- [ ] Voice response < 2 seconds
- [ ] Memory usage < 150MB baseline

---

## Notes

- Tests should be maintainable and readable
- Prioritize behavior testing over implementation testing
- Use Given-When-Then format for clarity
- Mock external dependencies (Speech, AVFoundation)
- Run tests on CI/CD pipeline when available

---

**End of TODO Analysis**
