#!/bin/bash
#================================================================*
# run-simulation.sh — Multi-day hub-and-spoke banking simulation
#
# Each day: 5 banks generate transactions (SIMULATE), then the
# clearing house settles outbound transfers (SETTLE).
#
# Usage:
#   ./scripts/run-simulation.sh          # Full 25-day run
#   ./scripts/run-simulation.sh 10       # Run only 10 days
#
# Prerequisites:
#   ./scripts/build.sh   — Compile SIMULATE and SETTLE
#   ./scripts/seed.sh    — Fresh starting data
#================================================================*

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DAYS=${1:-25}

# Verify binaries
for BIN in SIMULATE SETTLE; do
  if [ ! -f "$ROOT/bin/$BIN" ]; then
    echo "ERROR: $BIN not found. Run ./scripts/build.sh first."
    exit 1
  fi
done

BANKS="BANK_A BANK_B BANK_C BANK_D BANK_E"

echo "========================================"
echo "  COBOL BANKING SIMULATION"
echo "  Days: $DAYS  |  Banks: 5 + CLEARING"
echo "========================================"
echo ""

for DAY in $(seq 1 $DAYS); do
  echo "--- DAY $DAY ---"

  # Phase 1: Each bank generates daily transactions
  for BANK in $BANKS; do
    cd "$ROOT/data/$BANK"
    "$ROOT/bin/SIMULATE" "$BANK" "$DAY"
  done

  # Phase 2: Clearing house settles outbound transfers
  cd "$ROOT/data/CLEARING"
  "$ROOT/bin/SETTLE" "$DAY"

  echo ""
done

echo "========================================"
echo "  SIMULATION COMPLETE — $DAYS days"
echo "========================================"
echo ""
echo "Output files:"
for BANK in $BANKS; do
  TX_FILE="$ROOT/data/$BANK/TRANSACT.DAT"
  TX_COUNT=0
  [ -f "$TX_FILE" ] && TX_COUNT=$(wc -l < "$TX_FILE")
  echo "  $BANK: $TX_COUNT transactions"
done
CLEARING_TX="$ROOT/data/CLEARING/TRANSACT.DAT"
STL_COUNT=0
[ -f "$CLEARING_TX" ] && STL_COUNT=$(wc -l < "$CLEARING_TX")
echo "  CLEARING: $STL_COUNT settlement records"
