# 0004 - Feature-Based Conditional Script Generation

Date: 2025-10-31
Status: Accepted
Deciders: vld.lazar@proton.me
Consulted: Server configuration requirements analysis
Informed: System administrators, developers
Tags: automation, features, templates, makefile, organization

## Summary

Implemented feature-based template organization with Makefile conditional generation. Templates
organized as `templates/FEATURE/STAGE/` with foundation/ always generated and optional features
(nginx/, matrix/, monitoring/) generated based on ENABLE_X flags. Makefile uses `ifeq` conditionals
to generate only enabled features. Output contains only scripts for enabled features, avoiding
clutter and accidental execution of disabled features.

## Quick Reference

| Item | Value |
|------|-------|
| **Structure** | `templates/FEATURE/STAGE/` (e.g., `templates/nginx/e060-nginx/`) |
| **Foundation** | `templates/foundation/` - always generated |
| **Flags** | `export ENABLE_FEATURE := 1` in `server_settings.mk` |
| **Generation** | `make generate_all_scripts` uses `ifeq` conditionals |
| **Examples** | See `docs/adr/references/feature-generation-examples.md` |

## Context

MDIST generates scripts from templates. Different servers need different software. Without
conditional generation:
- Unnecessary scripts clutter output directory
- Operators must manually skip disabled features
- Risk of accidentally executing disabled features
- No clear feature organization

**Requirements:** Generate only enabled features, clear organization, simple conditionals, easy to
add features, self-documenting.

## Decision

**Feature-based template organization with Makefile conditional generation.**

### Template Organization

```
templates/
├── foundation/          # Always generated (core system)
│   ├── a001-system-init/
│   ├── a010-swap/
│   └── b020-network/
├── nginx/               # Generated if ENABLE_NGINX=1
│   └── e060-nginx/
├── matrix/              # Generated if ENABLE_MATRIX=1
│   └── f070-matrix/
└── monitoring/          # Generated if ENABLE_MONITORING=1
    └── z990-monitoring/
```

**Principles:** Feature = top-level dir under `templates/`, stages inside (XNNN-name/), foundation
always generated, feature name lowercase, one feature per directory.

### Makefile Integration

```makefile
generate_all_scripts:: check_settings
	mkdir -p $(OUT_PATH)
	$(MAKE) _generate_feature FEATURE=foundation  # Always

ifeq ($(ENABLE_NGINX),1)
	$(MAKE) _generate_feature FEATURE=nginx
endif

ifeq ($(ENABLE_MATRIX),1)
	$(MAKE) _generate_feature FEATURE=matrix
endif

_generate_feature:
	@for stage_dir in $(TEMPLATES)/$(FEATURE)/*/; do \
		# Copy and expand templates to $(OUT_PATH)/$$stage_name/
	done
```

### Feature Flags

In `server_settings.mk`:
```makefile
export ENABLE_SWAP      := 1
export ENABLE_NGINX     := 0
export ENABLE_MATRIX    := 1
export ENABLE_MONITORING := 1
```

**Workflow:** Run `make settings=SERVER_ID generate_all_scripts` -> sources `server_settings.mk` ->
foundation always generated -> check feature flags (`ifeq`) -> process enabled features via
`_generate_feature` -> expand to `out/SERVER_ID/STAGE/` -> make executable.

Full examples: `docs/adr/references/feature-generation-examples.md`

## Consequences

**Positive:** Clean output (only enabled features), clear organization (feature=directory), simple
conditionals (straightforward `ifeq`), easy feature addition (new dir + new conditional),
self-documenting structure, reduced errors (disabled features can't execute), native Make (no
external dependencies), reusable `_generate_feature` target.

**Negative:** Makefile verbosity (one `ifeq` per feature), extra directory depth
(`templates/FEATURE/STAGE/`), refactoring cost when moving templates, requires discipline.

**Risks:** Feature definition ambiguity (use best judgment), circular dependencies (enforce via
staging), foundation bloat (keep minimal).

### Follow-up Work

- [ ] Implement `_generate_feature` target in main Makefile
- [ ] Reorganize existing templates into feature directories
- [ ] Create foundation/ directory with core templates
- [ ] Update swap template path to foundation/a010-swap/
- [ ] Add `list_features` target to show available/enabled features
- [ ] Document feature creation guidelines
- [ ] Add validation to check feature flags are defined

## Alternatives

### A: Shell script generator with sourced settings
- **Pro:** More flexible scripting
- **Con:** Another script to maintain, must parse Make syntax
- **Rejected:** Adds complexity, breaks Makefile-centric workflow

### B: Template metadata with feature tags
Add `# MDIST_REQUIRES: ENABLE_NGINX=1` in template files
- **Pro:** Self-documenting templates
- **Con:** Complex parser needed, metadata duplication
- **Rejected:** Over-engineered

### C: JSON/YAML manifest
- **Pro:** Declarative, easy to edit
- **Con:** External dependencies (yq/jq), another file format
- **Rejected:** Adds dependencies, not Makefile-native

## References

- **Examples:** `docs/adr/references/feature-generation-examples.md`
- GNU Make conditionals: https://www.gnu.org/software/make/manual/html_node/Conditional-Syntax.html
- ADR #0003: Output folder staging structure
- ADR #0002: Swap file configuration template (first feature template)
- CDIST type organization: https://www.cluenet.de/~nico/cdist/man/latest/cdist-type.html
