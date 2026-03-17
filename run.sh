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

# プレイセッション構築
build_session_prompt() {
  local mode="$1" key="$2"
  local prompt

  prompt="$(cat "prompts/$mode.md")"
  prompt+=$'\n\n'"$(cat prompts/style.md)"
  prompt+="$(inject_characters_and_scenario)"
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
  resume)
    # claude --resume でセッション選択画面を開く（全会話履歴を保持したまま再開）
    search="${2:-rpg}"
    echo "Resuming session (search: $search)..."
    claude --resume "$search"
    ;;
  list)
    found=0
    keys=""
    for dir in state logs; do
      [ -d "$dir" ] || continue
      for d in "$dir"/*/; do
        [ -d "$d" ] || continue
        keys+="$(basename "$d")"$'\n'
      done
    done
    keys="$(echo "$keys" | sort -u | grep -v '^$')"
    for k in $keys; do
      if [ $found -eq 0 ]; then
        echo "Sessions:"
        echo ""
        found=1
      fi
      log_count=0
      if [ -d "logs/$k" ]; then
        log_count=$(find "logs/$k" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
      fi
      if [ -f "state/$k/summary.md" ]; then
        summary_line=$(head -1 "state/$k/summary.md" | sed 's/^#* *//')
        echo "  [$k]  logs: ${log_count}  ✓ has summary"
        [ -n "$summary_line" ] && echo "    $summary_line"
      else
        echo "  [$k]  logs: ${log_count}"
      fi
      echo ""
    done
    if [ $found -eq 0 ]; then
      echo "No sessions found. Run './run.sh play' or './run.sh auto' to start."
    fi
    echo "Tip: Use './run.sh resume' to resume with full conversation history."
    ;;
  *)
    echo "Usage: ./run.sh {create|play|auto|resume|list}"
    echo ""
    echo "  create          - Create characters and scenario"
    echo "  play [key]      - Play session (player inputs actions)"
    echo "  auto [key]      - Semi-auto session (story flows automatically)"
    echo "  resume [search] - Resume a previous session (default search: 'rpg')"
    echo "  list            - List available sessions"
    exit 1
    ;;
esac
