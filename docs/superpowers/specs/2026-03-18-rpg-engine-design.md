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
├── prompts/
│   ├── create.md        # キャラ＆シナリオ作成用システムプロンプト
│   └── play.md          # プレイ用システムプロンプト
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
4. セッション終了時にログをMarkdownで保存

### Session C: Continue (`run.sh continue`)

1. YAML + 前回ログを読み込み
2. システムプロンプトに前回ログを含めて構築
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

```

## Scenario Format

```yaml
title: ""
setting: ""
situation: ""
theme: ""
tone: ""
```

## System Prompt Design

### create.md

- 役割: シナリオ＆キャラクター作成ガイド
- ストーリー設定を対話で引き出す
- ストーリーに合うNPCを提案する
- プレイヤーキャラを対話で作成する
- 最終的にYAMLファイルとして保存する

### play.md

- 役割: ゲームマスター（GM）
- プレイヤーキャラの行動はプレイヤーが入力。勝手に動かさない
- NPCはキャラシートの性格・口調に忠実に自律行動
- 描写: 小説風三人称、五感を使った臨場感、300〜600字/回
- 戦闘: 完全ナラティブ、数値判定なし
- 緩急を意識（戦闘・日常・会話シーンを織り交ぜる）
- 描写末尾で状況を示し、プレイヤーの次の行動を待つ

## run.sh

```
run.sh create    → キャラ＆シナリオ作成セッション起動
run.sh play      → プレイセッション起動
run.sh continue  → 前回の続きからプレイ
```

スクリプトの責務:
- キャラYAML + シナリオYAML + プロンプトテンプレートを結合
- 結合結果をClaude Codeのプロンプトとして渡してセッション起動
- ログ保存（セッション終了時）

## Constraints

- API課金なし。Claude Codeサブスクリプション範囲内で完結
- ジャンル: 現代（初期デフォルト）
- パーティ: プレイヤー1人 + AI自動NPC 3人
- 1セッション: 1〜2時間（中編エピソード）
- ログ: Markdown自動保存
