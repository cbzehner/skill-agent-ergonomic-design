#!/usr/bin/env bash
set -euo pipefail

# Install this repository's skill into common agent skill directories.
# Usage:
#   ./install.sh                 # install to Claude, Codex, and generic agents
#   ./install.sh claude          # ~/.claude/skills
#   ./install.sh codex           # ~/.codex/skills
#   ./install.sh agents          # ~/.agents/skills (generic/Pi/Hermes-style harnesses)
#   ./install.sh opencode        # ~/.config/opencode/skills
#   ./install.sh all --copy      # copy instead of symlink
#   ./install.sh all --force     # replace an existing non-symlink destination

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(find "$REPO_DIR/skills" -mindepth 1 -maxdepth 1 -type d | sort | head -n 1)"
SKILL_NAME="$(basename "$SKILL_DIR")"

TARGET="all"
MODE="symlink"
FORCE=0

for arg in "$@"; do
  case "$arg" in
    claude|codex|agents|opencode|all) TARGET="$arg" ;;
    --copy) MODE="copy" ;;
    --force) FORCE=1 ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# *//'; exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

case "$TARGET" in
  claude) DESTS=("$HOME/.claude/skills") ;;
  codex) DESTS=("$HOME/.codex/skills") ;;
  agents) DESTS=("$HOME/.agents/skills") ;;
  opencode) DESTS=("$HOME/.config/opencode/skills") ;;
  all) DESTS=("$HOME/.claude/skills" "$HOME/.codex/skills" "$HOME/.agents/skills") ;;
esac

install_one() {
  local dest_dir="$1"
  local target="$dest_dir/$SKILL_NAME"
  mkdir -p "$dest_dir"

  if [ -e "$target" ] || [ -L "$target" ]; then
    if [ "$FORCE" -eq 1 ] || [ -L "$target" ]; then
      rm -rf "$target"
    else
      echo "skip $target: exists and is not a symlink (use --force to replace)" >&2
      return 0
    fi
  fi

  if [ "$MODE" = "copy" ]; then
    cp -R "$SKILL_DIR" "$target"
  else
    ln -s "$SKILL_DIR" "$target"
  fi
  echo "installed $SKILL_NAME -> $target ($MODE)"
}

for dest in "${DESTS[@]}"; do
  install_one "$dest"
done
