#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
PROJECT_DIR="$(pwd)"

# プロンプトにプロジェクトディレクトリ情報を付与
inject_project_dir() {
  printf '\n\n## Project Directory\nすべてのファイル操作は以下のディレクトリ内で行うこと（絶対パスを使用）:\n`%s`\n\n例:\n- `%s/characters/player.yaml`\n- `%s/scenarios/current.yaml`\n- `%s/logs/`\n- `%s/state/summary.md`\n' "$PROJECT_DIR" "$PROJECT_DIR" "$PROJECT_DIR" "$PROJECT_DIR" "$PROJECT_DIR"
}

case "${1:-}" in
  create)
    prompt="$(cat prompts/create.md)"
    prompt+="$(inject_project_dir)"
    claude --system-prompt "$prompt" --name "rpg-create"
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
    prompt+="$(inject_project_dir)"
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
    prompt+="$(inject_project_dir)"
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
