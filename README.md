# CmdBrutPS

Neo‑brutalist command lookup for PowerShell.

- **TLDR (offline)**: fast command cheatsheets from a local `tldr/pages/**` checkout (installed to a cache on first run).
- **PowerShell (local)**: search `Get-Command` and view docs via `Get-Help`.

## What you get

### Commands

- `Find-CmdBrut` — search commands (TLDR index or PowerShell commands)
- `Get-CmdBrutDoc` — show docs (TLDR markdown or `Get-Help -Full` output)
- `Update-CmdBrutData` — install/update TLDR pages **from a zip or folder** and rebuild a local index

### Offline-first storage

CmdBrutPS stores its local cache here:

- `%LOCALAPPDATA%\CmdBrutPS\tldr\pages\...`
- `%LOCALAPPDATA%\CmdBrutPS\index.json`

## Install (from source repo)

From the repo root:

```powershell
# Import directly from the manifest
Import-Module (Resolve-Path .\src\CmdBrutPS\CmdBrutPS.psd1) -Force

# Confirm exports
Get-Command -Module CmdBrutPS | Select-Object Name
```

## Quickstart

### 1) Get TLDR pages (zip) and build the index

Download TLDR as a zip and place it in the repo (recommended location):

```powershell
$dst = Join-Path (Resolve-Path .).Path "vendor\tldr\tldr.zip"
New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
Invoke-WebRequest -Uri "https://codeload.github.com/tldr-pages/tldr/zip/refs/heads/main" -OutFile $dst

# Install to cache + rebuild local index
Update-CmdBrutData -TldrZipPath .\vendor\tldr\tldr.zip -InstallToCache $true -RebuildIndex $true
```

### 2) Search TLDR (offline)

```powershell
Find-CmdBrut tar -Top 10
Get-CmdBrutDoc tar | Select-Object -First 40
```

### 3) Search PowerShell commands + show help

```powershell
Find-CmdBrut net -Mode PowerShell -Top 10
Get-CmdBrutDoc Get-Process -Mode PowerShell | Select-Object -First 40
```

## Usage notes

### Auto mode

Both `Find-CmdBrut` and `Get-CmdBrutDoc` default to `-Mode Auto`:

- If the input looks like `Verb-Noun` **and** exists locally, CmdBrutPS uses **PowerShell mode**.
- Otherwise it uses **TLDR mode**.

### Updating PowerShell help

If you want richer `Get-Help` output (examples, full docs), you can run this while online:

```powershell
Update-Help
```

CmdBrutPS will still work without it (you’ll just see partial help in some cases).

## Repo layout

```text
src/
  CmdBrutPS/
    CmdBrutPS.psd1        # manifest
    CmdBrutPS.psm1        # module entry
    Public/
      Find-CmdBrut.ps1
      Get-CmdBrutDoc.ps1
      Update-CmdBrutData.ps1
    Private/
      ...
vendor/
  tldr/
    tldr.zip              # optional local zip (recommended to .gitignore)
```

## Roadmap

- Add Pester tests
- CI (GitHub Actions)
- Distribution (PSGallery or a release zip)
- Optional: split a separate “data + website” repo for hosted browsing

## ProjectUri (later)

When you’re ready, add your GitHub URL to the manifest at:

```powershell
PrivateData = @{
  PSData = @{
    ProjectUri = 'https://github.com/<you>/<repo>'
  }
}
```

## Attribution

TLDR content is sourced from the `tldr-pages/tldr` community project (when you download/build the local cache).
