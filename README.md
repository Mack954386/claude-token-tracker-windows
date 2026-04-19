# Claude Token Tracker for Windows

Claude Codeのトークン使用量を自動集計してAPIに送信するWindows用フックスクリプトです。

## ファイル構成

- `setup.ps1` — 初回セットアップ用スクリプト
- `token-hook.ps1` — Claude Codeのhookから呼ばれるトークン集計スクリプト

## セットアップ手順

1. このリポジトリをクローンまたはZIPダウンロードする
2. PowerShellを開き、スクリプトのあるフォルダに移動する
3. 以下を実行する：

```powershell
powershell -ExecutionPolicy Bypass -File setup.ps1
```

4. メールアドレスを入力する
5. Claude Codeを再起動する

## 動作の仕組み

1. Claude Codeのセッションが終了すると `Stop` フックが発火する
2. `token-hook.ps1` がトランスクリプトのJSONLファイルを読み込む
3. `assistant` タイプのエントリから以下のトークン数を合計する：
   - `input_tokens`
   - `cache_read_input_tokens`
   - `cache_creation_input_tokens`
   - `output_tokens`
4. 集計結果をAPIに送信する

## 送信先API

- URL: `https://claude-token-tracker-amber.vercel.app/api/hooks/token`
- Method: POST
- Header: `x-hook-secret: digiman2026`
