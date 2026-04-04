<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk> -->
# TOPOLOGY.md — k9-pre-commit

## Purpose

Pre-commit hook for validating `.k9` and `.k9.ncl` contractile files before commit. Enforces the K9! magic number, required field presence, and security-tier constraints. Integrates with the standard pre-commit framework.

## Module Map

```
k9-pre-commit/
├── hooks/
│   └── validate-k9.sh    # Main validation script
├── examples/             # Example .k9 files (pass/fail)
├── docs/                 # Usage documentation
└── .pre-commit-hooks.yaml
```

## Data Flow

```
[git commit] ──► [pre-commit framework] ──► [validate-k9.sh] ──► [pass/fail]
                                                   │
                                         [.k9 / .k9.ncl files in repo]
```
