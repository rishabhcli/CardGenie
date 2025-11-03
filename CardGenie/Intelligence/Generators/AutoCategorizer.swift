//
//  AutoCategorizer.swift
//  CardGenie
//
//  Automatically categorizes study content using Apple Intelligence.
//

import Foundation
import FoundationModels
import Combine

/// Automatic content categorization using AI
final class AutoCategorizer: ObservableObject {
    private let fmClient = FMClient()

    // MARK: - Predefined Categories

    static let commonCategories = [
        "Science", "Math", "History", "Language", "Literature",
        "Computer Science", "Business", "Medicine", "Engineering",
        "Art", "Music", "Philosophy", "Psychology", "General"
    ]

    // MARK: - Auto-Categorize

    /// Automatically categorize content based on its text
    func categorize(_ content: StudyContent) async throws -> String {
        // Check AI availability
        guard fmClient.capability() == .available else {
            return fallbackCategory(for: content)
        }

        // Use existing tags as hint if available
        let hint = content.tags.isEmpty ? "" : "Existing tags: \(content.tags.joined(separator: ", "))"

        let prompt = """
        Analyze the following study content and categorize it into ONE of these categories:
        \(Self.commonCategories.joined(separator: ", "))

        Content:
        \(content.displayText.prefix(500))

        \(hint)

        Respond with ONLY the category name, nothing else.
        """

        do {
            let category = try await fmClient.customPrompt(prompt)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Validate against common categories
            if Self.commonCategories.contains(where: { $0.localizedCaseInsensitiveCompare(category) == .orderedSame }) {
                return category
            }

            return fallbackCategory(for: content)

        } catch {
            return fallbackCategory(for: content)
        }
    }

    /// Batch categorize multiple content items
    func categorizeBatch(_ contents: [StudyContent]) async -> [UUID: String] {
        var results: [UUID: String] = [:]

        for content in contents {
            if let category = try? await categorize(content) {
                results[content.id] = category
            }
        }

        return results
    }

    // MARK: - Smart Suggestions

    /// Suggest category based on tags and existing patterns
    func suggestCategory(for content: StudyContent, basedOn allContent: [StudyContent]) -> String? {
        // If content has tags, find similar content
        guard !content.tags.isEmpty else { return nil }

        let contentTagSet = Set(content.tags)

        // Find content with similar tags
        let similar = allContent.filter { other in
            !other.tags.isEmpty &&
            !contentTagSet.intersection(other.tags).isEmpty &&
            other.topic != nil
        }

        // Get most common category among similar content
        let categories = similar.compactMap { $0.topic }
        let grouped = Dictionary(grouping: categories, by: { $0 })
        let mostCommon = grouped.max(by: { $0.value.count < $1.value.count })

        return mostCommon?.key
    }

    // MARK: - Fallback

    /// Simple keyword-based fallback categorization
    private func fallbackCategory(for content: StudyContent) -> String {
        let text = content.displayText.lowercased()

        // Keyword patterns for common categories
        let patterns: [(String, [String])] = [
            ("Science", ["science", "biology", "chemistry", "physics", "experiment", "theory", "hypothesis"]),
            ("Math", ["math", "equation", "calculate", "algebra", "geometry", "theorem", "proof"]),
            ("History", ["history", "war", "century", "ancient", "civilization", "revolution", "empire"]),
            ("Language", ["language", "grammar", "vocabulary", "verb", "noun", "sentence", "pronunciation"]),
            ("Literature", ["literature", "novel", "poem", "author", "character", "plot", "story"]),
            ("Computer Science", ["code", "programming", "algorithm", "computer", "software", "function", "data"]),
            ("Business", ["business", "marketing", "finance", "management", "strategy", "customer", "revenue"]),
            ("Medicine", ["medical", "health", "disease", "treatment", "patient", "diagnosis", "symptom"]),
            ("Engineering", ["engineering", "design", "circuit", "mechanical", "structure", "system", "build"]),
            ("Art", ["art", "painting", "sculpture", "artist", "canvas", "museum", "exhibition"]),
            ("Music", ["music", "song", "instrument", "melody", "rhythm", "composer", "harmony"]),
            ("Philosophy", ["philosophy", "ethics", "logic", "existence", "knowledge", "moral", "truth"]),
            ("Psychology", ["psychology", "behavior", "mind", "emotion", "cognitive", "therapy", "mental"])
        ]

        // Check tags first
        if !content.tags.isEmpty {
            for (category, keywords) in patterns {
                if content.tags.contains(where: { tag in
                    keywords.contains(where: { tag.localizedCaseInsensitiveContains($0) })
                }) {
                    return category
                }
            }
        }

        // Check content text
        for (category, keywords) in patterns {
            let matches = keywords.filter { text.contains($0) }.count
            if matches >= 2 {
                return category
            }
        }

        return "General"
    }
}

// MARK: - FMClient Extension

extension FMClient {
    /// Custom prompt execution
    func customPrompt(_ prompt: String) async throws -> String {
        // Use the reflection method as a proxy for custom prompts
        return try await reflection(for: prompt)
    }
}
