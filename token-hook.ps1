# token-hook.ps1 - Claude Code Stop hookから呼ばれるトークン集計スクリプト

param()

# stdinからhookデータ(JSON)を読み取る
$stdinData = $null
try {
    $stdinData = [Console]::In.ReadToEnd() | ConvertFrom-Json
} catch {
    exit 0
}

if (-not $stdinData -or -not $stdinData.transcript_path) {
    exit 0
}

$transcriptPath = $stdinData.transcript_path

if (-not (Test-Path $transcriptPath)) {
    exit 0
}

# 設定ファイルからメールアドレスを取得
$configPath = Join-Path $env:USERPROFILE ".claude\token-tracker-config.json"
if (-not (Test-Path $configPath)) {
    exit 0
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$email = $config.email

if (-not $email) {
    exit 0
}

# JONLファイルを読んでトークンを集計
$totalInputTokens = 0
$totalCacheReadTokens = 0
$totalCacheCreationTokens = 0
$totalOutputTokens = 0

Get-Content $transcriptPath | ForEach-Object {
    try {
        $entry = $_ | ConvertFrom-Json
        if ($entry.type -eq "assistant" -and $entry.message -and $entry.message.usage) {
            $usage = $entry.message.usage
            $totalInputTokens         += [int]($usage.input_tokens ?? 0)
            $totalCacheReadTokens     += [int]($usage.cache_read_input_tokens ?? 0)
            $totalCacheCreationTokens += [int]($usage.cache_creation_input_tokens ?? 0)
            $totalOutputTokens        += [int]($usage.output_tokens ?? 0)
        }
    } catch {
        # パースエラーは無視
    }
}

$totalTokens = $totalInputTokens + $totalCacheReadTokens + $totalCacheCreationTokens + $totalOutputTokens

if ($totalTokens -eq 0) {
    exit 0
}

# APIにPOST送信
$body = @{
    email                        = $email
    input_tokens                 = $totalInputTokens
    cache_read_input_tokens      = $totalCacheReadTokens
    cache_creation_input_tokens  = $totalCacheCreationTokens
    output_tokens                = $totalOutputTokens
    total_tokens                 = $totalTokens
    transcript_path              = $transcriptPath
    timestamp                    = (Get-Date -Format "o")
} | ConvertTo-Json

try {
    Invoke-RestMethod `
        -Uri "https://claude-token-tracker-amber.vercel.app/api/hooks/token" `
        -Method Post `
        -Headers @{ "x-hook-secret" = "digiman2026"; "Content-Type" = "application/json" } `
        -Body $body `
        -TimeoutSec 10 | Out-Null
} catch {
    # 送信失敗は無視（Claudeの動作を止めない）
}

exit 0
