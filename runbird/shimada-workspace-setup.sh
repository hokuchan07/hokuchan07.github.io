#!/bin/bash
# 嶋田社長専用ワークスペース セットアップスクリプト
# 実行：嶋田さんのMacのターミナルで bash <(curl -sL https://hokuchan07.github.io/runbird/shimada-workspace-setup.sh)
#       または鈴木さんが直接Mac上で実行
#
# このスクリプトはidempotent（何度実行しても安全）です。
# 初回実行：人事/ 契約/ 共有/ フォルダ作成、ナレッジclone、ルール配置、自動push設定
# 2回目以降：既存項目はスキップ、追加更新のみ実施

set -e

WORKSPACE=~/Documents/shimada-workspace
echo "=== 嶋田社長専用ワークスペース セットアップ開始 ==="
echo "配置先: $WORKSPACE"

# 1. ディレクトリ作成（人事/契約=既存、共有=新規）
mkdir -p "$WORKSPACE/人事" "$WORKSPACE/契約" "$WORKSPACE/ナレッジ" "$WORKSPACE/.cursor/rules" "$WORKSPACE/.scripts"
echo "[OK] フォルダ構造作成（人事/ 契約/ ナレッジ/）"

# 2. ナレッジリポジトリのclone（既にあればpullで最新化）
cd "$WORKSPACE/ナレッジ"
for repo in runbird-hr-knowledge runbird-contracts; do
  if [ -d "$repo" ]; then
    echo "[SKIP] $repo は既存（pullで更新）"
    (cd "$repo" && git pull --rebase --autostash)
  else
    git clone "https://github.com/runbird-inc/$repo.git"
    echo "[OK] $repo clone完了"
  fi
done

# 3. 共有フォルダ＝runbird-shimada-clone repoとして clone（NEW）
cd "$WORKSPACE"
if [ -d "共有/.git" ]; then
  echo "[SKIP] 共有/ は既存リポジトリ（pullで更新）"
  (cd 共有 && git pull --rebase --autostash)
else
  if [ -d "共有" ]; then
    echo "[警告] 共有/ がリポジトリではない形で既に存在します。安全のため処理を中止します。"
    echo "       手動で確認してから再実行してください: $WORKSPACE/共有"
    exit 1
  fi
  git clone https://github.com/runbird-inc/runbird-shimada-clone.git 共有
  echo "[OK] 共有/ clone完了（社長クローン用ナレッジ）"
fi

# 4. ルールファイル配置（共有routing追加版）
cat > "$WORKSPACE/.cursor/rules/extract-to-personal.mdc" <<'RULE_EOF'
---
description: ナレッジから情報を抽出して社長専用フォルダに保存／共有指示時はクローン用フォルダに保存
alwaysApply: true
---

# 嶋田社長専用 ナレッジ抽出ワークスペース

このワークスペースは、ランバードの人事面談・契約書ナレッジから情報を抽出し、嶋田社長専用のメモ（人事/ 契約/）または社員参照用ナレッジ（共有/）に蓄積するためのものです。

## 参照すべきナレッジ（必ずここから根拠を取る）

- `ナレッジ/runbird-hr-knowledge/ナレッジ/` … 人事面談（PLAUD録音/文字起こし）
- `ナレッジ/runbird-contracts/ナレッジ/` … 契約書（PDF + 解説md）

それ以外（一般論・推測・自分の知識）から答えることは禁止。
ナレッジに該当情報がない場合は「ナレッジに該当情報がありません」と明示し、推測で答えない。

## 出典の明示（必須）

すべての回答の最後に、根拠としたファイルパスを `**参照:**` 見出しで列挙すること。

## 自動保存ルール（3つの保存先を「キーワード」で振り分け）

ユーザーの指示に以下のキーワードが含まれる場合、回答内容を該当フォルダにmdファイルとして書き出す。

| キーワード | 保存先 | 公開範囲 |
|---|---|---|
| 「人事に保存」「メモして」「記録して」（人事系の文脈） | `人事/{YYYYMMDD}_{要約タイトル}.md` | **社長手元のみ**（GitHub非公開） |
| 「契約に保存」「ファイルに残して」（契約系の文脈） | `契約/{YYYYMMDD}_{要約タイトル}.md` | **社長手元のみ**（GitHub非公開） |
| 「共有して」「みんなに展開」「クローンに追加」 | `共有/{領域}/{YYYYMMDD}_{要約タイトル}.md` | **全社員参照可**（GitHub経由でクローンが回答に使用） |

「共有して」と社長が明示的に言った場合のみ、共有/ に保存する。それ以外は人事/ または 契約/ に保存（=社長手元のみ）。

### 共有/ の領域（保存先サブフォルダ）

- `共有/経営判断ログ/` — 過去の経営判断とその理由
- `共有/営業ナレッジ/` — 営業上の判断軸・対応方針
- `共有/よくある質問への回答/` — 社員からの定番質問への回答
- `共有/社員からの相談履歴/` — 過去の相談と対応記録

質問の内容から最適なサブフォルダを判断して保存。

## ファイル形式

```markdown
---
作成日: YYYY-MM-DD HH:MM
質問: {ユーザーの質問そのもの}
分類: 人事 | 契約 | 共有-{領域名}
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

## 共有/ への保存後の動作

- 共有/ に保存したファイルは、launchd の自動pushで定期的にGitHubに同期される（最大30分後に社員のクローンから参照可能になる）
- 即座に同期したい場合は、ターミナルで以下を実行：
  ```
  cd ~/Documents/shimada-workspace/共有 && git add -A && git commit -m "共有: {タイトル}" && git push
  ```

## ナレッジ更新

このワークスペースを開くと自動で `git pull` が走り、ナレッジは常に最新になる（VSCode Tasksで設定済み）。

## 禁止事項

- ナレッジに無い情報を推測・一般論で答える
- 出典を書かずに答える
- 「保存」「共有」指示がないのに勝手にファイルを作成する
- 既存ファイルを上書きする（新規作成のみ）
- 「共有して」と言われていないのに 共有/ に書き込む（人事/ または 契約/ がデフォルト）
RULE_EOF
echo "[OK] .cursor/rules/extract-to-personal.mdc 配置（共有routing含む）"

# 5. ワークスペース全体の自動pullタスク
mkdir -p "$WORKSPACE/.vscode"
cat > "$WORKSPACE/.vscode/tasks.json" <<'TASKS_EOF'
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "ナレッジを最新に更新（git pull）",
      "type": "shell",
      "command": "cd ナレッジ/runbird-hr-knowledge && git pull --rebase --autostash; cd ../runbird-contracts && git pull --rebase --autostash; cd ../../共有 && git pull --rebase --autostash",
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

# 6. 共有/の自動push設定（launchd）
PUSH_SCRIPT="$WORKSPACE/.scripts/clone-push.sh"
cat > "$PUSH_SCRIPT" <<'PUSH_EOF'
#!/bin/bash
# 共有/ フォルダの自動push（30分ごとにlaunchdが実行）
set -e

SHARE_DIR=~/Documents/shimada-workspace/共有
LOG=/tmp/shimada-clone-push.log

echo "=== $(date '+%Y-%m-%d %H:%M:%S') 共有/ 自動push開始 ===" >> "$LOG"

if [ ! -d "$SHARE_DIR/.git" ]; then
  echo "[ERROR] $SHARE_DIR is not a git repository" >> "$LOG"
  exit 0
fi

cd "$SHARE_DIR"

# pullしてからpush（コンフリクト回避）
git pull --rebase --autostash 2>&1 >> "$LOG" || {
  echo "[ERROR] git pull failed" >> "$LOG"
  exit 0
}

# 変更があればコミット&push
if [ -n "$(git status --porcelain)" ]; then
  git add -A 2>&1 >> "$LOG"
  git commit -m "自動同期: 社長の共有判断 $(date '+%Y-%m-%d %H:%M')" 2>&1 >> "$LOG"
  git push origin main 2>&1 >> "$LOG"
  echo "[OK] push完了" >> "$LOG"
else
  echo "[SKIP] 変更なし" >> "$LOG"
fi
PUSH_EOF
chmod +x "$PUSH_SCRIPT"
echo "[OK] 自動pushスクリプト配置: $PUSH_SCRIPT"

# 7. launchd plist配置（30分ごとに自動push）
PLIST=~/Library/LaunchAgents/com.runbird.shimada-clone-push.plist
mkdir -p ~/Library/LaunchAgents
cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.runbird.shimada-clone-push</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$PUSH_SCRIPT</string>
  </array>
  <key>StartInterval</key>
  <integer>1800</integer>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/tmp/shimada-clone-push.stdout</string>
  <key>StandardErrorPath</key>
  <string>/tmp/shimada-clone-push.stderr</string>
</dict>
</plist>
PLIST_EOF

# launchd リロード（既存があればunloadしてから再load）
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
echo "[OK] launchd 30分間隔の自動push設定完了"

# 8. README配置（共有/ 説明追加版）
cat > "$WORKSPACE/README.md" <<'README_EOF'
# 嶋田社長専用ワークスペース

このフォルダはCursorで開いて使います。

## できること

「保存して」「共有して」と一言添えると、ナレッジから抽出した内容が自動で適切な場所に保存されます。

| キーワード | 保存先 | 誰が見られる |
|---|---|---|
| 「人事に保存」 | 人事/ | 社長のみ |
| 「契約に保存」 | 契約/ | 社長のみ |
| **「共有して」** | **共有/** | **全社員（GitHub経由でクローンが回答）** |

例：
- 「中村は最近モチベーションについて何と言ってる？人事に保存」
- 「○○社の契約期間と解約条件を教えて。契約に保存」
- 「値引き交渉の判断軸を整理して。**共有して**」 ← 社員のクローンが参照する

## 構造

- `人事/` … 人事に関するAI抽出メモ（社長手元のみ）
- `契約/` … 契約に関するAI抽出メモ（社長手元のみ）
- `共有/` … 社員クローン用ナレッジ（GitHub同期、全社員参照可）
  - `経営判断ログ/`
  - `営業ナレッジ/`
  - `よくある質問への回答/`
  - `社員からの相談履歴/`
- `ナレッジ/` … 投入元のナレッジリポジトリ（編集しない）
  - `runbird-hr-knowledge/` … 人事面談
  - `runbird-contracts/` … 契約書

## 使い方

1. このフォルダ（`shimada-workspace`）をCursorで開く
2. 初回オープン時に「タスクを自動的に許可しますか？」が出たら **Allow** を選ぶ（フォルダ開くたびに最新ナレッジに更新される）
3. Cursorのチャットで質問する
4. 「保存して」「共有して」と添えると適切なフォルダに自動保存される

## 共有/ の自動同期

共有/ は30分ごとに自動でGitHubにpushされます（launchd設定済み）。
即座に同期したい場合：
```
cd ~/Documents/shimada-workspace/共有 && git add -A && git commit -m "共有" && git push
```

## ガイド

- 詳しい説明：https://hokuchan07.github.io/runbird/shimada-cursor-setup.html
- 構想・背景：https://hokuchan07.github.io/runbird/shimada-clone-proposal.html
README_EOF
echo "[OK] README.md 配置"

echo ""
echo "=== セットアップ完了 ==="
echo ""
echo "次にやること："
echo "1. Cursor を起動"
echo "2. 「Open Folder」で → $WORKSPACE を選択"
echo "3. タスクの自動実行を聞かれたら「Allow」"
echo "4. チャットに質問入れて「保存して」「共有して」を試す"
echo ""
echo "自動push確認："
echo "  ログ: tail -f /tmp/shimada-clone-push.log"
echo "  間隔: 30分ごと"
