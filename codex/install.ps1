$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$SkillSource = Join-Path $RepoRoot 'skills'
$CodexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
$SkillDest = Join-Path $HOME '.agents\skills'
$ConfigDest = Join-Path $CodexHome 'config.toml'

New-Item -ItemType Directory -Force -Path $SkillDest, $CodexHome | Out-Null
Copy-Item -Path (Join-Path $SkillSource '*') -Destination $SkillDest -Recurse -Force

if (-not (Test-Path $ConfigDest)) {
    Copy-Item (Join-Path $RepoRoot 'codex\config.toml.example') $ConfigDest
    Write-Host "Created $ConfigDest"
} else {
    Write-Host "Kept existing $ConfigDest"
}

Write-Host "Installed Codex skills to $SkillDest"
Write-Host "Repository instructions remain in $(Join-Path $RepoRoot 'AGENTS.md')"
