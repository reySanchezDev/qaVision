param(
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

function Invoke-Step {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [Parameter(Mandatory = $true)]
    [scriptblock]$Command
  )

  Write-Host ""
  Write-Host "==> $Name"
  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "$Name failed with exit code $LASTEXITCODE"
  }
}

Invoke-Step "flutter pub get" {
  flutter pub get
}

Invoke-Step "flutter analyze --no-pub" {
  flutter analyze --no-pub
}

Invoke-Step "flutter test --concurrency 1" {
  flutter test --concurrency 1
}

if (-not $SkipBuild) {
  Invoke-Step "flutter build windows --no-pub" {
    flutter build windows --no-pub
  }
}

Write-Host ""
Write-Host "Validation completed."
