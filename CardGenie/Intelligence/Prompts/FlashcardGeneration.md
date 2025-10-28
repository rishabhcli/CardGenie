# Flashcard Generation Prompt

## Task
Generate exactly 8 high-quality flashcards from the provided note.

## Constraints
- Use Flashcard schema with proper @Guide constraints
- Front text: maximum 140 characters
- Back text: maximum 220 characters
- Tags: 2-4 relevant tags per card
- Difficulty: 1 (easiest) to 5 (hardest)
- No duplicates across the set
- No trivial facts (dates alone, simple definitions from text)
- Prefer concepts students commonly confuse or need to memorize

## Quality Standards

### Good Flashcards
- Test understanding, not just recall
- Use clear, unambiguous language
- Focus on a single concept per card
- Include context when needed
- Appropriate difficulty distribution (mix of 1-5)

### Bad Flashcards
- Overly broad questions ("What is biology?")
- Multiple concepts in one card
- Vague or ambiguous answers
- Exact quotes from text without context
- All cards at same difficulty level

## Content Safety
- No unsafe or sensitive content
- Keep wording age-appropriate
- Skip controversial topics unless core to curriculum
- Avoid personal information from notes

## Output Format
Return array of Flashcard objects with:
- `front`: String (question or cloze with _____)
- `back`: String (answer)
- `tags`: [String] (2-4 tags)
- `difficulty`: Int (1-5)

## Example Input
```
AP Statistics Chapter 3: Measures of Center
The mean is the arithmetic average. Add all values and divide by n.
The median is the middle value when data is ordered. For even n, average the two middle values.
Mode is the most frequent value. A distribution can be unimodal, bimodal, or multimodal.
Mean is sensitive to outliers; median is resistant.
```

## Example Output
```json
[
  {
    "front": "What happens to the mean when outliers are present?",
    "back": "The mean is sensitive to outliers and will be pulled in their direction",
    "tags": ["statistics", "mean", "outliers"],
    "difficulty": 3
  },
  {
    "front": "The _____ is resistant to outliers, unlike the mean.",
    "back": "median",
    "tags": ["statistics", "median", "outliers"],
    "difficulty": 2
  }
]
```
