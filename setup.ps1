$ErrorActionPreference = 'Stop'

Write-Host "Setting up Eyeball..."
Write-Host ""

# Find a usable Python 3
$python = $null
$pythonArgs = @()

foreach ($candidate in @(
    @{ Exe = "py"; Args = @("-3") },
    @{ Exe = "python"; Args = @() },
    @{ Exe = "python3"; Args = @() }
)) {
    $cmd = Get-Command $candidate.Exe -ErrorAction SilentlyContinue
    if (-not $cmd) { continue }

    try {
        $versionOutput = & $cmd.Source @($candidate.Args + @("--version")) 2>&1
        if ($LASTEXITCODE -eq 0 -and ($versionOutput | Select-Object -First 1) -match "^Python 3") {
            $python = $cmd.Source
            $pythonArgs = $candidate.Args
            break
        }
    } catch {}
}

if (-not $python) {
    Write-Host "ERROR: Python 3 is required but was not found."
    Write-Host "Install Python 3 from https://python.org"
    exit 1
}

$versionStr = & $python @($pythonArgs + @("--version")) 2>&1 | Select-Object -First 1
Write-Host "Found $versionStr"

# Install Python dependencies
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$requirements = Join-Path $scriptDir "requirements.txt"

if (-not (Test-Path $requirements)) {
    Write-Host "ERROR: requirements.txt not found at: $requirements"
    exit 1
}

Write-Host ""
Write-Host "Installing Python dependencies..."

& $python @($pythonArgs + @("-m", "pip", "install", "-r", $requirements, "--disable-pip-version-check", "--quiet"))
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to install Python dependencies."
    exit 1
}
Write-Host "Python dependencies installed."

# Install Playwright Chromium
Write-Host ""
Write-Host "Installing Playwright Chromium browser (for web page support)..."

& $python @($pythonArgs + @("-m", "playwright", "install", "chromium"))
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to install Playwright Chromium."
    exit 1
}
Write-Host "Playwright browser installed."

# Check document conversion capability
Write-Host ""
Write-Host "Checking document conversion tools..."

$converterFound = $false

# Windows: Check for Microsoft Word via registry
$wordFound = $false
$wordRegPaths = @(
    "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\WINWORD.EXE",
    "Registry::HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\WINWORD.EXE",
    "Registry::HKEY_CLASSES_ROOT\Word.Application"
)
foreach ($regPath in $wordRegPaths) {
    if (Test-Path $regPath) {
        $wordFound = $true
        break
    }
}

if ($wordFound) {
    # Check if pywin32 is available
    & $python @($pythonArgs + @("-c", "import win32com.client")) 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Found: Microsoft Word (Windows) -- will use for .docx to PDF conversion"
        $converterFound = $true
    } else {
        Write-Host "  Found: Microsoft Word (Windows), but pywin32 is not installed."
        Write-Host "  Word automation requires pywin32. It should have been installed with"
        Write-Host "  the other dependencies. If not, run:"
        Write-Host "    $python -m pip install pywin32"
    }
}

# Check for LibreOffice
$libreOffice = $null
foreach ($name in @("soffice", "libreoffice")) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { $libreOffice = $cmd.Source; break }
}
if (-not $libreOffice) {
    foreach ($envVar in @("ProgramFiles", "ProgramFiles(x86)")) {
        $base = [System.Environment]::GetEnvironmentVariable($envVar)
        if ($base) {
            $candidate = Join-Path $base "LibreOffice\program\soffice.exe"
            if (Test-Path $candidate) { $libreOffice = $candidate; break }
        }
    }
}
if ($libreOffice) {
    Write-Host "  Found: LibreOffice -- will use for .docx to PDF conversion"
    $converterFound = $true
}

if (-not $converterFound) {
    Write-Host "  WARNING: No document converter found."
    Write-Host "  To convert .docx files, install Microsoft Word or LibreOffice."
    Write-Host "  PDF files and web URLs will still work without a converter."
}

Write-Host ""
Write-Host "Setup complete."
Write-Host ""
Write-Host "Supported source types:"
Write-Host "  - PDF files: Ready"
Write-Host "  - Web URLs: Ready (via Playwright)"
if ($converterFound) {
    Write-Host "  - Word docs (.docx): Ready"
} else {
    Write-Host "  - Word docs (.docx): Needs Microsoft Word or LibreOffice"
}
