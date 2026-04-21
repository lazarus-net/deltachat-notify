# 0007 — Session Start Briefing Protocol
Date: 2025-11-01
Status: Accepted
Author: vld.lazar@proton.me
Remark: generated/edited with Claude
Copyright: vld.lazar@proton.me
Deciders: vld.lazar@proton.me
Consulted: repository operators
Informed: automation contributors, future agents
Tags: process, documentation, onboarding

## Context
Recent sessions relied on ad-hoc reminders for agents to reread `AGENTS.md` and `CLAUDE.md`. Without a persistent
checklist, an operator can forget to deliver the reminder, leaving the assistant unaware of mandatory guardrails and
style requirements. The repository lacks a central place describing the expected first prompt, so new operators guess
and risk inconsistent onboarding.

## Decision
Publish a dedicated `SESSION_START_REMINDER.md` at the repository root that captures the operator checklist and the
recommended first message. Update `AGENTS.md` with metadata and a session-start section that points to the reminder so
the directive is visible whenever the file is opened.

## Consequences
- Positive: Every session now has an explicit, reusable script for the initial reminder, reducing onboarding drift.
- Negative: Operators incur a small amount of overhead to copy the suggested prompt before doing real work.
- Risks/Trade-offs: Compliance still depends on human operators following the checklist; automation is not enforced.
- Follow-up work: Explore wiring the reminder into project tooling (e.g., CLI banner) to remove the manual step if the
  environment allows.

## Alternatives
- Rely on verbal memory — rejected because it fails when multiple operators rotate through the project.
- Modify the harness to auto-print the reminder — rejected: outside repository scope and may require infrastructure
  changes the team cannot commit.

## References
- `SESSION_START_REMINDER.md`
- `AGENTS.md`
- `CLAUDE.md`
