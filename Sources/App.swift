import AppKit
import SwiftUI

private let accent = Color(red: 0.12, green: 0.56, blue: 0.45)

struct OverviewView: View {
    @ObservedObject var model: MonitorModel
    @FocusState private var searchFocused: Bool
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                summary("Running apps", value: "\(model.includedRows.count)", unit: "apps", symbol: "app.badge", color: accent)
                summary("Memory usage", value: memoryText(model.totalMemory), unit: "", symbol: "memorychip", color: .blue)
                summary("CPU usage", value: String(format: "%.1f%%", model.totalCPU), unit: "of total capacity", symbol: "cpu", color: .orange)
            }.padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 16)
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    sortHeader("App", choice: .name).fixedSize()
                    Button {
                        if model.searchExpanded { closeSearch() } else { openSearch() }
                    } label: {
                        Image(systemName: model.searchExpanded ? "xmark" : "magnifyingglass")
                            .foregroundStyle(model.searchExpanded ? accent : Color.secondary)
                            .frame(width: 24, height: 24)
                    }.buttonStyle(.plain)
                        .accessibilityLabel(model.searchExpanded ? "Close search" : "Search apps")
                        .help(model.searchExpanded ? "Close search and clear the filter" : "Search apps ⌘F")
                    if model.searchExpanded {
                        TextField("Search apps", text: $model.query)
                            .textFieldStyle(.plain).font(.system(size: 14))
                            .focused($searchFocused)
                            .onExitCommand { closeSearch() }
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(.primary.opacity(0.07)))
                            .frame(minWidth: 70, idealWidth: 110, maxWidth: 150)
                            .layoutPriority(-1)
                    }
                    Toggle("Menu bar apps", isOn: $model.includeMenuApps)
                        .toggleStyle(.checkbox).font(.system(size: 13)).fixedSize()
                        .help("Include standalone menu bar apps")
                    HStack(spacing: 4) {
                        Circle().fill(model.paused ? Color.orange : accent).frame(width: 6, height: 6)
                        Text(model.paused ? "Paused" : "Live")
                    }.fixedSize()
                    Button { model.paused.toggle(); if !model.paused { model.refresh() } } label: {
                        Image(systemName: model.paused ? "play.fill" : "pause.fill").frame(width: 20, height: 24)
                    }.buttonStyle(.borderless).help(model.paused ? "Resume updates" : "Pause updates")
                    Button { model.refresh() } label: {
                        Image(systemName: "arrow.clockwise").frame(width: 20, height: 24)
                    }.buttonStyle(.borderless).keyboardShortcut("r").help("Refresh now ⌘R")
                }.frame(maxWidth: .infinity, alignment: .leading)
                sortHeader("Memory usage", choice: .memory).frame(width: 132, alignment: .trailing)
                sortHeader("CPU", choice: .cpu).frame(width: 114, alignment: .trailing)
                Text("Action").frame(width: 92, alignment: .trailing).foregroundStyle(.secondary)
            }.font(.system(size: 13, weight: .medium)).padding(.horizontal, 28).padding(.vertical, 8)
                .background(Color.primary.opacity(0.035))
            Divider()
            if model.rows.isEmpty && model.updatedAt == nil {
                VStack(spacing: 12) { ProgressView(); Text("Loading running apps…").foregroundStyle(.secondary) }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.visibleRows.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").font(.system(size: 32)).foregroundStyle(.tertiary)
                    Text(model.query.isEmpty ? "No running apps" : "No matching apps").foregroundStyle(.secondary)
                    if !model.query.isEmpty { Button("Clear search") { model.query = "" } }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.visibleRows) { row in
                            applicationRow(row)
                            Divider().padding(.leading, 80).padding(.trailing, 24)
                        }
                    }
                }
            }
            if let status = model.status {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle").foregroundStyle(accent)
                    Text(status).font(.system(size: 12)).lineLimit(2)
                    Spacer()
                    Button { model.status = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                }.padding(.horizontal, 24).padding(.vertical, 10).background(accent.opacity(0.07))
            }
        }
        .frame(minWidth: 780, minHeight: 460)
        .background {
            // A restrained blue wash adds color while clear glass retains backdrop detail.
            LinearGradient(stops: [
                .init(color: Color(red: 0.15, green: 0.58, blue: 1.00).opacity(0.12), location: 0),
                .init(color: Color(red: 0.11, green: 0.42, blue: 0.95).opacity(0.07), location: 0.40),
                .init(color: Color(red: 0.10, green: 0.30, blue: 0.86).opacity(0.09), location: 1)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(LinearGradient(stops: [
                    .init(color: Color.white.opacity(0.78), location: 0),
                    .init(color: Color(red: 0.81, green: 0.93, blue: 1).opacity(0.40), location: 0.15),
                    .init(color: Color(red: 0.72, green: 0.87, blue: 1).opacity(0.22), location: 0.55),
                    .init(color: Color.white.opacity(0.09), location: 1)
                ], startPoint: .top, endPoint: .bottom), lineWidth: 0.9)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("FocusAppSearch"))) { _ in openSearch() }
        .onChange(of: searchFocused) { focused in
            if !focused && model.query.isEmpty {
                withAnimation(.easeInOut(duration: 0.15)) { model.searchExpanded = false }
            }
        }
    }

    private func openSearch() {
        withAnimation(.easeInOut(duration: 0.15)) { model.searchExpanded = true }
        DispatchQueue.main.async { searchFocused = true }
    }

    private func closeSearch() {
        model.query = ""
        searchFocused = false
        withAnimation(.easeInOut(duration: 0.15)) { model.searchExpanded = false }
    }

    private func summary(_ title: String, value: String, unit: String, symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                Image(systemName: symbol).foregroundStyle(color.opacity(0.85)).font(.system(size: 14))
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value).font(.system(size: 28, weight: .semibold, design: .rounded)).monospacedDigit()
                Text(unit).font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.primary.opacity(0.05)))
    }

    private func sortHeader(_ title: String, choice: SortChoice) -> some View {
        Button { model.changeSort(choice) } label: {
            HStack(spacing: 4) {
                Text(title)
                if model.sort == choice { Image(systemName: model.descending ? "chevron.down" : "chevron.up").font(.system(size: 9, weight: .bold)) }
            }.foregroundStyle(model.sort == choice ? Color.primary : .secondary)
        }.buttonStyle(.plain).help("Sort by \(title). Click again to reverse the order.")
    }

    private func applicationRow(_ row: AppRow) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(nsImage: row.icon).resizable().frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.descriptor.name).font(.system(size: 15, weight: .medium)).lineLimit(1)
                    if model.pending.contains(row.id) {
                        Text("Waiting to quit…").font(.system(size: 12)).foregroundStyle(.orange)
                    } else {
                        Text(row.usage.unreadable > 0 ? "Some data unavailable" : (row.descriptor.menuOnly ? "Menu bar app" : "Running"))
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Text(row.usage.readable > 0 ? memoryText(row.usage.memory) + (row.usage.unreadable > 0 ? "*" : "") : "—")
                .font(.system(size: 15, weight: .medium, design: .rounded)).monospacedDigit()
                .frame(width: 132, alignment: .trailing)
                .help("Combined \(row.usage.processCount) app processes. Memory is the physical footprint.")
            Text(row.usage.cpuReady ? String(format: "%.1f%%", row.usage.cpu) + (row.usage.unreadable > 0 ? "*" : "") : "—")
                .font(.system(size: 15, weight: .medium, design: .rounded)).monospacedDigit()
                .foregroundStyle(row.usage.cpu > 80 ? Color.orange : Color.primary)
                .frame(width: 114, alignment: .trailing)
                .help(row.usage.cpuReady ? "100% means the full CPU capacity of this Mac." : "Waiting for the next sample, or data unavailable.")
            Button("Quit") { model.terminate(row, force: true) }
                .controlSize(.regular)
                .font(.system(size: 13))
                .disabled(model.isProtected(row) || model.pending.contains(row.id))
                .help(model.isProtected(row) ? "Finder manages your desktop and files and is protected." : "Force quit this app and its bundled helpers.")
                .frame(width: 92, alignment: .trailing)
        }.padding(.horizontal, 28).frame(height: 74)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { model.activate(row) }
    }
}

final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    let model = MonitorModel()
    var window: NSWindow!
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let view = OverviewView(model: model)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 880, height: 660),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "App monitor"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        let hosting = NSHostingView(rootView: view)
        hosting.frame = window.contentView!.bounds
        hosting.autoresizingMask = [.width, .height]
        let backdrop = NSView(frame: window.contentView!.bounds)
        backdrop.wantsLayer = true
        backdrop.layer?.cornerRadius = 16
        backdrop.layer?.masksToBounds = true
        if #available(macOS 26.0, *) {
            // Clear glass needs a dimming layer for readable white content.
            // The blue scrim keeps the hue and contrast; a faint native frost
            // softens the backdrop without fading text or glass reflections.
            let frost = NSVisualEffectView(frame: backdrop.bounds)
            frost.material = .underWindowBackground
            frost.blendingMode = .behindWindow
            frost.state = .active
            frost.alphaValue = 0.14
            frost.autoresizingMask = [.width, .height]
            backdrop.addSubview(frost)
            let dimming = NSView(frame: backdrop.bounds)
            dimming.wantsLayer = true
            dimming.layer?.backgroundColor = NSColor(calibratedRed: 0.01,
                green: 0.10, blue: 0.36, alpha: 0.52).cgColor
            dimming.autoresizingMask = [.width, .height]
            backdrop.addSubview(dimming)
            hosting.appearance = NSAppearance(named: .darkAqua)
            let glass = NSGlassEffectView(frame: backdrop.bounds)
            glass.style = .clear
            glass.tintColor = NSColor(calibratedRed: 0.20, green: 0.52, blue: 0.95, alpha: 0.025)
            glass.cornerRadius = 16
            glass.autoresizingMask = [.width, .height]
            glass.contentView = hosting
            backdrop.addSubview(glass)
        } else {
            let material = NSVisualEffectView(frame: backdrop.bounds)
            material.material = .underWindowBackground
            material.blendingMode = .behindWindow
            material.state = .active
            material.autoresizingMask = [.width, .height]
            backdrop.addSubview(material)
            hosting.frame = backdrop.bounds
            backdrop.addSubview(hosting)
        }
        window.contentView = backdrop
        window.minSize = NSSize(width: 780, height: 500)
        window.setFrameAutosaveName("AppOverviewWindow")
        window.center()
        window.makeKeyAndOrderFront(nil)
        if #available(macOS 14.0, *) { NSApp.activate() }
        else { NSApp.activate(ignoringOtherApps: true) }
        installMenu()
        model.start()
        let arguments = CommandLine.arguments
        if let index = arguments.firstIndex(of: "--snapshot"), arguments.count > index + 1 {
            let path = arguments[index + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                guard let view = self?.window.contentView,
                      let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
                view.cacheDisplay(in: view.bounds, to: rep)
                if let data = rep.representation(using: .png, properties: [:]) { try? data.write(to: URL(fileURLWithPath: path)) }
            }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window.makeKeyAndOrderFront(nil); return true
    }
    private func installMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem(); main.addItem(appItem)
        let appMenu = NSMenu(); appItem.submenu = appMenu
        let about = NSMenuItem(title: "About App monitor", action: #selector(aboutApp), keyEquivalent: ""); about.target = self; appMenu.addItem(about)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide App monitor", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit App monitor", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editItem = NSMenuItem(); main.addItem(editItem)
        let editMenu = NSMenu(title: "Edit"); editItem.submenu = editMenu
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let viewItem = NSMenuItem(); main.addItem(viewItem)
        let viewMenu = NSMenu(title: "View"); viewItem.submenu = viewMenu
        let search = NSMenuItem(title: "Search Apps", action: #selector(focusSearch), keyEquivalent: "f"); search.target = self; viewMenu.addItem(search)
        let refresh = NSMenuItem(title: "Refresh Now", action: #selector(refreshApps), keyEquivalent: "r"); refresh.target = self; viewMenu.addItem(refresh)
        let windowItem = NSMenuItem(); main.addItem(windowItem)
        let windowMenu = NSMenu(title: "Window"); windowItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        NSApp.windowsMenu = windowMenu
        NSApp.mainMenu = main
    }
    @objc private func focusSearch() { NotificationCenter.default.post(name: .init("FocusAppSearch"), object: nil) }
    @objc private func refreshApps() { model.refresh() }
    @objc private func aboutApp() {
        let alert = NSAlert(); alert.messageText = "App monitor 1.10"
        alert.informativeText = "One row per app, with helper processes combined.\nCPU and memory update every second. Quit or force quit apps.\nAll data stays on this Mac. No network access."
        alert.addButton(withTitle: "OK"); alert.beginSheetModal(for: window)
    }
}

@main
enum AppMain {
    static func main() {
        if CommandLine.arguments.contains("--diagnostics") {
            let apps = runningApps()
            let sampler = ProcessSampler()
            _ = sampler.sample(apps: apps)
            Thread.sleep(forTimeInterval: 2)
            let result = sampler.sample(apps: apps)
            let objects = apps.map { app -> [String: Any] in
                let usage = result.usages[app.id] ?? AppUsage()
                return ["name": app.name, "bundle": app.path, "pids": app.pids, "processes": usage.processCount,
                    "memoryBytes": usage.memory, "cpuPercent": usage.cpu, "unreadable": usage.unreadable,
                    "members": result.processes.filter { result.processOwners[$0.pid] == app.id }.map {
                        ["pid": $0.pid, "parent": $0.parent, "path": $0.path, "coalition": $0.coalition] as [String: Any]
                    }]
            }
            if let data = try? JSONSerialization.data(withJSONObject: objects, options: [.prettyPrinted, .sortedKeys]),
               let text = String(data: data, encoding: .utf8) { print(text) }
            return
        }
        let app = NSApplication.shared
        let delegate = ApplicationDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
