#!/bin/bash
# Run-LabADTests.sh — Bash wrapper for Run-LabADTests.ps1
# Usage: ./Run-LabADTests.sh [options]
#   --skip-build          Skip module build
#   --domains LIST        Comma-separated domain roles (default: RootForest,ChildDomain,SeparateForest)
#   --tag TAG             Test tag filter (default: AD)
#   --evidence-dir PATH   Local evidence directory
#   --help                Show this help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKIP_BUILD=""
DOMAINS=""
TAG=""
EVIDENCE_DIR=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-build) SKIP_BUILD="-SkipBuild"; shift ;;
    --domains) DOMAINS="-Domains $($2)"; shift 2 ;;
    --tag) TAG="-Tag '$2'"; shift 2 ;;
    --evidence-dir) EVIDENCE_DIR="-EvidenceDir '$2'"; shift 2 ;;
    --help)
      echo "Usage: $0 [options]"
      grep '^#   ' "$0" | sed 's/^# //'
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "Running Maester AD lab tests via PowerShell wrapper..."
pwsh -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT_DIR/Run-LabADTests.ps1" $SKIP_BUILD $DOMAINS $TAG $EVIDENCE_DIR
