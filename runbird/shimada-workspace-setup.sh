#!/bin/bash
# 嶋田社長専用ワークスペース セットアップスクリプト
# 実行：嶋田さんのMacのターミナルで bash <(curl -sL https://hokuchan07.github.io/runbird/shimada-workspace-setup.sh)
#       または鈴木さんが直接Mac上で実行

set -e

WORKSPACE=~/Documents/shimada-workspace
echo "=== 嶋田社長専用ワークスペース セットアップ開始 ==="
echo "配置先: $WORKSPACE"

# 1. ディレクトリ作成
mkdir -p "$WORKSPACE/人事" "$WORKSPACE/契約" "$WORKSPACE/ナレッジ" "$WORKSPACE/.cursor/rules"
echo "[OK] フォルダ構造作成"

# 2. ナレッジリポジトリのclone（既にあればpullで最新化）
cd "$WORKSPACE/ナレッジ"
if [ -d "runbird-hr-knowledge" ]; then
  echo "[SKIP] runbird-hr-knowledge は既存（pullで更新）"
  cd runbird-hr-knowledge && git pull --rebase --autostash && cd ..
else
  git clone https://github.com/hokuchan07/runbird-hr-knowledge.git
  echo "[OK] runbird-hr-knowledge clone完了"
fi

if [ -d "runbird-contracts" ]; then
  echo "[SKIP] runbird-contracts は既存（pullで更新）"
  cd runbird-contracts && git pull --rebase --autostash && cd ..
else
  git clone https://github.com/hokuchan07/runbird-contracts.git
  echo "[OK] runbird-contracts clone完了"
fi

# 3. ルールファイル配置
cat > "$WORKSPACE/.cursor/rules/extract-to-personal.mdc" <<'RULE_EOF'
---
description: ナレッジから情報を抽出して社長専用フォルダに保存
alwaysApply: true
---

# 嶋田社長専用 ナレッジ抽出ワークスペース

このワークスペースは、ランバードの人事面談・契約書ナレッジから情報を抽出し、嶋田社長専用のメモ（人事/ 契約/）に蓄積するためのものです。

## 参照すべきナレッジ（必ずここから根拠を取る）

- `ナレッジ/runbird-hr-knowledge/ナレッジ/` … 人事面談（PLAUD録音/文字起こし）
- `ナレッジ/runbird-contracts/ナレッジ/` … 契約書（PDF + 解説md）

それ以外（一般論・推測・自分の知識）から答えることは禁止。
ナレッジに該当情報がない場合は「ナレッジに該当情報がありません」と明示し、推測で答えない。

## 出典の明示（必須）

すべての回答の最後に、根拠としたファイルパスを `**参照:**` 見出しで列挙すること。

## 自動保存ルール

ユーザーの指示に「保存して」「メモして」「記録して」「ファイルに残して」「人事に保存」「契約に保存」のいずれかが含まれる場合、回答内容を以下にmdファイルとして書き出すこと。

| 質問の種類 | 保存先 |
|---|---|
| 人事・面談・メンバー・評価関連 | `人事/{YYYYMMDD}_{要約タイトル}.md` |
| 契約書・契約条件・取引先関連 | `契約/{YYYYMMDD}_{要約タイトル}.md` |

ファイルの中身は以下の形式：

```markdown
---
作成日: YYYY-MM-DD HH:MM
質問: {ユーザーの質問そのもの}
分類: 人事 | 契約
---

# {要約タイトル（25文字以内）}

## 質問
{ユーザーの質問}

## 回答（ナレッジから抽出）
{抽出した情報。事実ベースで}

## 出典
- {ファイルパス1}
- {ファイルパス2}
```

## ファイル名のルール

- スラッシュ・コロン・スペース等の禁則文字は含めない（アンダースコアに置換）
- 同名ファイルがある場合は `_2`, `_3` のサフィックスを付ける
- タイトルは25文字以内に収める（長い場合は要約）

## ナレッジ更新

このワークスペースを開くと自動で `git pull` が走り、ナレッジは常に最新になる（VSCode Tasksで設定済み）。

## 禁止事項

- ナレッジに無い情報を推測・一般論で答える
- 出典を書かずに答える
- 「保存」指示がないのに勝手にファイルを作成する
- 既存ファイルを上書きする（新規作成のみ）
RULE_EOF
echo "[OK] .cursor/rules/extract-to-personal.mdc 配置"

# 4. ワークスペース全体の自動pullタスク
mkdir -p "$WORKSPACE/.vscode"
cat > "$WORKSPACE/.vscode/tasks.json" <<'TASKS_EOF'
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "ナレッジを最新に更新（git pull）",
      "type": "shell",
      "command": "cd ナレッジ/runbird-hr-knowledge && git pull --rebase --autostash; cd ../runbird-contracts && git pull --rebase --autostash",
      "presentation": {
        "reveal": "silent",
        "panel": "dedicated",
        "showReuseMessage": false,
        "clear": true,
        "close": true
      },
      "runOptions": {
        "runOn": "folderOpen"
      },
      "problemMatcher": []
    }
  ]
}
TASKS_EOF
cat > "$WORKSPACE/.vscode/settings.json" <<'SETTINGS_EOF'
{
  "task.allowAutomaticTasks": "on"
}
SETTINGS_EOF
echo "[OK] .vscode/tasks.json 配置（フォルダオープン時に自動pull）"

# 5. README配置
cat > "$WORKSPACE/README.md" <<'README_EOF'
# 嶋田社長専用ワークスペース

このフォルダはCursorで開いて使います。

## できること

「保存して」「メモして」と一言添えると、ナレッジから抽出した内容が `人事/` または `契約/` に自動で保存されます。

例：
- 「中村は最近モチベーションについて何と言ってる？人事に保存」
- 「○○社の契約期間と解約条件を教えて。契約に保存」

## 構造

- `人事/` … 人事に関するAI抽出メモ（自動蓄積）
- `契約/` … 契約に関するAI抽出メモ（自動蓄積）
- `ナレッジ/` … 投入元のナレッジリポジトリ（編集しない）
  - `runbird-hr-knowledge/` … 人事面談
  - `runbird-contracts/` … 契約書

## 使い方

1. このフォルダ（`shimada-workspace`）をCursorで開く
2. 初回オープン時に「タスクを自動的に許可しますか？」が出たら **Allow** を選ぶ（フォルダ開くたびに最新ナレッジに更新される）
3. Cursorのチャットで質問する
4. 「保存して」と添えると `人事/` か `契約/` に自動保存される

## ガイド

詳しい説明：https://hokuchan07.github.io/runbird/shimada-cursor-setup.html
README_EOF
echo "[OK] README.md 配置"

echo ""
echo "=== セットアップ完了 ==="
echo ""
echo "次にやること："
echo "1. Cursor を起動"
echo "2. 「Open Folder」で → $WORKSPACE を選択"
echo "3. タスクの自動実行を聞かれたら「Allow」"
echo "4. チャットに質問入れて「保存して」と添える → 人事/ か 契約/ にmdが生成される"
