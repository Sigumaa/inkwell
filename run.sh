#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

case "${1:-}" in
  create)
    claude --system-prompt "$(cat prompts/create.md)" --name "rpg-create"
    ;;
  play)
    if [ ! -f characters/player.yaml ]; then
      echo "Error: characters/player.yaml not found. Run './run.sh create' first."
      exit 1
    fi
    if [ ! -f scenarios/current.yaml ]; then
      echo "Error: scenarios/current.yaml not found. Run './run.sh create' first."
      exit 1
    fi
    prompt="$(cat prompts/play.md)"
    prompt+=$'\n\n## Characters\n'
    for f in characters/*.yaml; do
      [ "$(basename "$f")" = ".gitkeep" ] && continue
      prompt+=$'\n### '"$(basename "$f" .yaml)"$'\n```yaml\n'"$(cat "$f")"$'\n```\n'
    done
    prompt+=$'\n\n## Scenario\n```yaml\n'"$(cat scenarios/current.yaml)"$'\n```\n'
    claude --system-prompt "$prompt" --name "rpg-play"
    ;;
  continue)
    if [ ! -f state/summary.md ]; then
      echo "Error: state/summary.md not found. No previous session to continue."
      exit 1
    fi
    if [ ! -f characters/player.yaml ]; then
      echo "Error: characters/player.yaml not found."
      exit 1
    fi
    prompt="$(cat prompts/continue.md)"
    prompt+=$'\n\n## Characters\n'
    for f in characters/*.yaml; do
      [ "$(basename "$f")" = ".gitkeep" ] && continue
      prompt+=$'\n### '"$(basename "$f" .yaml)"$'\n```yaml\n'"$(cat "$f")"$'\n```\n'
    done
    prompt+=$'\n\n## Scenario\n```yaml\n'"$(cat scenarios/current.yaml)"$'\n```\n'
    prompt+=$'\n\n## Previous Session Summary\n'"$(cat state/summary.md)"
    claude --system-prompt "$prompt" --name "rpg-continue"
    ;;
  *)
    echo "Usage: ./run.sh {create|play|continue}"
    echo ""
    echo "  create    - Create characters and scenario interactively"
    echo "  play      - Start a new play session"
    echo "  continue  - Continue from previous session"
    exit 1
    ;;
esac
