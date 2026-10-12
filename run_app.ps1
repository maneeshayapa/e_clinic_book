param(
    [ValidateSet("chrome", "android")]
    [Alias("Target")]
    [string]$Device = "chrome"
)

$ErrorActionPreference = "Stop"

$envFile = Join-Path $PSScriptRoot ".env.supabase"

if (-not (Test-Path $envFile)) {
    Write-Host "Missing .env.supabase file." -ForegroundColor Red
    exit 1
}

$values = @{}

Get-Content $envFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
        $parts = $line -split "=", 2
        $values[$parts[0].Trim()] = $parts[1].Trim()
    }
}

if (-not $values.ContainsKey("SUPABASE_URL") -or
    -not $values.ContainsKey("SUPABASE_ANON_KEY") -or
    [string]::IsNullOrWhiteSpace($values["SUPABASE_URL"]) -or
    [string]::IsNullOrWhiteSpace($values["SUPABASE_ANON_KEY"])) {
    Write-Host "Supabase URL or public key is missing." -ForegroundColor Red
    exit 1
}

$flutterDevice = if ($Device -eq "android") {
    "CNU765H006490715941"
} else {
    "chrome"
}
$dartDefines = @(
    "--dart-define=SUPABASE_URL=$($values['SUPABASE_URL'])"
    "--dart-define=SUPABASE_ANON_KEY=$($values['SUPABASE_ANON_KEY'])"
)

& flutter run -d $flutterDevice @dartDefines

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
