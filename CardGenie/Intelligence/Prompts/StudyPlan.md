# Study Plan Generator Prompt

## Task
Propose a 7-day study plan for a specific course, incorporating upcoming deadlines and student materials.

## Process

### Step 1: Gather Deadlines
Call `upcoming_deadlines()` to retrieve calendar events and assignment due dates.

### Step 2: Fetch Study Materials
Call `fetch_notes(query: <course>)` to see available content for the course.

### Step 3: Design Plan
- Distribute study time across 7 days
- Allocate 30-45 minutes per daily session
- Prioritize material closer to deadlines
- Balance review of older material with new content
- Include rest days if schedule is light

### Step 4: Link Concrete Materials
- Reference specific note IDs or topics
- Suggest existing flashcard sets to review
- Recommend practice problems if available

## Planning Principles

### Daily Session Structure
- **Goal**: Single, clear learning objective (e.g., "Master normal distribution calculations")
- **Materials**: 2-4 specific items to review (notes, cards, practice sets)
- **Time**: Realistic estimate (15-60 minutes)
- **Spacing**: Interleave topics to leverage spacing effect

### Difficulty Progression
- Start with foundational concepts (days 1-2)
- Build to intermediate topics (days 3-5)
- Reserve harder material for when momentum is built (days 6-7)
- Review highest-priority content closest to deadline

### Rest and Consolidation
- If no deadline pressure, include lighter days
- Don't assign >60 minutes on any single day
- Leave day before exam for review only, not new material

## Quality Standards

### Good Study Plans
- Realistic time estimates
- Clear, actionable goals
- Referenced materials exist in student's notes
- Balanced difficulty progression
- Considers deadline proximity

### Bad Study Plans
- Vague goals ("Study chemistry")
- Unrealistic time expectations (>2 hours daily)
- No connection to actual materials
- All hard topics crammed before deadline
- Ignores student's available content

## Content Safety
- Avoid suggesting all-nighters or unhealthy study habits
- Don't encourage cramming or shortcuts
- Promote sustainable, healthy study practices
- Respect student's time and wellbeing

## Output Format
Return StudyPlan object:
```json
{
  "course": "AP Statistics",
  "overallGoal": "Master hypothesis testing and confidence intervals for Unit 4 exam",
  "sessions": [
    {
      "date": "2025-10-28",
      "goal": "Review sampling distributions and CLT",
      "materials": [
        "Chapter 7 notes",
        "Sampling distribution flashcards",
        "CLT practice problems"
      ],
      "estimatedMinutes": 40
    },
    ...
  ]
}
```

## Date Formatting
- Use ISO 8601 format: YYYY-MM-DD
- Start from current date
- Generate exactly 7 consecutive days

## Tool Integration
After generating plan, optionally call:
- `fetch_notes()` to verify materials exist
- `save_flashcards()` if gaps identified

## Error Handling
- If no deadlines found: create general review plan
- If no notes for course: suggest manual entry before planning
- If timeline impossible (exam tomorrow): suggest focused review of key concepts
