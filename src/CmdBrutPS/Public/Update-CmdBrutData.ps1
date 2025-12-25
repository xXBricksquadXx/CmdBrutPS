function Update-CmdBrutData {
    [CmdletBinding()]
    param(
        # Folder that contains a `pages` directory (e.g. .\vendor\tldr\pages OR a tldr repo root)
        [Parameter()]
        [string] $TldrSourcePath,

        # Optional: a zip that contains `pages/...` inside it (no network; you provide the zip)
        [Parameter()]
        [string] $TldrZipPath,

        # Copy into %LOCALAPPDATA%\CmdBrutPS\tldr\pages
        [Parameter()]
        [bool] $InstallToCache = $true,

        # Rebuild %LOCALAPPDATA%\CmdBrutPS\index.json from local tldr pages
        [Parameter()]
        [bool] $RebuildIndex = $true
    )

    $cacheRoot = Join-Path $env:LOCALAPPDATA 'CmdBrutPS'
    $tldrDest = Join-Path $cacheRoot 'tldr\pages'
    $indexPath = Join-Path $cacheRoot 'index.json'

    if (-not (Test-Path $cacheRoot)) { New-Item -ItemType Directory -Path $cacheRoot -Force | Out-Null }
    if (-not (Test-Path $tldrDest)) { New-Item -ItemType Directory -Path $tldrDest  -Force | Out-Null }

    # Resolve a source path automatically if not provided
    if (-not $TldrSourcePath) {
        $candidates = @()
        if ($script:RepoRoot) {
            $candidates += (Join-Path $script:RepoRoot 'vendor\tldr\pages')
            $candidates += (Join-Path $script:RepoRoot 'tldr\pages')
            $candidates += (Join-Path $script:RepoRoot 'data\tldr\pages')
        }
        foreach ($p in $candidates) {
            if (Test-Path $p) { $TldrSourcePath = $p; break }
        }
    }

    # If source is a repo root, allow pointing at it and auto-append \pages
    if ($TldrSourcePath -and (Test-Path $TldrSourcePath)) {
        $maybePages = Join-Path $TldrSourcePath 'pages'
        if (Test-Path $maybePages) { $TldrSourcePath = $maybePages }
    }

    # 1) Install pages into cache (from zip or folder)
    if ($InstallToCache) {
        if ($TldrZipPath) {
            if (-not (Test-Path $TldrZipPath)) { throw "Zip not found: $TldrZipPath" }

            $tmp = Join-Path $env:TEMP ("cmdbrut_tldr_" + [guid]::NewGuid().ToString('n'))
            New-Item -ItemType Directory -Path $tmp -Force | Out-Null

            Expand-Archive -Path $TldrZipPath -DestinationPath $tmp -Force

            # Find `pages` inside the extracted tree
            $pages = Get-ChildItem -Path $tmp -Directory -Recurse -Filter 'pages' -ErrorAction SilentlyContinue |
            Select-Object -First 1
            if (-not $pages) { throw "Zip did not contain a 'pages' folder: $TldrZipPath" }

            Copy-Item -Path (Join-Path $pages.FullName '*') -Destination $tldrDest -Recurse -Force
            Remove-Item -Path $tmp -Recurse -Force -ErrorAction SilentlyContinue
        }
        elseif ($TldrSourcePath) {
            if (-not (Test-Path $TldrSourcePath)) { throw "Tldr source not found: $TldrSourcePath" }

            # Copy CONTENTS of pages -> cache pages (so cache has common/linux/... directly)
            Copy-Item -Path (Join-Path $TldrSourcePath '*') -Destination $tldrDest -Recurse -Force
        }
        else {
            throw "No tldr source found. Provide -TldrSourcePath (folder containing pages) or -TldrZipPath."
        }
    }

    # 2) Rebuild local index
    if ($RebuildIndex) {
        if (-not (Test-Path $tldrDest)) {
            throw "No local tldr pages at $tldrDest. Run Update-CmdBrutData -InstallToCache first."
        }

        $platformPriority = @{
            common  = 0
            linux   = 1
            osx     = 2
            windows = 3
            sunos   = 4
        }

        $files = Get-ChildItem -Path $tldrDest -Filter '*.md' -Recurse -File -ErrorAction SilentlyContinue
        $best = @{} # name -> object (prefer common/linux)

        foreach ($f in $files) {
            $platform = Split-Path -Leaf (Split-Path -Parent $f.FullName)
            $name = [IO.Path]::GetFileNameWithoutExtension($f.Name)
            if (-not $name) { continue }

            $lines = Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue
            $descLines = @()
            foreach ($ln in $lines) {
                if ($ln -like '> *') { $descLines += ($ln -replace '^>\s*', '').Trim() }
                elseif ($descLines.Count -gt 0) { break }
            }
            $desc = ($descLines -join ' ').Trim()

            $obj = [pscustomobject]@{
                Name        = $name
                Description = $desc
                Platform    = $platform
                Path        = $f.FullName
                Source      = 'tldr'
            }

            if (-not $best.ContainsKey($name)) { $best[$name] = $obj; continue }

            $cur = $best[$name]
            $pNew = $platformPriority[$platform]
            $pCur = $platformPriority[$cur.Platform]
            if ($pNew -lt $pCur) { $best[$name] = $obj }
        }

        $index = $best.Values | Sort-Object Name
        $index | ConvertTo-Json -Depth 4 | Set-Content -Path $indexPath -Encoding UTF8

        [pscustomobject]@{
            TldrPages = $tldrDest
            IndexPath = $indexPath
            Count     = $index.Count
        }
    }
}
