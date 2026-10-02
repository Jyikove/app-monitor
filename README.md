# App monitor 1.10

Download **App-monitor-v1.10-macOS-arm64.zip** from the [latest release](https://github.com/Jyikove/app-monitor/releases/latest), extract it, and open **App monitor.app**. The app is built for Apple Silicon Macs running macOS 13 or later and does not require extra dependencies.

This repository contains the source code and icon assets. To build locally with Apple Command Line Tools installed:

```sh
git clone https://github.com/Jyikove/app-monitor.git
cd app-monitor
./Sources/build.command
```

## Interface

The app displays one row per running application. Helper processes are combined into the app's CPU and memory totals; system background processes are not listed separately. All interface text, menus, tooltips, status messages, and confirmation dialogs are in English. Application names follow the names provided by the installed applications.

The large title and subtitle row has been removed. Application names and usage values use 15-point text, with larger status labels, column headings, and summary values. Summary cards appear at the top. The app column heading, compact search button, menu bar app toggle, live status, pause and refresh controls all share a single table header row with the measurement column headings. The native window title is also hidden, while the standard window controls remain available.

On macOS 26 or later, the window uses Apple's native **NSGlassEffectView** with the **clear** style. A separate native NSVisualEffectView behind-window material at 14% opacity adds a light frosted contribution. A translucent blue dimming layer sits above the frost to retain the stronger blue hue and support readable light text; the restrained blue wash adds a subtle gradient. Text and controls remain fully opaque. A fine edge reflection is strongest at the top and fades toward the bottom, and the native soft window shadow is retained. Earlier macOS versions use the native translucent window material. Native materials respect the system accessibility settings, so their appearance can vary with the background and Reduce Transparency.

## Controls

- **Search apps:** Click the magnifying-glass button beside App, or press Command-F, to expand and focus the search field. Type to filter apps. Press Escape or click the close button to clear the filter and collapse search. An empty search also collapses when it loses focus.
- **App / Memory usage / CPU:** Click a column heading to sort. Click again to reverse the order. The default is highest memory first.
- **Menu bar apps:** Include standalone user apps such as Mos and YouTu that do not have ordinary windows.
- **Pause / Resume:** Freeze the data or resume automatic updates. Sampling normally runs every second.
- **Refresh:** Update immediately, including while automatic updates are paused. Shortcut: Command-R.
- **Quit:** Force quit the application and its bundled helpers. A confirmation warns about unsaved changes before force quitting. The Action column contains this single button; there is no More menu or dropdown.
- **Double-click a row:** Switch to that application.

Finder is protected because it manages the desktop and files. Closing the App monitor window exits App monitor.

## Measurements

**CPU per application:** CPU time used by the app's processes during the latest sampling interval. CPU time is divided by the Mac's logical processor count. 100% represents the full CPU capacity of this Mac; each application uses the same whole-machine scale as the summary. On this 10-core Mac, one fully occupied core is approximately 10%. The first reading appears after about one second.

**CPU usage summary:** The sum of all included application CPU percentages. Each application is normalized once to total machine capacity, so the summary uses the same scale as the rows.

**Memory usage:** The combined physical memory footprint of the app's processes, including compressed memory accounting. This is not simply resident memory and does not equal total system memory usage.

Search filters only the list; summary cards continue to count all included apps. The menu bar app toggle also changes the summary totals. Protected or unavailable measurements are shown as a dash or marked with an asterisk.

## Attribution and quitting

App monitor identifies normal applications from macOS's running-app list and standalone menu bar apps installed under /Applications or the current user's Applications folder. Processes are grouped by the application's main process, executable bundle path, ancestry, and available macOS coalition information. Each process contributes to at most one app.

Shared services and processes without a clear owner are excluded. Only apps owned by the current user are measured. Results can therefore differ from Activity Monitor. Coalition attribution uses an optional read-only XNU interface; if it becomes unavailable, bundle paths and ancestry remain available, but some system-launched helpers may not be attributed.

The Quit button uses force quitting by default. It closes the main app and cleans up helpers whose executable paths are inside that exact app bundle. Process identities are checked before cleanup. Shared system services are not directly signalled, and independent login items may restart themselves.

All measurements stay on this Mac. App monitor does not access the network or require administrator, Accessibility, or Screen Recording permissions.

## Source and build

The **Sources** folder contains the Swift interface and monitor, C process reader, application metadata, icon, and build.command. On an Apple Silicon Mac with Apple Command Line Tools installed, run build.command to generate App monitor.app in the parent directory. Quit the running app before rebuilding.

## Validation

The monitoring implementation was checked against real multi-process apps and a dedicated test app with a 32 MB helper that continuously used one CPU core. The helper and main app appeared as one row, and the original per-core measurement was approximately 99.6%. CPU readings are now normalized to whole-machine capacity. A subsequent live check measured one busy core as 9.68% on this 10-core Mac and verified that the summary matched the application row without dividing twice. Normal quitting, declined quit requests, force-quit confirmation, helper cleanup, and Finder protection were verified. The English Liquid Glass interface was compiled and inspected on macOS 26. The interface uses Memory usage and CPU usage labels, larger text, and one Quit button per Action cell that opens the force-quit confirmation. Version 1.3 normalizes all CPU percentages to total machine capacity and removes the bottom hint bar.

API references: [NSRunningApplication](https://developer.apple.com/documentation/appkit/nsrunningapplication), [NSGlassEffectView](https://developer.apple.com/documentation/appkit/nsglasseffectview), [XNU coalition information](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/sys/proc_info_private.h), and [XNU CPU and memory accounting](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/kern/bsd_kern.c).

## Generated icon

Version 1.4 uses an ImageGen icon with layered glass app cards and three resource-usage bars, matching the teal accent and Liquid Glass interface. Sources/AppIcon-v2.png is the transparent master image, AppIcon-v2.icns is the multi-resolution macOS icon, and AppIcon-v2-prompt.txt records the exact generation prompt and built-in tool mode. The previous source icon is preserved. The build script selects the icon declared in Info.plist.

Version 1.5 merges the search/update toolbar and table headings into one compact row. Search is collapsed to an icon by default, expanding inline when activated. The collapsed and expanded layouts, live filtering, Command-F focusing, and Escape clearing/collapse were checked in the native app.

Version 1.6 refines the background to blue-tinted frosted glass, with a thin top-to-bottom fading highlight and a subtle native shadow. The layout and controls are preserved. The updated material, reflection, text contrast, inline search, and Escape collapse were verified in the native app on macOS 26.

Version 1.7 lightens the frosted backdrop to 76% opacity and reduces the blue wash and glass tint for a clearer finish. The edge reflections and soft shadow are retained. The updated appearance and text visibility were checked in the native app.

Version 1.8 removes the additional traditional frosted material on macOS 26, replacing it with native clear Liquid Glass over a translucent dimming layer. The blue wash and tint are substantially reduced. This corrects the persistent cloudy appearance from the previous layering approach; reducing frost opacity alone did not remove its blur. The native window and text visibility were inspected, and the application signature was verified.

Version 1.9 strengthens the blue background while retaining the native clear glass style, edge reflections, and shadow. The dimming layer retains its previous opacity, and no extra frosted layer is added. CPU and memory automatically refresh every second; CPU calculation continues to use the actual elapsed sampling time. The About panel and this guide reflect the new refresh interval.

Version 1.10 restores a faint traditional frosted layer at 14% opacity beneath the blue dimming layer and native clear glass. This lightly softens the backdrop while preserving the blue hue, glass reflections, and one-second refresh interval. The native window appearance, text visibility, search button, and Escape collapse were checked.
