function Get-CmdBrutDoc {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string] $Name,

        [Parameter()]
        [ValidateSet('Auto', 'Tldr', 'PowerShell')]
        [string] $Mode = 'Auto'
    )

    $cmd = ($Name ?? '').Trim()
    if (-not $cmd) { return }

    if ($Mode -eq 'Auto') {
        if ($cmd -match '^[A-Za-z]+\-[A-Za-z]+' -and (Get-Command -Name $cmd -ErrorAction SilentlyContinue)) {
            $Mode = 'PowerShell'
        }
        else {
            $Mode = 'Tldr'
        }
    }

    if ($Mode -eq 'PowerShell') {
        $txt = (Get-Help $cmd -Full -ErrorAction SilentlyContinue | Out-String -Width 200).TrimEnd()
        if (-not $txt) {
            throw "No local help found for '$cmd'. (Optional: run Update-Help while online.)"
        }
        return $txt
    }

    # ---- TLDR (offline) doc lookup ----
    $roots = @()

    # Primary cache location
    $roots += (Join-Path $env:LOCALAPPDATA 'CmdBrutPS\tldr\pages')

    # Also support repo checkout locations (no install needed)
    try {
        $moduleRoot = Split-Path -Parent $PSScriptRoot
        $repoRoot = Resolve-Path (Join-Path $moduleRoot '..\..') -ErrorAction Stop
        $roots += (Join-Path $repoRoot.Path 'data\tldr\pages')
        $roots += (Join-Path $repoRoot.Path 'vendor\tldr\pages')
        $roots += (Join-Path $repoRoot.Path 'tldr\pages')
    }
    catch { }

    $platforms = @('common', 'linux', 'osx', 'windows', 'sunos')

    $docPath = $null

    foreach ($r in $roots) {
        if (-not (Test-Path $r)) { continue }

        foreach ($p in $platforms) {
            $candidate = Join-Path $r (Join-Path $p ($cmd + '.md'))
            if (Test-Path $candidate) { $docPath = $candidate; break }
        }
        if ($docPath) { break }

        # Fallback: find anywhere under pages
        $hit = Get-ChildItem -Path $r -Recurse -File -Filter ($cmd + '.md') -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hit) { $docPath = $hit.FullName; break }
    }

    if (-not $docPath) {
        throw "No offline tldr doc for '$cmd'. Put a tldr 'pages' folder somewhere and run Update-CmdBrutData to install/rebuild, or place it at: $($roots -join ', ')."
    }

    Get-Content -Raw -Path $docPath
}
