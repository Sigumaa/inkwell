#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
PROJECT_DIR="$(pwd)"

# セッションキー生成（日時ベース）
generate_key() {
  date +%Y%m%d-%H%M%S
}

# プロンプトにプロジェクトディレクトリ＋セッション情報を付与
inject_session_info() {
  local key="$1"
  printf '\n\n## Session Info\nSession Key: `%s`\n\n## Project Directory\nすべてのファイル操作は以下のディレクトリ内で行うこと（絶対パスを使用）:\n`%s`\n\nログ保存先: `%s/logs/%s/`\n状態保存先: `%s/state/%s/summary.md`\nキャラ: `%s/characters/`\nシナリオ: `%s/scenarios/current.yaml`\n' \
    "$key" "$PROJECT_DIR" "$PROJECT_DIR" "$key" "$PROJECT_DIR" "$key" "$PROJECT_DIR" "$PROJECT_DIR"
}

# キャラ＋シナリオをプロンプトに結合
inject_characters_and_scenario() {
  local out=""
  out+=$'\n\n## Characters\n'
  for f in characters/*.yaml; do
    [ "$(basename "$f")" = ".gitkeep" ] && continue
    out+=$'\n### '"$(basename "$f" .yaml)"$'\n```yaml\n'"$(cat "$f")"$'\n```\n'
  done
  out+=$'\n\n## Scenario\n```yaml\n'"$(cat scenarios/current.yaml)"$'\n```\n'
  printf '%s' "$out"
}

# 前提チェック
check_created() {
  if [ ! -f characters/player.yaml ]; then
    echo "Error: characters/player.yaml not found. Run './run.sh create' first."
    exit 1
  fi
  if [ ! -f scenarios/current.yaml ]; then
    echo "Error: scenarios/current.yaml not found. Run './run.sh create' first."
    exit 1
  fi
}

# プレイセッション構築（play/auto共通部分）
build_session_prompt() {
  local mode="$1" key="$2"
  local prompt

  prompt="$(cat "prompts/$mode.md")"
  prompt+=$'\n\n'"$(cat prompts/style.md)"
  prompt+="$(inject_characters_and_scenario)"

  if [ -f "state/$key/summary.md" ]; then
    prompt+=$'\n\n'"$(cat prompts/continue-header.md)"
    prompt+=$'\n\n## Previous Session Summary\n'"$(cat "state/$key/summary.md")"
  fi

  prompt+="$(inject_session_info "$key")"
  printf '%s' "$prompt"
}

case "${1:-}" in
  create)
    prompt="$(cat prompts/create.md)"
    prompt+="$(inject_session_info "create")"
    claude --system-prompt "$prompt" --name "rpg-create"
    ;;
  play)
    check_created
    key="${2:-$(generate_key)}"
    mkdir -p "logs/$key" "state/$key"
    echo "Session key: $key"
    prompt="$(build_session_prompt play "$key")"
    claude --system-prompt "$prompt" --name "rpg-play-$key"
    ;;
  auto)
    check_created
    key="${2:-$(generate_key)}"
    mkdir -p "logs/$key" "state/$key"
    echo "Session key: $key"
    prompt="$(build_session_prompt auto "$key")"
    claude --system-prompt "$prompt" --name "rpg-auto-$key"
    ;;
  continue)
    if [ -z "${2:-}" ]; then
      echo "Error: Session key required."
      echo "Usage: ./run.sh continue <key> [play|auto]"
      echo ""
      echo "Available sessions:"
      for d in state/*/; do
        [ -d "$d" ] || continue
        k="$(basename "$d")"
        if [ -f "$d/summary.md" ]; then
          echo "  $k"
        fi
      done
      exit 1
    fi
    key="$2"
    mode="${3:-auto}"
    if [ "$mode" != "play" ] && [ "$mode" != "auto" ]; then
      echo "Error: Mode must be 'play' or 'auto'. Got: $mode"
      exit 1
    fi
    if [ ! -f "state/$key/summary.md" ]; then
      echo "Error: state/$key/summary.md not found. No session with key '$key'."
      exit 1
    fi
    check_created
    mkdir -p "logs/$key"
    echo "Continuing session '$key' in $mode mode"
    prompt="$(build_session_prompt "$mode" "$key")"
    claude --system-prompt "$prompt" --name "rpg-$mode-$key"
    ;;
  list)
    echo "Sessions:"
    for d in state/*/; do
      [ -d "$d" ] || continue
      k="$(basename "$d")"
      if [ -f "$d/summary.md" ]; then
        echo "  $k  (has summary)"
      else
        echo "  $k  (in progress)"
      fi
    done
    ;;
  *)
    echo "Usage: ./run.sh {create|play|auto|continue|list}"
    echo ""
    echo "  create                    - Create characters and scenario"
    echo "  play [key]                - Play session (player inputs actions)"
    echo "  auto [key]                - Semi-auto session (story flows automatically)"
    echo "  continue <key> [play|auto] - Continue a session (default: auto)"
    echo "  list                      - List available sessions"
    exit 1
    ;;
esac
