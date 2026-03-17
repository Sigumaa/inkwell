# RPG Engine Design — Claude Code Saga & Seeker Clone

## Overview

Claude Codeセッション上で動作するテキストRPGエンジン。Saga & Seekerのゲーム体験をClaude Codeのサブスクリプション範囲内で再現する。

## Architecture

```
rpg/
├── characters/          # キャラシート（YAML）
│   ├── player.yaml
│   ├── npc1.yaml
│   ├── npc2.yaml
│   └── npc3.yaml
├── scenarios/
│   └── current.yaml     # 現在のシナリオ設定
├── logs/                # セッションログ（Markdown）
│   └── YYYY-MM-DD-NNN.md
├── state/               # セッション間の状態引き継ぎ
│   └── summary.md       # 前回セッションの要約
├── prompts/
│   ├── create.md        # キャラ＆シナリオ作成用システムプロンプト
│   ├── play.md          # プレイ用システムプロンプト
│   └── continue.md      # 続きからプレイ用システムプロンプト
├── run.sh               # メインスクリプト
└── .gitignore
```

## Sessions

### Session A: Create (`run.sh create`)

1. プレイヤーにストーリーの状況を聞く
2. AIがストーリーの骨格を提案、対話で調整
3. AIがストーリーに合うパーティメンバー3人を提案、対話で調整
4. プレイヤーキャラを対話で作成
5. 全キャラYAML + シナリオYAMLを保存

### Session B: Play (`run.sh play`)

1. 保存済みYAMLからシステムプロンプトを自動構築
2. Claude Codeセッションを起動、物語開始
3. プレイヤーが行動入力 → AIがNPC反応＋物語展開を描写
4. GMはターンごとにWriteツールで `logs/` にログ追記
5. セッション終了時、GMが `state/summary.md` に要約を書き出し、キャラYAMLの変更点を更新

### Session C: Continue (`run.sh continue`)

1. キャラYAML + シナリオYAML + `state/summary.md` を読み込み
2. `continue.md` テンプレートでプロンプト構築（全文ログは含めない、要約のみ）
3. 物語再開

## Character Sheet Format

```yaml
name: ""
gender: ""
age: 0
appearance: ""

personality:
  traits: []
  motivation: ""
  trauma: ""
  quirks: ""

speech:
  tone: ""
  first_person: ""
  examples: []

skills: []

relationships:
  - target: ""
    relation: ""
    feeling: ""

backstory: |

# GMが物語の進行に応じて更新するセクション
state:
  injuries: []
  items: []
  relationship_changes: []
  notes: ""
```

## Scenario Format

```yaml
title: ""
setting: ""
situation: ""
theme: ""
tone: ""

progress:
  current_act: ""
  resolved: []
  unresolved: []
  next_beats: []
```

## System Prompt Design

### create.md

- 役割: シナリオ＆キャラクター作成ガイド
- ストーリー設定を対話で引き出す
- ストーリーに合うNPCを提案する
- プレイヤーキャラを対話で作成する
- 最終的にYAMLファイルとしてWriteツールで保存する

### play.md

- 役割: ゲームマスター（GM）
- プレイヤーキャラの行動はプレイヤーが入力。勝手に動かさない
- NPCはキャラシートの性格・口調に忠実に自律行動
- 描写: 小説風三人称、五感を使った臨場感、300〜600字/回
- 戦闘: 完全ナラティブ、数値判定なし
- 緩急を意識（戦闘・日常・会話シーンを織り交ぜる）
- 描写末尾で状況を示し、プレイヤーの次の行動を待つ
- ターンごとにWriteツールで `logs/` にログ追記する
- キャラの状態が変化したらEditツールでキャラYAMLの `state` セクションを更新する
- セッション終了時に `state/summary.md` に要約（主要イベント、キャラ状態変化、未解決の伏線）を書き出す
- シナリオYAMLの `progress` セクションを更新する

### continue.md

- play.mdの内容 + 前回要約の再確認指示
- `state/summary.md` の内容を展開
- 「前回のあらすじ」として物語冒頭に要約を提示してから再開

## run.sh Implementation

```bash
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

case "${1:-}" in
  create)
    claude --system-prompt "$(cat prompts/create.md)" --name "rpg-create"
    ;;
  play)
    # 前提チェック
    if [ ! -f characters/player.yaml ]; then
      echo "Error: characters/player.yaml not found. Run 'run.sh create' first."
      exit 1
    fi
    # キャラ＋シナリオをプロンプトに結合
    prompt="$(cat prompts/play.md)"
    prompt+=$'\n\n## Characters\n'
    for f in characters/*.yaml; do
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
    prompt="$(cat prompts/continue.md)"
    prompt+=$'\n\n## Characters\n'
    for f in characters/*.yaml; do
      prompt+=$'\n### '"$(basename "$f" .yaml)"$'\n```yaml\n'"$(cat "$f")"$'\n```\n'
    done
    prompt+=$'\n\n## Scenario\n```yaml\n'"$(cat scenarios/current.yaml)"$'\n```\n'
    prompt+=$'\n\n## Previous Session Summary\n'"$(cat state/summary.md)"
    claude --system-prompt "$prompt" --name "rpg-continue"
    ;;
  *)
    echo "Usage: run.sh {create|play|continue}"
    exit 1
    ;;
esac
```

## Log Saving

GMはプレイ中、各ターンの描写後にWriteツールを使って `logs/YYYY-MM-DD-NNN.md` にログを追記する。外部スクリプトでの保存は不要。

セッション終了時にGMが行うこと:
1. `state/summary.md` に要約を書き出し
2. キャラYAMLの `state` セクションを更新
3. シナリオYAMLの `progress` セクションを更新

## Constraints

- API課金なし。Claude Codeサブスクリプション範囲内で完結
- ジャンル: 現代
- パーティ: プレイヤー1人 + AI自動NPC 3人
- 1セッション: 1〜2時間（中編エピソード）
- ログ: Markdown、GMがWriteツールで自動保存
- 続きプレイ時は全文ログではなく要約のみをコンテキストに含める
