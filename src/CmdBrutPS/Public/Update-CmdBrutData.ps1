function Update-CmdBrutData {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        # Folder that contains a `pages` directory (e.g. .\vendor\tldr\pages OR a tldr repo root)
        [Parameter()]
        [string] $TldrSourcePath,

        [Parameter()]
        [string] $TldrZipPath,

        # Copy into %LOCALAPPDATA%\CmdBrutPS\tldr\pages
        # Default behavior: ON (unless explicitly passed -InstallToCache:$false)
        [Parameter()]
        [switch] $InstallToCache,

        # Rebuild %LOCALAPPDATA%\CmdBrutPS\index.json from local tldr pages
        # Default behavior: ON (unless explicitly passed -RebuildIndex:$false)
        [Parameter()]
        [switch] $RebuildIndex
    )

    # Keep prior behavior (both actions default to ON), but avoid "switch defaults to true" analyzer warnings
    $doInstall = $true
    if ($PSBoundParameters.ContainsKey('InstallToCache')) { $doInstall = [bool]$InstallToCache }

    $doRebuild = $true
    if ($PSBoundParameters.ContainsKey('RebuildIndex')) { $doRebuild = [bool]$RebuildIndex }

    $cacheRoot = Join-Path $env:LOCALAPPDATA 'CmdBrutPS'
    $tldrDest = Join-Path $cacheRoot 'tldr\pages'
    $indexPath = Join-Path $cacheRoot 'index.json'

    if (-not (Test-Path -LiteralPath $cacheRoot)) { New-Item -ItemType Directory -Path $cacheRoot -Force | Out-Null }
    if (-not (Test-Path -LiteralPath $tldrDest)) { New-Item -ItemType Directory -Path $tldrDest  -Force | Out-Null }

    # Resolve a source path automatically if not provided
    if (-not $TldrSourcePath) {
        $candidates = @()
        if ($script:RepoRoot) {
            $candidates += (Join-Path $script:RepoRoot 'vendor\tldr\pages')
            $candidates += (Join-Path $script:RepoRoot 'tldr\pages')
            $candidates += (Join-Path $script:RepoRoot 'data\tldr\pages')
        }
        foreach ($p in $candidates) {
            if (Test-Path -LiteralPath $p) { $TldrSourcePath = $p; break }
        }
    }

    # If source is a repo root, allow pointing at it and auto-append \pages
    if ($TldrSourcePath -and (Test-Path -LiteralPath $TldrSourcePath)) {
        $maybePages = Join-Path $TldrSourcePath 'pages'
        if (Test-Path -LiteralPath $maybePages) { $TldrSourcePath = $maybePages }
    }

    # ---- helpers (avoid wildcard issues with pages like "[.md" and "[[.md") ----
    function Copy-DirectoryContents {
        param(
            [Parameter(Mandatory = $true)] [string] $FromDir,
            [Parameter(Mandatory = $true)] [string] $ToDir
        )

        $items = Get-ChildItem -LiteralPath $FromDir -Force -ErrorAction Stop
        foreach ($it in $items) {
            if ($PSCmdlet.ShouldProcess($ToDir, "Copy '$($it.FullName)'")) {
                Copy-Item -LiteralPath $it.FullName -Destination $ToDir -Recurse -Force
            }
        }
    }

    # 1) Install pages into cache (from zip or folder)
    if ($doInstall) {
        if ($TldrZipPath) {
            if (-not (Test-Path -LiteralPath $TldrZipPath)) { throw "Zip not found: $TldrZipPath" }

            $tmp = Join-Path $env:TEMP ("cmdbrut_tldr_" + [guid]::NewGuid().ToString('n'))
            New-Item -ItemType Directory -Path $tmp -Force | Out-Null

            try {
                Expand-Archive -LiteralPath $TldrZipPath -DestinationPath $tmp -Force

                # Find `pages` inside the extracted tree
                $pages = Get-ChildItem -LiteralPath $tmp -Directory -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -eq 'pages' } |
                Select-Object -First 1

                if (-not $pages) { throw "Zip did not contain a 'pages' folder: $TldrZipPath" }

                # Copy CONTENTS of pages -> cache pages (so cache has common/linux/... directly)
                Copy-DirectoryContents -FromDir $pages.FullName -ToDir $tldrDest
            }
            finally {
                if ($PSCmdlet.ShouldProcess($tmp, "Remove temp extract folder")) {
                    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
        elseif ($TldrSourcePath) {
            if (-not (Test-Path -LiteralPath $TldrSourcePath)) { throw "Tldr source not found: $TldrSourcePath" }

            # Copy CONTENTS of pages -> cache pages (so cache has common/linux/... directly)
            Copy-DirectoryContents -FromDir $TldrSourcePath -ToDir $tldrDest
        }
        else {
            throw "No tldr source found. Provide -TldrSourcePath (folder containing pages) or -TldrZipPath."
        }
    }

    # 2) Rebuild local index
    if ($doRebuild) {
        if (-not (Test-Path -LiteralPath $tldrDest)) {
            throw "No local tldr pages at $tldrDest. Run Update-CmdBrutData -InstallToCache first."
        }

        $platformPriority = @{
            common  = 0
            linux   = 1
            osx     = 2
            windows = 3
            sunos   = 4
            freebsd = 5
            openbsd = 6
            netbsd  = 7
            android = 8
        }

        $files = Get-ChildItem -LiteralPath $tldrDest -Recurse -File -Filter '*.md' -ErrorAction SilentlyContinue
        $best = @{} # name -> object (prefer common/linux)

        foreach ($f in $files) {
            $platform = Split-Path -Leaf (Split-Path -Parent $f.FullName)
            $name = [IO.Path]::GetFileNameWithoutExtension($f.Name)
            if (-not $name) { continue }

            # Only read the top of the file to extract the blockquote summary
            $lines = Get-Content -LiteralPath $f.FullName -TotalCount 60 -ErrorAction SilentlyContinue
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
            $pNew = if ($platformPriority.ContainsKey($platform)) { $platformPriority[$platform] } else { 99 }
            $pCur = if ($platformPriority.ContainsKey($cur.Platform)) { $platformPriority[$cur.Platform] } else { 99 }

            if ($pNew -lt $pCur) { $best[$name] = $obj }
        }

        $index = $best.Values | Sort-Object Name
        $json = $index | ConvertTo-Json -Depth 4

        if ($PSCmdlet.ShouldProcess($indexPath, "Write index.json ($($index.Count) entries)")) {
            $json | Set-Content -LiteralPath $indexPath -Encoding UTF8
        }

        [pscustomobject]@{
            TldrPages = $tldrDest
            IndexPath = $indexPath
            Count     = $index.Count
        }
    }
}
