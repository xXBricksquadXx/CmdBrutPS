# CmdBrutPS

Neo‑brutalist command lookup for PowerShell: **offline TLDR cheatsheets** plus **local PowerShell help**.

**GitHub About (paste-ready):** Offline-first PowerShell command lookup that searches TLDR pages or local Get-Command output and renders docs via TLDR markdown or Get-Help.

---

## What this is

CmdBrutPS is a PowerShell module that gives you a fast, minimal UI for:
- finding commands (either TLDR pages or PowerShell commands)
- reading docs (TLDR markdown or `Get-Help -Full`)
- keeping an offline TLDR cache updated on your machine

CmdBrutPS keeps data **out of the repo** by default and uses a local cache so it works when you’re offline.

---

## Commands

- **`Find-CmdBrut`** — search commands (TLDR index or PowerShell commands)
- **`Get-CmdBrutDoc`** — show docs (TLDR markdown or `Get-Help -Full`)
- **`Update-CmdBrutData`** — install/update TLDR pages from a **zip or folder** and rebuild a local index

---

## Offline-first cache

CmdBrutPS stores its local TLDR pages + search index here:

- `%LOCALAPPDATA%\CmdBrutPS\tldr\pages\...`
- `%LOCALAPPDATA%\CmdBrutPS\index.json`

If you want to reset everything, you can delete `%LOCALAPPDATA%\CmdBrutPS\` and rebuild with `Update-CmdBrutData`.

---

## Install (from this repo)

From the repo root:

```powershell
# Import directly from the manifest
Import-Module (Resolve-Path .\src\CmdBrutPS\CmdBrutPS.psd1) -Force

# Confirm exports
Get-Command -Module CmdBrutPS | Select-Object Name
```

---

## Quickstart

### 1) Download TLDR pages (zip) and build the local index

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

---

## How mode selection works

Both `Find-CmdBrut` and `Get-CmdBrutDoc` default to `-Mode Auto`:

- If the input looks like `Verb-Noun` **and** exists locally, CmdBrutPS uses **PowerShell mode**.
- Otherwise it uses **TLDR mode**.

---

## Updating PowerShell help (optional)

If you want richer `Get-Help` output (examples, full docs), run this while online:

```powershell
Update-Help
```

CmdBrutPS still works without it (you’ll just see partial help in some cases).

---

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

---

## Roadmap (short)

- Pester tests
- CI (GitHub Actions)
- Distribution (PSGallery or a release zip)
- Optional: split “data + browser UI” into a separate repo (CmdBrutData)

---

## Attribution

TLDR content is sourced from the `tldr-pages/tldr` community project when you download/build the local cache.
