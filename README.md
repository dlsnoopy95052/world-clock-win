# World Clock for Windows

A small floating desktop clock that shows the time in up to five cities / time zones at once. Written in PowerShell + WinForms: no install, no build step.

## Features

- Five configurable clocks (defaults: Local, New York, Taipei, Sydney, UTC)
- Day / night icon per city: dawn (5-7 AM), day, sunset (5-7 PM), night
- Time difference from your local time (e.g. `+13h`)
- 12 / 24-hour toggle
- Drag anywhere to move; position is remembered
- Optional always-on-top, adjustable opacity, start with Windows
- High-DPI aware, flicker-free rendering

## Requirements

- Windows 10 / 11 with Windows PowerShell 5.1 (included with Windows)

## Run

Double-click `WorldClock.vbs` (launches without a console window), or run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File WorldClock.ps1
```

## Usage

Right-click the clock for the menu:

| Item | What it does |
|------|--------------|
| Choose 5 cities... | Pick a label and a Windows time zone for each of the five rows |
| 24-hour time | Switch between 24-hour and 12-hour (AM/PM) display |
| Opacity | 100% to 40% |
| Always on top | Keep the clock above other windows |
| Start with Windows | Adds / removes a shortcut in your Startup folder |
| Exit | Close the clock |

Windows time zones are named by region (e.g. "Eastern Time (US & Canada)"), so type your own label such as `New York` in the Label box.

## Settings

Settings are saved to `config.json` next to the script (created on first change, git-ignored). You can edit it by hand, e.g. the `Clocks` list, using Windows time zone IDs. List them with:

```powershell
Get-TimeZone -ListAvailable | Select-Object Id, DisplayName
```

Use `"Id": "local"` for your PC's time zone.

## Notes

Windows 11 does not allow third-party additions to the taskbar calendar flyout. For up to two extra clocks there, use the built-in option: `Win+R` → `timedate.cpl` → *Additional Clocks*.
