# 0005 - Feature Flag Naming Convention

Date: 2025-10-31
Status: Accepted
Deciders: vld.lazar@proton.me
Consulted: Feature management analysis
Informed: System administrators, developers
Tags: configuration, features, conventions, standards

## Summary

Established ENABLE_XXX prefix exclusively with explicit 0/1 values for all feature flags. Format:
`export ENABLE_FEATURE_NAME := VALUE` where VALUE is `1` (enabled) or `0` (disabled). No other
prefixes (DISABLE_, FEATURE_), no undefined flags, no tri-state. Defined in
`settings/SERVER_ID/server_settings.mk`. Enables simple `ifeq ($(ENABLE_X),1)` conditionals and
easy discovery via `grep '^export ENABLE_'`.

## Quick Reference

| Item | Value |
|------|-------|
| **Format** | `export ENABLE_FEATURE_NAME := VALUE` |
| **Values** | `1` (enabled) or `0` (disabled) only |
| **Location** | `settings/SERVER_ID/server_settings.mk` |
| **Discovery** | `grep '^export ENABLE_' settings/*/server_settings.mk` |
| **Examples** | See `docs/adr/references/feature-flag-examples.md` |

## Context

MDIST uses feature flags to control component generation. Without consistent naming:
- Ambiguity (ENABLE_X vs DISABLE_X vs FEATURE_X)
- Conflicting flags possible
- Unclear implicit defaults
- Hard to discover available features
- Difficult programmatic listing

**Requirements:** Clear naming, single source of truth, easy discovery, simple boolean logic,
consistent pattern, shell/make friendly.

## Decision

**Use ENABLE_XXX prefix exclusively with explicit 0/1 values.**

### Naming Convention

**Format:** `export ENABLE_FEATURE_NAME := VALUE`

**Rules:**
1. Use ENABLE_ prefix only (never DISABLE_, FEATURE_, etc.)
2. Explicit values required: `1` or `0` (no undefined flags)
3. Uppercase with underscores (SCREAMING_SNAKE_CASE)
4. Boolean only: `1` (enabled) or `0` (disabled)
5. Location: `settings/SERVER_ID/server_settings.mk`

**Good:**
```makefile
export ENABLE_SWAP       := 1
export ENABLE_NGINX      := 0
export ENABLE_MATRIX     := 1
export ENABLE_POSTGRESQL := 0
```

**Bad:**
```makefile
export DISABLE_NGINX := 1              # Wrong: Use ENABLE_NGINX := 0
export FEATURE_MATRIX := true          # Wrong: Use ENABLE_MATRIX := 1
export ENABLE_SWAP                     # Wrong: Must be := 1 or := 0
export ENABLE_REDIS := yes             # Wrong: Use := 1
ENABLE_DOCKER=1                        # Wrong: Must use 'export' and ':='
```

### Implementation

Check flags:
```makefile
ifeq ($(ENABLE_NGINX),1)
	$(MAKE) _generate_feature FEATURE=nginx
endif
```

List all features:
```makefile
ls_enabled_features::
	@grep '^export ENABLE_' $(SERVER_SETTINGS_FN)
```

Full examples: `docs/adr/references/feature-flag-examples.md`

## Consequences

**Positive:** No ambiguity (single pattern), explicit intent (every state documented), simple logic
(boolean comparisons), easy discovery (`grep '^export ENABLE_'`), self-documenting (shows all
features), consistent, tool-friendly (easy to parse), no conflicts.

**Negative:** Verbosity (must list every feature explicitly), maintenance (update settings when
adding features), no defaults (can't rely on "undefined = disabled").

**Risks:** Forgotten flags when adding features (mitigation: documentation, code review),
inconsistent values like `2`, `true`, `yes` (mitigation: validation), copy-paste errors
(mitigation: consider shared defaults file).

### Follow-up Work

- [ ] Add validation rule to check all ENABLE_* flags are 0 or 1
- [ ] Consider creating `settings/common.mk` with default flags
- [ ] Document feature flag creation process
- [ ] Add lint/validation script
- [ ] Update CLAUDE.md with feature flag guidelines

## Alternatives

### A: ENABLE_XXX and DISABLE_XXX
- **Pro:** Semantic clarity for disabled features
- **Con:** Confusing precedence, potential conflicts
- **Rejected:** Too complex, ambiguous

### B: Undefined = Disabled (Implicit)
Only define enabled features, undefined means disabled.
- **Pro:** Minimal configuration
- **Con:** Hard to discover, unclear defaults
- **Rejected:** Not self-documenting

### C: Tri-state (ENABLE/DISABLE/AUTO)
- **Pro:** More expressive
- **Con:** Complex string comparisons, overkill for boolean
- **Rejected:** Unnecessary complexity

### D: Single FEATURES variable
`export FEATURES := swap nginx matrix`
- **Pro:** Very compact
- **Con:** No disabled state visible, harder to parse
- **Rejected:** Not self-documenting, loses disabled features

## References

- **Examples:** `docs/adr/references/feature-flag-examples.md`
- Feature flags best practices: Martin Fowler's "Feature Toggles"
- Autoconf naming: https://www.gnu.org/software/autoconf/
- ADR #0004: Feature-based conditional script generation
