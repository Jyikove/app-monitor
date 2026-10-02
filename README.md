# App monitor

A lightweight macOS app resource monitor with a native blue glass interface.

- App-level CPU and memory usage, refreshed every second.
- Search, sorting, pause/resume, and double-click to switch apps.
- Optional menu bar app monitoring and confirmed force quit. Finder is protected.
- All data stays on your Mac. No network access or administrator permissions required.

## Download

Download the ZIP from the [latest release](https://github.com/Jyikove/app-monitor/releases/latest), extract it, and open **App monitor.app**.

Requires an Apple Silicon Mac running macOS 13 or later. Native Liquid Glass is available on macOS 26 or later. The app is ad-hoc signed and not notarized by Apple.

## Build

With Apple Command Line Tools installed, run:

```sh
git clone https://github.com/Jyikove/app-monitor.git
cd app-monitor
./Sources/build.command
```

The app is generated in the project root. CPU percentages use total machine capacity; memory includes the app and its helper processes' physical footprint.
