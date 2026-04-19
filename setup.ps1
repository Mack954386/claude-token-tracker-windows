# setup.ps1 - Claude Token Tracker セットアップスクリプト

Write-Host "=== Claude Token Tracker セットアップ ===" -ForegroundColor Cyan
Write-Host ""

# メールアドレスを入力させる
$email = ""
while (-not $email) {
    $input = Read-Host "メールアドレスを入力してください"
    $input = $input.Trim()
    if ($input -match "^[^@]+@[^@]+\.[^@]+$") {
        $email = $input
    } else {
        Write-Host "正しいメールアドレスを入力してください。" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "メールアドレス: $email" -ForegroundColor Green

# .claudeディレクトリ確認・作成
$claudeDir = Join-Path $env:USERPROFILE ".claude"
if (-not (Test-Path $claudeDir)) {
    New-Item -ItemType Directory -Path $claudeDir | Out-Null
    Write-Host ".claudeディレクトリを作成しました。" -ForegroundColor Gray
}

# 設定ファイルにメールアドレスを保存
$configPath = Join-Path $claudeDir "token-tracker-config.json"
@{ email = $email } | ConvertTo-Json | Set-Content $configPath -Encoding UTF8
Write-Host "設定ファイルを保存しました: $configPath" -ForegroundColor Gray

# token-hook.ps1をコピー
$hookScriptSrc = Join-Path $PSScriptRoot "token-hook.ps1"
$hookScriptDst = Join-Path $claudeDir "token-hook.ps1"

if (-not (Test-Path $hookScriptSrc)) {
    Write-Host "エラー: token-hook.ps1 が見つかりません: $hookScriptSrc" -ForegroundColor Red
    exit 1
}

Copy-Item $hookScriptSrc $hookScriptDst -Force
Write-Host "token-hook.ps1 をコピーしました: $hookScriptDst" -ForegroundColor Gray

# settings.jsonを読み込む（なければ空のオブジェクトで開始）
$settingsPath = Join-Path $claudeDir "settings.json"
$settings = @{}

if (Test-Path $settingsPath) {
    try {
        $settingsContent = Get-Content $settingsPath -Raw -Encoding UTF8
        $parsed = $settingsContent | ConvertFrom-Json
        # PSCustomObject をハッシュテーブルに変換（PS 5.1 互換）
        $settings = @{}
        $parsed.PSObject.Properties | ForEach-Object {
            $settings[$_.Name] = $_.Value
        }
        Write-Host "既存のsettings.jsonを読み込みました。" -ForegroundColor Gray
    } catch {
        Write-Host "settings.jsonの読み込みに失敗しました。新規作成します。" -ForegroundColor Yellow
        $settings = @{}
    }
}

# hooksセクションを確認・作成
if (-not $settings.ContainsKey("hooks")) {
    $settings["hooks"] = @{}
}

$hookPath = Join-Path $env:USERPROFILE ".claude\token-hook.ps1"
$hookCommand = "powershell -ExecutionPolicy Bypass -File `"$hookPath`""

$newHookEntry = @{
    matcher = ""
    hooks   = @(
        @{
            type    = "command"
            command = $hookCommand
        }
    )
}

# Stopフックを確認・追加（重複しないように）
if (-not $settings["hooks"].ContainsKey("Stop")) {
    $settings["hooks"]["Stop"] = @()
}

$alreadyExists = $false
foreach ($entry in $settings["hooks"]["Stop"]) {
    foreach ($h in $entry.hooks) {
        if ($h.command -eq $hookCommand) {
            $alreadyExists = $true
            break
        }
    }
    if ($alreadyExists) { break }
}

if ($alreadyExists) {
    Write-Host "hookはすでに登録済みです。スキップします。" -ForegroundColor Yellow
} else {
    $settings["hooks"]["Stop"] += $newHookEntry
    Write-Host "Stopフックを追加しました。" -ForegroundColor Gray
}

# settings.jsonに書き戻す
$settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
Write-Host "settings.jsonを更新しました: $settingsPath" -ForegroundColor Gray

Write-Host ""
Write-Host "=== セットアップ完了！ ===" -ForegroundColor Green
Write-Host "Claude Codeを再起動すると、セッション終了時に自動でトークンが送信されます。"
