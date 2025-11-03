//
//  StudyPlanView.swift
//  CardGenie
//
//  AI-generated study plans for optimal learning.
//

import SwiftUI
import SwiftData

// MARK: - Study Plan View

struct StudyPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var studyPlans: [StudyPlan]

    @State private var showCreatePlan = false

    var body: some View {
        NavigationStack {
            Group {
                if studyPlans.isEmpty {
                    EmptyPlansView {
                        showCreatePlan = true
                    }
                } else {
                    PlansList(plans: studyPlans)
                }
            }
            .navigationTitle("Study Plans")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreatePlan = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showCreatePlan) {
                CreateStudyPlanView()
            }
        }
    }
}

// MARK: - Empty State

struct EmptyPlansView: View {
    let onCreate: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No Study Plans", systemImage: "calendar")
        } description: {
            Text("Create an AI-powered study plan for your upcoming exams")
        } actions: {
            Button("Create Plan") {
                onCreate()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Plans List

struct PlansList: View {
    let plans: [StudyPlan]

    var body: some View {
        List {
            ForEach(plans.filter { $0.isActive }, id: \.id) { plan in
                NavigationLink(destination: PlanDetailView(plan: plan)) {
                    PlanRowView(plan: plan)
                }
            }

            if !plans.filter({ !$0.isActive }).isEmpty {
                Section("Completed") {
                    ForEach(plans.filter { !$0.isActive }, id: \.id) { plan in
                        NavigationLink(destination: PlanDetailView(plan: plan)) {
                            PlanRowView(plan: plan)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Plan Row

struct PlanRowView: View {
    let plan: StudyPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(plan.title)
                    .font(.headline)

                Spacer()

                if daysUntilExam > 0 {
                    Text("\(daysUntilExam)d")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            // Mastery progress
            HStack(spacing: 8) {
                ProgressView(value: plan.currentMastery / 100.0)
                    .tint(masteryColor)

                Text("\(Int(plan.currentMastery))%")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            // Upcoming session
            if let nextSession = plan.sessions.filter({ !$0.isCompleted }).first {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text(nextSession.scheduledTime, format: .relative(presentation: .named))
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
    }

    private var daysUntilExam: Int {
        Calendar.current.dateComponents(
            [.day],
            from: Date(),
            to: plan.targetDate
        ).day ?? 0
    }

    private var masteryColor: Color {
        if plan.currentMastery >= plan.targetMastery {
            return .green
        } else if plan.currentMastery >= plan.targetMastery * 0.7 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Plan Detail View

struct PlanDetailView: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var plan: StudyPlan

    @State private var showRecalculate = false
    @State private var isRecalculating = false

    var body: some View {
        List {
            // Stats Section
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Current Mastery")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(plan.currentMastery))%")
                            .font(.title2.weight(.bold))
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("Target")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(plan.targetMastery))%")
                            .font(.title2.weight(.bold))
                    }
                }

                HStack {
                    Image(systemName: "calendar")
                    Text("Exam: \(plan.targetDate, format: .dateTime.month().day())")
                }

                HStack {
                    Image(systemName: "checkmark.circle")
                    Text("\(completedSessions)/\(plan.sessions.count) sessions completed")
                }
            }

            // Sessions
            Section("Study Sessions") {
                ForEach(plan.sessions.sorted(by: { $0.scheduledTime < $1.scheduledTime }), id: \.id) { session in
                    StudySessionRow(session: session)
                }
            }

            // Actions
            Section {
                Button {
                    recalculatePlan()
                } label: {
                    Label("Recalculate Plan", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(isRecalculating)

                Button(role: .destructive) {
                    plan.isActive = false
                } label: {
                    Label("Mark as Complete", systemImage: "checkmark")
                }
            }
        }
        .navigationTitle(plan.title)
        .overlay {
            if isRecalculating {
                ProgressView("Recalculating...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            }
        }
    }

    private var completedSessions: Int {
        plan.sessions.filter { $0.isCompleted }.count
    }

    private func recalculatePlan() {
        isRecalculating = true

        Task {
            let scheduler = SmartScheduler(modelContext: modelContext)
            try? await scheduler.recalculatePlan(plan)

            await MainActor.run {
                isRecalculating = false
            }
        }
    }
}

// MARK: - Study Session Row

struct StudySessionRow: View {
    @Bindable var session: StudySession

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time
            VStack(alignment: .leading, spacing: 2) {
                Text(session.scheduledTime, format: .dateTime.month().day())
                    .font(.caption.weight(.medium))
                Text(session.scheduledTime, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 60, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.topic)
                    .font(.subheadline.weight(.medium))

                HStack(spacing: 8) {
                    Label("\(session.durationMinutes)m", systemImage: "clock")

                    Text(session.sessionType.rawValue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if session.isCompleted {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("\(session.cardsReviewed) cards")
                    }
                    .font(.caption)
                    .foregroundStyle(.green)
                }
            }

            Spacer()

            if !session.isCompleted {
                Button {
                    session.isCompleted = true
                    session.completedAt = Date()
                } label: {
                    Image(systemName: "checkmark.circle")
                }
                .buttonStyle(.borderless)
            }
        }
        .opacity(session.isCompleted ? 0.6 : 1.0)
    }
}

// MARK: - Create Study Plan View

struct CreateStudyPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var flashcardSets: [FlashcardSet]

    @State private var title = ""
    @State private var examDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
    @State private var selectedSets: Set<UUID> = []
    @State private var targetMastery = 85.0
    @State private var isGenerating = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan Details") {
                    TextField("Title (e.g., Physics Exam)", text: $title)

                    DatePicker("Exam Date", selection: $examDate, in: Date()..., displayedComponents: .date)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Target Mastery: \(Int(targetMastery))%")
                            .font(.subheadline)
                        Slider(value: $targetMastery, in: 50...100, step: 5)
                    }
                }

                Section("Flashcard Sets") {
                    ForEach(flashcardSets, id: \.id) { set in
                        Toggle(isOn: Binding(
                            get: { selectedSets.contains(set.id) },
                            set: { isSelected in
                                if isSelected {
                                    selectedSets.insert(set.id)
                                } else {
                                    selectedSets.remove(set.id)
                                }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(set.topicLabel)
                                    .font(.subheadline)
                                Text("\(set.cardCount) cards")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Create Study Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Generate") {
                        generatePlan()
                    }
                    .disabled(title.isEmpty || selectedSets.isEmpty || isGenerating)
                }
            }
            .overlay {
                if isGenerating {
                    ProgressView("Generating optimal study plan...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
            }
        }
    }

    private func generatePlan() {
        isGenerating = true

        Task {
            let scheduler = SmartScheduler(modelContext: modelContext)

            do {
                _ = try await scheduler.generateStudyPlan(
                    title: title,
                    examDate: examDate,
                    flashcardSetIDs: Array(selectedSets),
                    targetMastery: targetMastery
                )

                await MainActor.run {
                    isGenerating = false
                    dismiss()
                }
            } catch {
                print("Failed to generate plan: \(error)")
                await MainActor.run {
                    isGenerating = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    StudyPlanView()
        .modelContainer(for: [StudyPlan.self, StudySession.self])
}
