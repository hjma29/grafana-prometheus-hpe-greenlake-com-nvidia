# Copilot Instructions for Grafana Documentation

## File to be focused
- Only look into whitepaper.md under docs directory


## Content Preservation Rules
- **NEVER modify content inside code blocks** (```, ~~~, or indented code)
- Preserve all commands, configurations, and technical output exactly as captured
- Keep all URLs, file paths, and technical identifiers unchanged
- Do not alter any numerical values, timestamps, or version numbers in code blocks

## Writing Style
- Follow technical white paper standards: clear, professional, and precise
- Use active voice where appropriate
- Write in present tense for current state, past tense for completed actions
- Maintain a formal but accessible tone
- Use industry-standard terminology for Grafana, Prometheus, Kubernetes, and NVIDIA technologies

## Grammar and Formatting
- Fix spelling and grammatical errors in prose (not in code blocks)
- Use proper capitalization for product names: Grafana, Prometheus, Kubernetes, NVIDIA
- Ensure subject-verb agreement and proper punctuation
- Remove redundant phrases and improve sentence clarity

## Document Structure

### Headings
- Use hierarchical heading structure: `#` for title, `##` for major sections, `###` for subsections
- Capitalize headings using title case (capitalize major words)
- Keep headings concise and descriptive
- Add blank line before and after each heading

### Lists and Bullets
- Use `-` for unordered lists (not `*` or `+`)
- Use `1.`, `2.`, `3.` for ordered/sequential lists
- Indent nested lists with 2 spaces
- Maintain consistent indentation throughout
- Add blank line before and after list blocks

### Spacing Consistency
- Use **one blank line** between paragraphs
- Use **one blank line** before and after code blocks
- Use **one blank line** before and after lists
- Use **one blank line** before and after headings
- No multiple consecutive blank lines (collapse to single line)

## Technical Documentation Best Practices
- Begin with a brief overview or introduction
- Use descriptive section headings to guide readers
- Include clear step-by-step instructions where applicable
- Add explanatory context before complex code blocks
- Use tables for structured comparison or configuration data
- Add notes or warnings using blockquotes when appropriate

## Example Structure Template
```
# Document Title

Brief introduction paragraph.

## Section Name

Paragraph explaining the section.

### Subsection

Step-by-step or detailed content.

- Bullet point one
- Bullet point two
  - Nested item with 2-space indent

1. First sequential step
2. Second sequential step

Command or configuration example:
\`\`\`bash
kubectl get pods
\`\`\`

Next paragraph after code block.
```

## What NOT to Change
- Original technical capture in any code block
- Shell commands and their output
- Configuration files (YAML, JSON, TOML)
- Log entries or error messages
- API responses or query results