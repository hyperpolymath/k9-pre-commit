#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# hooks/validate-k9.sh — Pre-commit hook for K9 configuration validation
#
# Called by the pre-commit framework with staged .k9 / .k9.ncl files as
# arguments. Validates each file for:
#   1. K9! magic number on first non-empty line
#   2. Pedigree block with name and version fields
#   3. Valid security level (kennel / yard / hunt)
#   4. Hunt-level files must have signature or signature_required field
#   5. SPDX-License-Identifier header
#
# Exit codes:
#   0 — All files valid
#   1 — Validation errors found

set -euo pipefail

ERRORS=0
WARNINGS=0
FILES_CHECKED=0

VALID_LEVELS="kennel yard hunt"

# ---------------------------------------------------------------------------
# Helper: normalise a security level string
# ---------------------------------------------------------------------------
normalise_level() {
    local raw="$1"
    raw="${raw#*=}"
    raw="${raw//\"/}"
    raw="${raw//\'/}"
    raw="${raw//,/}"
    raw="${raw## }"
    raw="${raw%% }"
    raw="${raw%%#*}"
    raw="${raw## }"
    raw="${raw%% }"
    echo "${raw,,}"
}

# ---------------------------------------------------------------------------
# Validate a single K9 file
# ---------------------------------------------------------------------------
validate_file() {
    local file="$1"
    local file_errors=0
    FILES_CHECKED=$((FILES_CHECKED + 1))

    # --- K9! magic number ---
    local first_content_line=""
    local line_num=0
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        [[ -z "${line// /}" ]] && continue
        first_content_line="$line"
        break
    done < "$file"

    if [[ "$first_content_line" != "K9!" ]]; then
        echo "  ERROR: ${file}: Missing K9! magic number on first non-empty line"
        file_errors=$((file_errors + 1))
    fi

    # --- SPDX header ---
    local has_spdx=false
    line_num=0
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        [[ $line_num -gt 10 ]] && break
        if [[ "$line" == *"SPDX-License-Identifier"* ]]; then
            has_spdx=true
            break
        fi
    done < "$file"

    if [[ "$has_spdx" == "false" ]]; then
        echo "  WARNING: ${file}: Missing SPDX-License-Identifier in first 10 lines"
        WARNINGS=$((WARNINGS + 1))
    fi

    # --- Pedigree block analysis ---
    local has_pedigree=false
    local has_name=false
    local has_version=false
    local has_security_level=false
    local security_level_value=""
    local has_signature_field=false
    local in_pedigree=false
    local pedigree_depth=0

    while IFS= read -r line; do
        # Detect pedigree start
        if [[ "$line" =~ ^[[:space:]]*pedigree[[:space:]]*= ]]; then
            has_pedigree=true
            in_pedigree=true
            pedigree_depth=0
            continue
        fi

        if [[ "$in_pedigree" == "true" ]]; then
            local opens="${line//[^\{]/}"
            local closes="${line//[^\}]/}"
            pedigree_depth=$(( pedigree_depth + ${#opens} - ${#closes} ))

            [[ "$line" =~ ^[[:space:]]+name[[:space:]]*= ]] && has_name=true
            [[ "$line" =~ ^[[:space:]]+(version|schema_version)[[:space:]]*= ]] && has_version=true

            if [[ "$line" =~ ^[[:space:]]+(leash|security_level)[[:space:]]*= ]]; then
                has_security_level=true
                security_level_value="$(normalise_level "$line")"
            fi

            [[ "$line" =~ ^[[:space:]]+(signature|signature_required)[[:space:]]*= ]] && has_signature_field=true

            if [[ $pedigree_depth -le 0 && "$line" == *"}"* ]]; then
                in_pedigree=false
            fi
        fi

        # Top-level signature field
        [[ "$line" =~ ^[[:space:]]*(signature)[[:space:]]*= ]] && has_signature_field=true
    done < "$file"

    if [[ "$has_pedigree" == "false" ]]; then
        echo "  ERROR: ${file}: Missing pedigree block"
        file_errors=$((file_errors + 1))
    else
        if [[ "$has_name" == "false" ]]; then
            echo "  ERROR: ${file}: Pedigree missing 'name' field"
            file_errors=$((file_errors + 1))
        fi
        if [[ "$has_version" == "false" ]]; then
            echo "  WARNING: ${file}: Pedigree missing 'version' or 'schema_version' field"
            WARNINGS=$((WARNINGS + 1))
        fi
    fi

    # --- Security level validation ---
    if [[ "$has_security_level" == "true" ]]; then
        local level_valid=false
        for valid in $VALID_LEVELS; do
            [[ "$security_level_value" == "$valid" ]] && level_valid=true
        done
        if [[ "$level_valid" == "false" ]]; then
            echo "  ERROR: ${file}: Invalid security level '${security_level_value}' (must be kennel/yard/hunt)"
            file_errors=$((file_errors + 1))
        fi
    elif [[ "$has_pedigree" == "true" ]]; then
        echo "  WARNING: ${file}: No security level found in pedigree block"
        WARNINGS=$((WARNINGS + 1))
    fi

    # --- Hunt-level signature requirement ---
    if [[ "$security_level_value" == "hunt" && "$has_signature_field" == "false" ]]; then
        echo "  ERROR: ${file}: Hunt-level files must include 'signature' or 'signature_required' field"
        file_errors=$((file_errors + 1))
    fi

    ERRORS=$((ERRORS + file_errors))
    return "$file_errors"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if [[ $# -eq 0 ]]; then
    echo "No K9 files to validate."
    exit 0
fi

echo "Validating ${#} K9 file(s)..."

for file in "$@"; do
    if [[ -f "$file" ]]; then
        validate_file "$file" || true
    fi
done

echo ""
echo "K9 validation: ${FILES_CHECKED} files, ${ERRORS} error(s), ${WARNINGS} warning(s)"

if [[ $ERRORS -gt 0 ]]; then
    echo "FAILED: K9 validation errors found."
    exit 1
fi

exit 0
