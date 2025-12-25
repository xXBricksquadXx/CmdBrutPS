function Find-CmdBrut {
  [CmdletBinding()]
  param(
    [Parameter(Position = 0, Mandatory = $true)]
    [string] $Query,

    [Parameter()]
    [int] $Top = 20,

    [Parameter()]
    [ValidateSet('Auto', 'Tldr', 'PowerShell')]
    [string] $Mode = 'Auto',

    # Only return exact Name matches (case-insensitive)
    [Parameter()]
    [switch] $Exact,

    # Only return Name starts-with matches (case-insensitive)
    [Parameter()]
    [switch] $StartsWith
  )

  $q = ($Query ?? '').Trim()
  if (-not $q) { return }

  # If both are set, Exact wins.
  if ($Exact) { $StartsWith = $false }

  # Auto mode: prefer PowerShell when query looks like Verb-Noun and exists
  if ($Mode -eq 'Auto') {
    if ($q -match '^[A-Za-z]+\-[A-Za-z]+' -and (Get-Command -Name $q -ErrorAction SilentlyContinue)) {
      $Mode = 'PowerShell'
    }
    else {
      $Mode = 'Tldr'
    }
  }

  if ($Mode -eq 'PowerShell') {
    if ($Exact) {
      Get-Command -Name $q -ErrorAction SilentlyContinue | Select-Object -First $Top
      return
    }

    $pattern = if ($StartsWith) { "$q*" } else { "*$q*" }

    Get-Command -Name $pattern -ErrorAction SilentlyContinue |
    Sort-Object Name |
    Select-Object -First $Top
    return
  }

  # ---- TLDR (offline) search ----
  $indexPaths = @(
    (Join-Path $env:LOCALAPPDATA 'CmdBrutPS\index.json')
  )

  # Also try repo-root data\index.json when running from source checkout
  try {
    $moduleRoot = Split-Path -Parent $PSScriptRoot           # ...\src\CmdBrutPS\Public -> ...\src\CmdBrutPS
    $repoRoot = Resolve-Path (Join-Path $moduleRoot '..\..') -ErrorAction Stop
    $indexPaths += (Join-Path $repoRoot.Path 'data\index.json')
  }
  catch { }

  $rawIndex = $null
  foreach ($p in $indexPaths) {
    if (Test-Path $p) {
      try {
        $rawIndex = Get-Content -Raw -LiteralPath $p -ErrorAction Stop | ConvertFrom-Json
        break
      }
      catch { }
    }
  }

  if (-not $rawIndex) {
    Write-Error "No offline index found. Run Update-CmdBrutData (-TldrZipPath or -TldrSourcePath) to build index.json."
    return
  }

  # Normalize entries to {Name, Description, Platform, Path, Source}
  $norm = foreach ($it in @($rawIndex)) {
    if (-not $it) { continue }

    $name =
    if ($it.PSObject.Properties['Name']) { [string]$it.Name }
    elseif ($it.PSObject.Properties['n']) { [string]$it.n }
    elseif ($it.PSObject.Properties['Command']) { [string]$it.Command }
    else { $null }

    if (-not $name) { continue }

    $desc =
    if ($it.PSObject.Properties['Description']) { [string]$it.Description }
    elseif ($it.PSObject.Properties['d']) { [string]$it.d }
    else { '' }

    $platform =
    if ($it.PSObject.Properties['Platform']) { [string]$it.Platform }
    elseif ($it.PSObject.Properties['p']) { [string]$it.p }
    else { '' }

    $path =
    if ($it.PSObject.Properties['Path']) { [string]$it.Path }
    else { '' }

    $source =
    if ($it.PSObject.Properties['Source']) { [string]$it.Source }
    else { 'tldr' }

    [pscustomobject]@{
      Name        = $name
      Description = $desc
      Platform    = $platform
      Path        = $path
      Source      = $source
    }
  }

  $ql = $q.ToLowerInvariant()

  if ($Exact) {
    $norm |
    Where-Object { $_.Name -and $_.Name.ToLowerInvariant() -eq $ql } |
    Select-Object -First $Top
    return
  }

  if ($StartsWith) {
    $norm |
    Where-Object { $_.Name -and $_.Name.ToLowerInvariant().StartsWith($ql) } |
    Sort-Object Name |
    Select-Object -First $Top
    return
  }

  # Scoring: Name hits dominate; description hits are weak (to avoid "star(ted)" beating "tar")
  $scored = foreach ($it in $norm) {
    $n = ([string]$it.Name).ToLowerInvariant()
    $d = ([string]$it.Description).ToLowerInvariant()

    $nameExact = ($n -eq $ql)
    $namePrefix = ($n.StartsWith($ql))
    $ni = $n.IndexOf($ql)
    $di = $d.IndexOf($ql)

    if (-not $nameExact -and -not $namePrefix -and $ni -lt 0 -and $di -lt 0) { continue }

    $score = 0

    if ($nameExact) { $score += 5000 }
    elseif ($namePrefix) { $score += 3500 }

    if ($ni -ge 0) { $score += 1200 + (300 - [Math]::Min($ni, 300)) }

    # Description matches only matter when name didn't match strongly
    if ($di -ge 0) {
      $score += 80 + (80 - [Math]::Min($di, 80))
    }

    [pscustomobject]@{ Score = $score; Item = $it }
  }

  $scored |
  Sort-Object Score -Descending |
  Select-Object -First $Top |
  ForEach-Object { $_.Item }
}
