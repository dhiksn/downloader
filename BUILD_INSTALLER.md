# Build RaiSaver Installer

## Prerequisites

1. Install Inno Setup from: https://jrsoftware.org/isdl.php
2. Build Flutter app first

## Steps to Build Installer

### 1. Build Flutter Windows App

```bash
flutter clean
flutter build windows --release
```

### 2. Compile Installer with Inno Setup

**Option A: Using Inno Setup GUI**
1. Open `installer.iss` with Inno Setup Compiler
2. Click "Build" menu → "Compile"
3. Installer will be created in `installer_output/` folder

**Option B: Using Command Line**
```bash
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss
```

### 3. Find Your Installer

The installer will be created at:
```
installer_output/RaiSaver_Setup_v1.0.0.exe
```

## Installer Features

- ✅ Modern wizard style
- ✅ Desktop shortcut option
- ✅ Start menu shortcuts
- ✅ Uninstaller included
- ✅ 64-bit support
- ✅ No admin rights required (installs to user folder)
- ✅ Compressed with LZMA

## Customization

Edit `installer.iss` to customize:
- `MyAppVersion` - Change version number
- `MyAppPublisher` - Change publisher name
- `MyAppURL` - Change website URL
- `SetupIconFile` - Change installer icon
- Add more languages in `[Languages]` section

## File Structure

```
RaiSaver/
├── installer.iss          # Inno Setup script
├── LICENSE                # License file (shown during install)
├── BUILD_INSTALLER.md     # This file
└── build/
    └── windows/
        └── x64/
            └── runner/
                └── Release/
                    ├── RaiSaver.exe
                    ├── *.dll
                    └── data/
```

## Troubleshooting

**Error: "Cannot find file"**
- Make sure you ran `flutter build windows --release` first
- Check that `build/windows/x64/runner/Release/RaiSaver.exe` exists

**Error: "Cannot find LICENSE"**
- Make sure `LICENSE` file exists in project root
- Or remove the `LicenseFile=LICENSE` line from installer.iss

**Want to skip license screen?**
- Remove or comment out the `LicenseFile=LICENSE` line in installer.iss
