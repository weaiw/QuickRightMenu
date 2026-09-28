# QuickRightMenu

QuickRightMenu is a lightweight macOS Finder right-click menu extension. It provides quick file creation, copy/move actions, file utilities, image tools, text tools, terminal launch, and an in-app settings window.

The app is implemented with Objective-C and FinderSync, with a small resident menu bar app that executes commands requested by the Finder extension.

## Features

- Context-aware menus: show tools matching the selected file types; pin actions and adjust their order
- Create TXT, Markdown, JSON, CSV, HTML, YAML, XML, Shell, Python, JavaScript, TypeScript, CSS and Office files
- Save clipboard text as TXT/Markdown or clipboard images as PNG
- Import file/folder templates, including Office documents; create a project folder with documents, assets and output folders
- Copy paths, names, parent directories, file URLs and Markdown links
- Copy/move files to system folders, three favorite folders or a chosen destination
- Open files/folders in VS Code, Cursor, a preferred app or a selected app; Terminal/iTerm2/Warp preferences
- Batch rename with prefix/suffix, find-and-replace, date or numbering; preview and conflict checks before applying
- Image dimensions, PNG/JPEG/WebP conversion, resizing, target-size JPEG compression, metadata removal and text watermarks
- Save image processing combinations: size, format, target bytes, metadata, watermark and output directory
- Combine images into a PDF, merge PDF documents, and recognize Chinese/English text from images locally
- Copy a directory tree or export a Markdown/CSV file inventory
- Text statistics, UTF-8 conversion and plain-text preview
- Background batch processing, cancellation, per-file results and guarded undo for the most recent move/rename batch
- Menu settings, login item, permission guide and GitHub Release update checks

### Behavior and limits (1.6.0)

- The settings window has **菜单**, **文件模板**, **打开方式** and **处理组合** pages. Existing feature switches, templates and favorites are preserved on upgrade. Reset Menu resets only menu preferences.
- Pinned actions appear at the top. Other actions remain grouped; ordering affects actions within their group and groups by their first action. Mixed selections hide tools that cannot handle every selected item.
- Image/PDF/text exports and template creation keep originals and choose an unused output name. Resizing and metadata-removal shortcuts save PNG files; target-size compression saves JPEG. Animated/multipage images use their first frame.
- A target of 1 MB means 1,000,000 bytes. JPEG compression may lower quality and dimensions to reach it. If the target cannot be met, the operation reports a failure and does not save an oversized result. JPEG uses a white background for transparent pixels.
- Image processing combinations always produce a new image, in the chosen directory or an `已处理` folder beside each original. Watermarks are placed at the bottom. WebP writing depends on the macOS ImageIO encoder and reports an error if unavailable.
- Imported templates are copied into managed storage. Removing a template sends its managed copy to Trash; the source file is unchanged. The built-in project template creates `文档`, `素材`, `输出` and `README.md`.
- PDFs are merged in natural filename order. Encrypted/empty/unreadable PDFs fail without altering inputs. OCR runs through Apple Vision on the Mac; no image is sent to an external service.
- Inventories include hidden entries and do not traverse symbolic links or package contents. CSV fields are quoted and formula-like leading text is escaped for spreadsheet safety.
- Cancellation stops later items; an in-progress file copy or OCR request finishes first. Successful earlier items remain. PDF creation and inventory export are single output jobs.
- Undo covers the most recent successful move/rename batch **in this app session**. It refuses changed/replaced files and occupied original paths; failed undo entries can be retried. It is not a persistent undo history.
- External `quickrightmenu://` requests require confirmation; normal Finder command-file actions do not.

## Build

Requirements:

- macOS 13 or later
- Xcode Command Line Tools
- Python 3 with Pillow, used only to regenerate the app icon

Build:

```bash
./scripts/build.sh
```

The built app is generated at:

```text
build/QuickRightMenu.app
```

## Checks

```bash
./scripts/check.sh
```

The native assertion-based check uses temporary fixtures and a separate pasteboard. It exercises menu filtering/order and Finder-to-app command routing, settings persistence, clipboard export, rename/undo conflicts, templates, image output and metadata, PDF page counts, Chinese/English OCR, inventories, batch results and cancellation. It does not install or enable the Finder extension.

To inspect the settings UI using isolated temporary settings:

```bash
./scripts/check.sh --ui
```

## Install Locally

For most users, download the latest `QuickRightMenu-*-macOS.zip` from GitHub Releases, unzip it, move `QuickRightMenu.app` to `/Applications`, open it once, then enable the Finder extension in System Settings if macOS asks.

On first launch, QuickRightMenu opens a permission guide inside the app. Follow it to enable the Finder extension, add Full Disk Access, and restart Finder.

QuickRightMenu also checks GitHub Releases for updates at launch and shows an in-app update page when a newer version is available.

For local development builds:

Copy the built app somewhere stable, then register and enable the FinderSync extension:

```bash
cp -R build/QuickRightMenu.app /Applications/QuickRightMenu.app
pluginkit -a "/Applications/QuickRightMenu.app/Contents/PlugIns/QuickRightMenu Extension.appex"
pluginkit -e use -i com.liaowenbin.QuickRightMenu.Extension
open /Applications/QuickRightMenu.app
killall Finder
```

If macOS still does not show the menu, check:

```bash
pluginkit -m -p com.apple.FinderSync -v
```

## Architecture

FinderSync extensions are sandboxed and are unreliable for directly launching arbitrary workflows from menu actions. QuickRightMenu uses a command-file bridge:

1. The FinderSync extension writes a `.cmd` file into the shared app container.
2. The menu bar app polls that folder.
3. The menu bar app validates the command and performs file operations in background batches.

`Sources/Shared/QRFeatures.h` defines stable feature keys, menu actions and context rules for both processes. `Sources/App/QRFileOperations.m` contains file/image/PDF/OCR operations, shared by the app and executable checks. Paths in new commands use a JSON array so filenames containing newlines survive the bridge; legacy newline-delimited commands remain readable.

This keeps Finder menu handling small and avoids depending on blocked `openURL` or distributed notification behavior inside FinderSync.

## Notes

- Bundle identifiers intentionally use `QuickRightMenu` for compatibility with existing local settings and FinderSync registration.
- The user-facing product name is `QuickRightMenu`.
- Office files are generated as minimal valid OpenXML packages.

## License

MIT
