# Session Start Reminder

Use this at the beginning of each new Claude session to ensure consistency.

## Quick Start Prompt

```
Read and follow project guidelines:
- CLAUDE.md: Project structure and conventions
- docs/claude/adr-guidelines.md: ADR creation rules
- docs/claude/PROJECT_NOTES.md: Current work status and session continuity

Key reminders:
- Shell scripts: Use POSIX sh (not bash). Validate: ./scripts/validate_posix.sh
- ADRs: <150 lines, include Summary + Quick Reference + Key Changes
- Code style: Limit 120 chars/line, concrete paths, commands in backticks
```

## What to Say at Session Start

**Option 1 (Minimal):**
```
Read CLAUDE.md and docs/claude/adr-guidelines.md. Follow project conventions.
```

**Option 2 (Detailed):**
```
New session setup:
1. Read: CLAUDE.md (project structure)
2. Read: docs/claude/adr-guidelines.md (ADR rules)
3. Remember: Use sh not bash, ADRs <150 lines, include Summary section
4. Check: docs/adr/0000-index.md for existing decisions
```

**Option 3 (When working on specific feature):**
```
Working on [feature name]:
- Read: CLAUDE.md, docs/claude/adr-guidelines.md
- Context: docs/adr/0000-index.md
- Related ADRs: #NNNN, #NNNN
```

## Why This Matters

Claude's context doesn't persist between sessions. Each new session needs:

1. **Project structure** - where files live, naming conventions
2. **Standards** - sh not bash, ADR format, code style
3. **Existing decisions** - check ADR index to avoid duplicates
4. **Token efficiency** - frontload info, use tables, concrete examples

## Verification Checklist

After starting session, verify Claude understands:

- [ ] Shell scripts use `#!/bin/sh` not `#!/bin/bash`
- [ ] ADRs include Summary (TL;DR) section
- [ ] ADRs kept under 150 lines
- [ ] Quick Reference section for implementation ADRs
- [ ] File paths are concrete: `templates/nginx/a00-install.sh`
- [ ] Commands shown in backticks: `make check`

## Auto-Reminder Options

### Option A: Add to ~/.zshrc or ~/.bashrc
```bash
function mdist() {
    cd /path/to/mdist
    cat docs/claude/SESSION_START_REMINDER.md
}
```

### Option B: Git alias
```bash
git config alias.claude-start '!cat docs/claude/SESSION_START_REMINDER.md'
# Usage: git claude-start
```

### Option C: Makefile target
```makefile
## Show session start reminder for Claude
claude_start::
	@cat docs/claude/SESSION_START_REMINDER.md
```

### Option D: Pre-commit reminder
Add to `.git/hooks/pre-commit`:
```bash
echo "Remember: New Claude session? Run 'make claude_start'"
```

## Common Mistakes Without Reminder

1. Using `#!/bin/bash` instead of `#!/bin/sh`
2. Creating ADRs >250 lines without Summary section
3. Using bash features: `[[`, `echo -e`, arrays
4. Verbose prose instead of tables
5. Not checking existing ADRs before creating new one
6. Abstract descriptions: "the nginx script" vs `templates/nginx/a00-install.sh`

## Integration with Claude Code

If using Claude Code (desktop app), create a project note or snippet with:

```
Project: MDIST
Setup: Read CLAUDE.md + docs/claude/adr-guidelines.md
Standards: POSIX sh, ADRs <150 lines, Summary required
Validate: ./scripts/validate_posix.sh
Index: docs/adr/0000-index.md
```

---

**Last Updated:** 2025-11-05
**Related:** CLAUDE.md, docs/claude/adr-guidelines.md
