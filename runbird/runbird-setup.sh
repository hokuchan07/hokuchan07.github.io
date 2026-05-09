#!/bin/bash
# RUNBIRD ナレッジAI 統合ワークスペース セットアップスクリプト
# 実行：bash <(curl -sL https://hokuchan07.github.io/runbird/runbird-setup.sh)
#
# やること：
# 1) ~/Documents/runbird-knowledge/ を作成
# 2) アクセスできる repo を自動的にclone（権限ないものはスキップ）
# 3) Cursor用の統合ワークスペースファイル(runbird.code-workspace)を生成
# 4) 1ウィンドウで自分の権限内ナレッジが全部見える状態にする

set +e  # アクセス権限なしのrepoがあってもスクリプト全体を止めない

WORKSPACE_DIR=~/Documents/runbird-knowledge
echo "=== RUNBIRD ナレッジAI 統合ワークスペース セットアップ ==="
echo "配置先: $WORKSPACE_DIR"
echo ""

mkdir -p "$WORKSPACE_DIR"
cd "$WORKSPACE_DIR" || exit 1

# 全リポジトリ候補
declare -a REPO_LIST=(
  "runbird-welfare-knowledge:福祉ナレッジ"
  "runbird-it-knowledge:IT営業ナレッジ"
  "runbird-hr-knowledge:人事面談"
  "runbird-contracts:契約書"
  "runbird-shimada-clone:社長クローン"
)

declare -a INCLUDED_REPOS=()
declare -a INCLUDED_NAMES=()

for entry in "${REPO_LIST[@]}"; do
  IFS=':' read -r repo name <<< "$entry"
  if [ -d "$repo" ]; then
    echo "[更新] $repo（既存・git pull）"
    (cd "$repo" && git pull --rebase --autostash 2>&1 | tail -2)
    INCLUDED_REPOS+=("$repo")
    INCLUDED_NAMES+=("$name")
  else
    echo "[clone] $repo を取得中..."
    if git clone "https://github.com/runbird-inc/$repo.git" 2>&1 | tail -2; then
      if [ -d "$repo" ]; then
        echo "  → 成功（$name）"
        INCLUDED_REPOS+=("$repo")
        INCLUDED_NAMES+=("$name")
      else
        echo "  → 権限なし or アクセス不可（スキップ）"
      fi
    fi
  fi
  echo ""
done

if [ ${#INCLUDED_REPOS[@]} -eq 0 ]; then
  echo "エラー: アクセスできるリポジトリがありませんでした。"
  echo "GitHub Org招待を承認しているか確認してください："
  echo "  https://github.com/runbird-inc"
  exit 1
fi

# Cursor統合ワークスペースファイル生成
WORKSPACE_FILE="$WORKSPACE_DIR/runbird.code-workspace"
{
  echo '{'
  echo '  "folders": ['
  for i in "${!INCLUDED_REPOS[@]}"; do
    repo="${INCLUDED_REPOS[$i]}"
    name="${INCLUDED_NAMES[$i]}"
    if [ "$i" -eq $((${#INCLUDED_REPOS[@]} - 1)) ]; then
      echo "    { \"name\": \"$name\", \"path\": \"$repo\" }"
    else
      echo "    { \"name\": \"$name\", \"path\": \"$repo\" },"
    fi
  done
  echo '  ],'
  echo '  "settings": {'
  echo '    "git.autofetch": true,'
  echo '    "git.autofetchPeriod": 600,'
  echo '    "task.allowAutomaticTasks": "on",'
  echo '    "window.title": "RUNBIRD ナレッジ — ${rootName}"'
  echo '  }'
  echo '}'
} > "$WORKSPACE_FILE"

# 各repoにフォルダオープン時の自動pullタスクを設定（既に設定済みならスキップ）
for repo in "${INCLUDED_REPOS[@]}"; do
  if [ ! -f "$repo/.vscode/tasks.json" ]; then
    mkdir -p "$repo/.vscode"
    cat > "$repo/.vscode/tasks.json" <<'EOF'
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "ナレッジを最新に更新（git pull）",
      "type": "shell",
      "command": "git pull --rebase --autostash",
      "presentation": { "reveal": "silent", "panel": "dedicated", "showReuseMessage": false, "clear": true, "close": true },
      "runOptions": { "runOn": "folderOpen" },
      "problemMatcher": []
    }
  ]
}
EOF
  fi
done

# README作成
cat > "$WORKSPACE_DIR/README.md" <<README_EOF
# RUNBIRD ナレッジAI 統合ワークスペース

このフォルダはCursorで $WORKSPACE_FILE を開いて使います。

## 含まれるナレッジ

$(for i in "${!INCLUDED_REPOS[@]}"; do echo "- ${INCLUDED_NAMES[$i]} (${INCLUDED_REPOS[$i]})"; done)

## 使い方

1. Cursorを起動
2. 「File > Open Workspace from File」で \`runbird.code-workspace\` を選択
3. 1ウィンドウで全ナレッジが折りたたみ表示されます
4. Cursorのチャット（Cmd+L）で質問

## 最新化

各ナレッジrepoはフォルダオープン時に自動 git pull が走ります。
手動で更新したい場合：このスクリプトをもう一度実行してください。

## 詳しいガイド

https://hokuchan07.github.io/runbird/hr-contracts-guide.html
README_EOF

echo "=== セットアップ完了 ==="
echo ""
echo "含まれるナレッジ:"
for i in "${!INCLUDED_REPOS[@]}"; do
  echo "  - ${INCLUDED_NAMES[$i]} (${INCLUDED_REPOS[$i]})"
done
echo ""
echo "次の操作:"
echo "  1. Cursor を起動"
echo "  2. File > Open Workspace from File"
echo "  3. 以下のファイルを選択:"
echo "     $WORKSPACE_FILE"
echo "  4. Cursorのチャット（Cmd+L）で質問"
