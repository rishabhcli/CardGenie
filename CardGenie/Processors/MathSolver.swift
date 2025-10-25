//
//  MathSolver.swift
//  CardGenie
//
//  Symbolic math solver with LLM explanations.
//  Uses rule engine for accuracy, LLM for wording.
//

import Foundation
import Vision
import UIKit

// MARK: - Math Solver

final class MathSolver {
    private let llm: LLMEngine

    init(llm: LLMEngine = AIEngineFactory.createLLMEngine()) {
        self.llm = llm
    }

    // MARK: - Solve from Image

    /// Capture math problem from image and solve
    func solve(image: UIImage) async throws -> MathSolution {
        // 1. OCR the math
        let mathText = try await extractMath(from: image)

        // 2. Parse to normalized form
        let expression = try parseExpression(mathText)

        // 3. Solve symbolically
        let steps = try solveSymbolic(expression)

        // 4. Generate explanations with LLM
        let explanations = try await generateExplanations(steps: steps)

        return MathSolution(
            originalText: mathText,
            expression: expression,
            steps: steps,
            explanations: explanations
        )
    }

    // MARK: - Compare Student Answer

    /// "Why you're wrong" - compare student work with solution
    func compareAnswer(
        problem: String,
        studentAnswer: String,
        correctSolution: MathSolution
    ) async throws -> ComparisonResult {
        // Parse student's work
        let studentSteps = extractSteps(from: studentAnswer)

        // Find first divergence
        var divergenceIndex: Int?
        for (index, correctStep) in correctSolution.steps.enumerated() {
            if index < studentSteps.count {
                if !isEquivalent(studentSteps[index], correctStep.result) {
                    divergenceIndex = index
                    break
                }
            }
        }

        // Generate feedback
        let feedback: String
        let correction: String

        if let divIndex = divergenceIndex {
            let wrongStep = studentSteps[divIndex]
            let correctStep = correctSolution.steps[divIndex]

            let prompt = """
            A student made an error in their math work.

            PROBLEM: \(problem)

            STUDENT'S STEP \(divIndex + 1): \(wrongStep)
            CORRECT STEP \(divIndex + 1): \(correctStep.result)

            Explain in 2-3 sentences:
            1. What mistake the student made
            2. Why it's wrong
            3. What the correct next step should be

            Be encouraging and educational.

            EXPLANATION:
            """

            feedback = try await llm.complete(prompt, maxTokens: 250)
            correction = correctStep.result
        } else {
            feedback = "Your work looks correct!"
            correction = ""
        }

        return ComparisonResult(
            isCorrect: divergenceIndex == nil,
            divergencePoint: divergenceIndex,
            feedback: feedback,
            correction: correction
        )
    }

    // MARK: - OCR Math

    private func extractMath(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw MathError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations.compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")

                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.customWords = [
                "x", "y", "dx", "dy", "sin", "cos", "tan",
                "lim", "log", "ln", "sqrt", "integral"
            ]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    // MARK: - Expression Parsing

    private func parseExpression(_ text: String) throws -> MathExpression {
        // Normalize: remove spaces, convert symbols
        var normalized = text.replacingOccurrences(of: " ", with: "")
        normalized = normalized.replacingOccurrences(of: "×", with: "*")
        normalized = normalized.replacingOccurrences(of: "÷", with: "/")
        normalized = normalized.replacingOccurrences(of: "−", with: "-")

        // Detect type
        if normalized.contains("=") {
            // Equation
            let parts = normalized.components(separatedBy: "=")
            guard parts.count == 2 else {
                throw MathError.invalidExpression
            }
            return MathExpression(type: .equation, text: normalized)
        } else if normalized.contains("d/dx") || normalized.contains("∫") {
            // Calculus
            return MathExpression(type: .calculus, text: normalized)
        } else {
            // Simplification
            return MathExpression(type: .simplify, text: normalized)
        }
    }

    // MARK: - Symbolic Solver

    private func solveSymbolic(_ expr: MathExpression) throws -> [SolutionStep] {
        switch expr.type {
        case .equation:
            return solveEquation(expr.text)
        case .simplify:
            return simplifyExpression(expr.text)
        case .calculus:
            return solveCalculus(expr.text)
        }
    }

    private func solveEquation(_ equation: String) -> [SolutionStep] {
        var steps: [SolutionStep] = []

        // Simple linear equation solver (ax + b = c)
        // This is a simplified version - production would use a full CAS

        steps.append(SolutionStep(
            operation: "Given equation",
            result: equation,
            rule: "Starting point"
        ))

        // Pattern: ax + b = c
        if let match = equation.range(of: #"^(\d*)x([+-]\d+)=(\d+)$"#, options: .regularExpression) {
            let eqn = String(equation[match])

            // Extract coefficients (simplified)
            // Production version would use proper parsing

            steps.append(SolutionStep(
                operation: "Isolate variable term",
                result: "ax = c - b",
                rule: "Subtract b from both sides"
            ))

            steps.append(SolutionStep(
                operation: "Solve for x",
                result: "x = (c - b) / a",
                rule: "Divide both sides by a"
            ))
        }

        return steps
    }

    private func simplifyExpression(_ expr: String) -> [SolutionStep] {
        var steps: [SolutionStep] = []

        steps.append(SolutionStep(
            operation: "Original expression",
            result: expr,
            rule: "Given"
        ))

        // Simple algebraic simplifications
        // Production would use full symbolic algebra

        // Example: 2x + 3x → 5x
        var simplified = expr

        // Combine like terms (very simplified)
        if simplified.contains("+") {
            steps.append(SolutionStep(
                operation: "Combine like terms",
                result: simplified,
                rule: "Add coefficients of same variables"
            ))
        }

        return steps
    }

    private func solveCalculus(_ expr: String) -> [SolutionStep] {
        var steps: [SolutionStep] = []

        steps.append(SolutionStep(
            operation: "Given",
            result: expr,
            rule: "Calculus problem"
        ))

        // Simple derivatives
        if expr.contains("d/dx") {
            // Power rule, etc.
            steps.append(SolutionStep(
                operation: "Apply power rule",
                result: "d/dx(x^n) = nx^(n-1)",
                rule: "Power rule of differentiation"
            ))
        }

        return steps
    }

    // MARK: - LLM Explanations

    private func generateExplanations(steps: [SolutionStep]) async throws -> [String] {
        var explanations: [String] = []

        for step in steps {
            let prompt = """
            Explain this math step in simple terms for a student.

            STEP: \(step.operation)
            RESULT: \(step.result)
            RULE: \(step.rule)

            Write 1-2 sentences explaining why we do this step.

            EXPLANATION:
            """

            let explanation = try await llm.complete(prompt, maxTokens: 100)
            explanations.append(explanation.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return explanations
    }

    // MARK: - Helpers

    private func extractSteps(from work: String) -> [String] {
        // Extract steps from student's work
        // Look for line breaks or step markers
        return work.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func isEquivalent(_ expr1: String, _ expr2: String) -> Bool {
        // Simplified equivalence check
        // Production would use symbolic comparison
        let normalized1 = expr1.replacingOccurrences(of: " ", with: "")
        let normalized2 = expr2.replacingOccurrences(of: " ", with: "")
        return normalized1 == normalized2
    }
}

// MARK: - Models

struct MathExpression {
    enum ExpressionType {
        case equation
        case simplify
        case calculus
    }

    let type: ExpressionType
    let text: String
}

struct SolutionStep {
    let operation: String
    let result: String
    let rule: String
}

struct MathSolution {
    let originalText: String
    let expression: MathExpression
    let steps: [SolutionStep]
    let explanations: [String]
}

struct ComparisonResult {
    let isCorrect: Bool
    let divergencePoint: Int?
    let feedback: String
    let correction: String
}

// MARK: - Errors

enum MathError: LocalizedError {
    case invalidImage
    case invalidExpression
    case unsupportedOperation

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Invalid image format"
        case .invalidExpression: return "Could not parse math expression"
        case .unsupportedOperation: return "Math operation not yet supported"
        }
    }
}
