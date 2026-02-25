#!/bin/bash
#================================================================*
# seed.sh — Generate demo ACCOUNTS.DAT for all 6 banking nodes
#
# Creates 42 accounts (37 customer + 5 nostro) in fixed-width
# 70-byte ACCTREC format. No Python required — pure shell + printf.
#
# Usage:
#   ./scripts/seed.sh          # from COBOL-BANKING root
#================================================================*

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Write one 70-byte account record (+ newline for LINE SEQUENTIAL)
# Args: file acct_id name type balance_cents status date
write_record() {
  local FILE="$1" ID="$2" NAME="$3" TYPE="$4" CENTS="$5" STATUS="$6" DATE="$7"
  printf "%-10s%-30s%s%012d%s%8s%8s\n" \
    "$ID" "$NAME" "$TYPE" "$CENTS" "$STATUS" "$DATE" "$DATE" >> "$FILE"
}

seed_bank() {
  local NODE="$1"
  shift
  local DIR="$ROOT/data/$NODE"
  mkdir -p "$DIR"
  > "$DIR/ACCOUNTS.DAT"    # truncate
  > "$DIR/TRANSACT.DAT"    # empty tx log

  local COUNT=0
  while [ $# -ge 5 ]; do
    write_record "$DIR/ACCOUNTS.DAT" "$1" "$2" "$3" "$4" "$5" "20260217"
    shift 5
    COUNT=$((COUNT + 1))
  done
  echo "  $NODE: $COUNT accounts"
}

echo "Seeding all 6 nodes..."
echo ""

# BANK_A: 8 retail accounts
seed_bank "BANK_A" \
  "ACT-A-001" "Maria Santos"          "C"  "500000"      "A" \
  "ACT-A-002" "James Wilson"          "S"  "1250000"     "A" \
  "ACT-A-003" "Chen Liu"              "C"  "85050"       "A" \
  "ACT-A-004" "Patricia Kumar"        "S"  "2500000"     "A" \
  "ACT-A-005" "Robert Brown"          "C"  "320000"      "A" \
  "ACT-A-006" "Sophie Martin"         "S"  "7500000"     "A" \
  "ACT-A-007" "David Garcia"          "C"  "150000"      "A" \
  "ACT-A-008" "Emma Johnson"          "S"  "4500000"     "A"

# BANK_B: 7 corporate accounts
seed_bank "BANK_B" \
  "ACT-B-001" "Acme Manufacturing"    "C"  "35000000"    "A" \
  "ACT-B-002" "Global Logistics"      "C"  "12500000"    "A" \
  "ACT-B-003" "TechStart Ventures"    "S"  "50000000"    "A" \
  "ACT-B-004" "Peninsula Holdings"    "C"  "7500000"     "A" \
  "ACT-B-005" "NorthSide Insurance"   "C"  "25000000"    "A" \
  "ACT-B-006" "Pacific Shipping"      "C"  "18000000"    "A" \
  "ACT-B-007" "Greenfield Properties" "S"  "100000000"   "A"

# BANK_C: 8 mixed accounts
seed_bank "BANK_C" \
  "ACT-C-001" "Lisa Wong"             "S"  "15000000"    "A" \
  "ACT-C-002" "Michael OBrien"        "C"  "4500000"     "A" \
  "ACT-C-003" "Alicia Patel"          "S"  "20000000"    "A" \
  "ACT-C-004" "Nina Kumar"            "S"  "32000000"    "A" \
  "ACT-C-005" "Thomas Anderson"       "C"  "2500000"     "A" \
  "ACT-C-006" "Rachel Green"          "S"  "55000000"    "A" \
  "ACT-C-007" "Christopher Lee"       "C"  "8000000"     "A" \
  "ACT-C-008" "Sophia Rivera"         "S"  "40000000"    "A"

# BANK_D: 6 high-value trust accounts
seed_bank "BANK_D" \
  "ACT-D-001" "Westchester Trust Corp"  "C"  "500000000"   "A" \
  "ACT-D-002" "Birch Estate Partners"   "S"  "1200000000"  "A" \
  "ACT-D-003" "Alpine Investment Club"  "C"  "75000000"    "A" \
  "ACT-D-004" "Laurel Foundation"       "S"  "250000000"   "A" \
  "ACT-D-005" "Strategic Capital Fund"  "C"  "800000000"   "A" \
  "ACT-D-006" "Legacy Trust Settlement" "S"  "1500000000"  "A"

# BANK_E: 8 community accounts
seed_bank "BANK_E" \
  "ACT-E-001" "Metro Community Fund"     "C"  "120000000"  "A" \
  "ACT-E-002" "Angela Rodriguez"         "C"  "4500000"    "A" \
  "ACT-E-003" "SBA Loan Pool"            "S"  "250000000"  "A" \
  "ACT-E-004" "Marcus Thompson"          "S"  "12500000"   "A" \
  "ACT-E-005" "Metro Food Bank"          "C"  "50000000"   "A" \
  "ACT-E-006" "Urban Development Proj"   "S"  "300000000"  "A" \
  "ACT-E-007" "Women Entrepreneurs Fund" "C"  "75000000"   "A" \
  "ACT-E-008" "Youth Skills Initiative"  "S"  "85000000"   "A"

# CLEARING: 5 nostro accounts ($10M each = $50M total)
seed_bank "CLEARING" \
  "NST-BANK-A" "Nostro Account - BANK_A" "C" "1000000000" "A" \
  "NST-BANK-B" "Nostro Account - BANK_B" "C" "1000000000" "A" \
  "NST-BANK-C" "Nostro Account - BANK_C" "C" "1000000000" "A" \
  "NST-BANK-D" "Nostro Account - BANK_D" "C" "1000000000" "A" \
  "NST-BANK-E" "Nostro Account - BANK_E" "C" "1000000000" "A"

echo ""
echo "Done — 42 accounts across 6 nodes"
echo "Verify: wc -l data/*/ACCOUNTS.DAT"
