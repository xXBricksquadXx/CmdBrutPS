Set-StrictMode -Version Latest

# Module-scoped paths
$script:ModuleRoot = $PSScriptRoot
$script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..') -ErrorAction SilentlyContinue

# Cache root (offline store)
$script:CacheRoot = Join-Path $env:LOCALAPPDATA 'CmdBrutPS'
$script:TldrCache = Join-Path $script:CacheRoot 'tldr\pages'
$script:IndexCache = Join-Path $script:CacheRoot 'index.json'

# Load functions
$public = Join-Path $PSScriptRoot 'Public'
$private = Join-Path $PSScriptRoot 'Private'

Get-ChildItem -Path $private -Filter '*.ps1' -ErrorAction SilentlyContinue | ForEach-Object { . $_.FullName }
Get-ChildItem -Path $public  -Filter '*.ps1' -ErrorAction SilentlyContinue | ForEach-Object { . $_.FullName }

Export-ModuleMember -Function Find-CmdBrut, Get-CmdBrutDoc, Update-CmdBrutData
