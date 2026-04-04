#!/usr/bin/env bash
# Eyeball setup script
# Installs Python dependencies and Playwright browsers for the Eyeball skill.

set -e

echo "Setting up Eyeball..."
echo ""

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is required but not found."
    echo "Install Python 3 from https://python.org or via your package manager."
    exit 1
fi

PYTHON_VERSION=$(python3 --version 2>&1)
echo "Found $PYTHON_VERSION"

# Install Python dependencies
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REQUIREMENTS="$SCRIPT_DIR/requirements.txt"

echo ""
echo "Installing Python dependencies..."
pip3 install -r "$REQUIREMENTS" --quiet 2>&1 | grep -v "already satisfied" || true
echo "Python dependencies installed."

# Install Playwright Chromium (for web page screenshots)
echo ""
echo "Installing Playwright Chromium browser (for web page support)..."
python3 -m playwright install chromium --quiet 2>&1 || python3 -m playwright install chromium 2>&1 | tail -3
echo "Playwright browser installed."

# Check document conversion capability
echo ""
echo "Checking document conversion tools..."

CONVERTER_FOUND=false

# macOS: Check for Microsoft Word
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ -d "/Applications/Microsoft Word.app" ]; then
        echo "  Found: Microsoft Word (macOS) -- will use for .docx to PDF conversion"
        CONVERTER_FOUND=true
    fi
fi

# Any platform: Check for LibreOffice
if command -v libreoffice &> /dev/null || command -v soffice &> /dev/null; then
    echo "  Found: LibreOffice -- will use for .docx to PDF conversion"
    CONVERTER_FOUND=true
fi

if [ "$CONVERTER_FOUND" = false ]; then
    echo "  WARNING: No document converter found."
    echo "  To convert .docx files, install Microsoft Word (macOS/Windows) or LibreOffice (any platform)."
    echo "  PDF files and web URLs will still work without a converter."
fi

echo ""
echo "Setup complete."
echo ""
echo "Supported source types:"
echo "  - PDF files: Ready"
echo "  - Web URLs: Ready (via Playwright)"
if [ "$CONVERTER_FOUND" = true ]; then
    echo "  - Word docs (.docx): Ready"
else
    echo "  - Word docs (.docx): Needs Microsoft Word or LibreOffice"
fi
