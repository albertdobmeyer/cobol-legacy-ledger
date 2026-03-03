#!/bin/bash
#================================================================*
# checkpoint.sh — Save/restore data snapshots for classroom lessons
# Usage: ./scripts/checkpoint.sh save N
#        ./scripts/checkpoint.sh restore N
#================================================================*

set -e

ACTION="${1:-}"
LESSON="${2:-}"
DATA_DIR="COBOL-BANKING/data"
CHECKPOINT_DIR="$DATA_DIR/.checkpoints"
NODES="BANK_A BANK_B BANK_C BANK_D BANK_E CLEARING"

if [ -z "$ACTION" ] || [ -z "$LESSON" ]; then
  echo "Usage: $0 save|restore LESSON_NUMBER"
  echo ""
  echo "Examples:"
  echo "  $0 save 3      # Snapshot data for lesson 3"
  echo "  $0 restore 3   # Restore data from lesson 3 snapshot"
  exit 1
fi

SNAP_DIR="$CHECKPOINT_DIR/lesson-$LESSON"

case "$ACTION" in
  save)
    echo "=== Saving checkpoint: lesson $LESSON ==="
    mkdir -p "$SNAP_DIR"

    for node in $NODES; do
      src="$DATA_DIR/$node"
      dst="$SNAP_DIR/$node"
      if [ -d "$src" ]; then
        rm -rf "$dst"
        cp -r "$src" "$dst"
        echo "  + $node"
      else
        echo "  ! $node (not found, skipping)"
      fi
    done

    echo ""
    echo "Checkpoint saved to $SNAP_DIR"
    echo "To restore: $0 restore $LESSON"
    ;;

  restore)
    if [ ! -d "$SNAP_DIR" ]; then
      echo "Error: No checkpoint found for lesson $LESSON"
      echo "  Expected: $SNAP_DIR"
      echo "  Available checkpoints:"
      ls -1 "$CHECKPOINT_DIR" 2>/dev/null || echo "    (none)"
      exit 1
    fi

    echo "=== Restoring checkpoint: lesson $LESSON ==="

    for node in $NODES; do
      src="$SNAP_DIR/$node"
      dst="$DATA_DIR/$node"
      if [ -d "$src" ]; then
        rm -rf "$dst"
        cp -r "$src" "$dst"
        echo "  + $node"
      else
        echo "  ! $node (not in checkpoint, skipping)"
      fi
    done

    echo ""
    echo "Checkpoint restored from $SNAP_DIR"
    echo "Run: make run  (to start server with restored data)"
    ;;

  *)
    echo "Unknown action: $ACTION"
    echo "Usage: $0 save|restore LESSON_NUMBER"
    exit 1
    ;;
esac
