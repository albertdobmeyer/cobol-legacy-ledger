#!/bin/bash
#================================================================*
# build.sh — Compile all COBOL programs
#
# Requires: GnuCOBOL (cobc) — install via apt or brew
#   Ubuntu/Debian: sudo apt install gnucobol
#   macOS:         brew install gnucobol
#   Docker:        docker run --rm -v $(pwd):/app -w /app ubuntu:22.04 \
#                    bash -c "apt-get update && apt-get install -y gnucobol && bash scripts/build.sh"
#
# Usage:
#   ./scripts/build.sh          # from COBOL-BANKING root
#================================================================*

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if ! command -v cobc &> /dev/null; then
  echo "ERROR: cobc (GnuCOBOL) not found. Install it first."
  echo "  Ubuntu/Debian: sudo apt install gnucobol"
  echo "  macOS:         brew install gnucobol"
  exit 1
fi

mkdir -p "$ROOT/bin"

PROGRAMS=(SMOKETEST ACCOUNTS TRANSACT VALIDATE REPORTS INTEREST FEES RECONCILE SIMULATE SETTLE)
FAILED=()

for PROG in "${PROGRAMS[@]}"; do
  SRC="$ROOT/src/${PROG}.cob"
  [ ! -f "$SRC" ] && echo "SKIP $PROG (not found)" && continue

  echo -n "BUILD $PROG ... "
  if cobc -x -free -I "$ROOT/copybooks" "$SRC" -o "$ROOT/bin/${PROG}" 2>&1; then
    echo "OK"
  else
    echo "FAIL"
    FAILED+=("$PROG")
  fi
done

chmod +x "$ROOT/bin"/* 2>/dev/null || true

if [ ${#FAILED[@]} -eq 0 ]; then
  echo ""
  echo "All ${#PROGRAMS[@]} programs compiled → bin/"
else
  echo ""
  echo "ERROR: ${#FAILED[@]} failed: ${FAILED[*]}"
  exit 1
fi
