# Install the 4-brain skill for Claude Code (Windows).
#   ./install.ps1          directory junction (repo stays source of truth; git pull updates it)
#   ./install.ps1 -Copy    independent copy
param([switch]$Copy)

$ErrorActionPreference = "Stop"
$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Src     = Join-Path $RepoDir "skill"
$DestDir = if ($env:CLAUDE_SKILLS_DIR) { $env:CLAUDE_SKILLS_DIR } else { Join-Path $env:USERPROFILE ".claude\skills" }
$Dest    = Join-Path $DestDir "4-brain"

if (-not (Test-Path (Join-Path $Src "SKILL.md"))) {
  Write-Error "skill\SKILL.md not found - run this from the repo root."
}
if (-not (Test-Path $DestDir)) { New-Item -ItemType Directory -Force -Path $DestDir | Out-Null }

if (Test-Path $Dest) {
  Write-Host "removing existing $Dest"
  # A junction must be removed with rmdir, not Remove-Item -Recurse (which can
  # follow the link and delete the repo contents on older PowerShell).
  cmd /c rmdir "$Dest" 2>$null
  if (Test-Path $Dest) { Remove-Item -Recurse -Force $Dest }
}

if ($Copy) {
  Copy-Item -Recurse $Src $Dest
  Write-Host "installed (copy) -> $Dest"
} else {
  cmd /c mklink /J "$Dest" "$Src" | Out-Null
  Write-Host "installed (junction) -> $Dest -> $Src"
}

Write-Host ""
Write-Host "Brains detected:"
# Some CLIs install to a per-user dir that is on the shell PATH Claude Code uses
# but not on PowerShell's, so probe known locations before declaring one missing.
$fallbacks = @{
  codex  = @("$env:USERPROFILE\.codex\bin\codex.exe",  "$env:USERPROFILE\.codex\bin\codex")
  gemini = @("$env:USERPROFILE\.gemini\bin\gemini.exe","$env:USERPROFILE\.gemini\bin\gemini")
  grok   = @("$env:USERPROFILE\.grok\bin\grok.exe",    "$env:USERPROFILE\.grok\bin\grok")
}
foreach ($cli in @("codex","gemini","grok")) {
  $exe = (Get-Command $cli -ErrorAction SilentlyContinue).Source
  if (-not $exe) { $exe = $fallbacks[$cli] | Where-Object { Test-Path $_ } | Select-Object -First 1 }
  if ($exe) {
    $ver = try { (& $exe --version 2>&1 | Select-Object -First 1) } catch { "installed" }
    "  {0,-7} {1}" -f $cli, $ver | Write-Host
  } else {
    "  {0,-7} not found (that route will be skipped)" -f $cli | Write-Host
  }
}
Write-Host ""
Write-Host "Done. Start Claude Code and run: /4-brain"
exit 0
