import AppKit
import Foundation

struct AppDescriptor {
    let id: String
    let name: String
    let path: String
    let pids: [Int32]
    let menuOnly: Bool
}

struct ProcessSample {
    let pid: Int32
    let parent: Int32
    let identity: String
    let path: String
    let coalition: UInt64
    let cpuTime: Double
    let memory: UInt64
    let available: Bool
}

struct AppUsage {
    var memory: UInt64 = 0
    var cpu: Double = 0
    var readable = 0
    var unreadable = 0
    var processCount = 0
    var cpuReady = false
}

struct SampleResult {
    let usages: [String: AppUsage]
    let processOwners: [Int32: String]
    let processes: [ProcessSample]
    let success: Bool
}

func runningApps() -> [AppDescriptor] {
    let currentUID = getuid()
    var groups: [String: AppDescriptor] = [:]
    for app in NSWorkspace.shared.runningApplications where !app.isTerminated {
        guard let url = app.bundleURL else { continue }
        let path = url.resolvingSymlinksInPath().path
        let regular = app.activationPolicy == .regular
        let outerBundle = !path.contains(".app/")
        // Accessory apps count only when they are actual user-installed top-level
        // bundles. This excludes system agents, XPC services and nested helpers.
        let accessory = app.activationPolicy == .accessory && outerBundle &&
            (path.hasPrefix("/Applications/") || path.hasPrefix(NSHomeDirectory() + "/Applications/"))
        guard regular || accessory else { continue }
        // NSWorkspace may report apps owned by a different logged-in user.
        var info = proc_bsdinfo()
        let size = MemoryLayout<proc_bsdinfo>.size
        guard proc_pidinfo(app.processIdentifier, PROC_PIDTBSDINFO, 0, &info, Int32(size)) == size,
              info.pbi_uid == currentUID else { continue }
        let id = path
        let name = app.localizedName ?? url.deletingPathExtension().lastPathComponent
        let pids = (groups[id]?.pids ?? []) + [app.processIdentifier]
        groups[id] = AppDescriptor(id: id, name: name, path: path, pids: pids,
                                   menuOnly: (groups[id]?.menuOnly ?? true) && !regular)
    }
    return groups.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
}

final class ProcessSampler {
    private var previous: [String: (cpu: Double, time: Double)] = [:]

    func sample(apps: [AppDescriptor]) -> SampleResult {
        var pointer: UnsafeMutablePointer<AMProcess>?
        let count = am_snapshot(&pointer)
        guard count >= 0, let pointer = pointer else {
            return SampleResult(usages: [:], processOwners: [:], processes: [], success: false)
        }
        defer { am_free(pointer) }
        let processes = UnsafeBufferPointer(start: pointer, count: Int(count)).map { raw -> ProcessSample in
            var executable = raw.executable
            let path = withUnsafePointer(to: &executable) {
                $0.withMemoryRebound(to: CChar.self, capacity: 4096) { String(cString: $0) }
            }
            return ProcessSample(pid: raw.pid, parent: raw.parent_pid,
                identity: "\(raw.pid):\(raw.start_seconds):\(raw.start_microseconds)", path: path,
                coalition: raw.coalition, cpuTime: raw.cpu_seconds, memory: raw.memory_bytes,
                available: raw.metrics_available != 0)
        }
        let now = ProcessInfo.processInfo.systemUptime
        let result = aggregate(apps: apps, processes: processes, now: now)
        previous = Dictionary(uniqueKeysWithValues: processes.filter(\.available).map { ($0.identity, ($0.cpuTime, now)) })
        return result
    }

    func aggregate(apps: [AppDescriptor], processes: [ProcessSample], now: Double) -> SampleResult {
        let byPID = Dictionary(uniqueKeysWithValues: processes.map { ($0.pid, $0) })
        var direct: [Int32: String] = [:]
        for app in apps { for pid in app.pids { direct[pid] = app.id } }
        var coalitionCandidates: [UInt64: Set<String>] = [:]
        for (pid, appID) in direct {
            if let process = byPID[pid], process.coalition != 0 {
                coalitionCandidates[process.coalition, default: []].insert(appID)
            }
        }
        let paths = apps.sorted { $0.path.count > $1.path.count }
        var owners = direct
        // First assign explicit app bundles. Only then walk ancestry so descendants
        // of helpers launched by launchd also resolve correctly.
        for process in processes where owners[process.pid] == nil {
            if let app = paths.first(where: { process.path.hasPrefix($0.path + "/") }) {
                owners[process.pid] = app.id
            }
        }
        for process in processes where owners[process.pid] == nil {
            var ancestor = process.parent
            var visited: Set<Int32> = [process.pid]
            while ancestor > 1 && visited.insert(ancestor).inserted {
                if let owner = owners[ancestor] { owners[process.pid] = owner; break }
                ancestor = byPID[ancestor]?.parent ?? 0
            }
            // A coalition shared by distinct visible apps is ambiguous: do not
            // attribute it. Each process can contribute to at most one app.
            if owners[process.pid] == nil, process.coalition != 0,
               let candidates = coalitionCandidates[process.coalition], candidates.count == 1 {
                owners[process.pid] = candidates.first
            }
        }
        var usages = Dictionary(uniqueKeysWithValues: apps.map { ($0.id, AppUsage()) })
        for process in processes {
            guard let owner = owners[process.pid] else { continue }
            var usage = usages[owner] ?? AppUsage()
            usage.processCount += 1
            if process.available {
                usage.memory += process.memory
                usage.readable += 1
                if let last = previous[process.identity], now > last.time, process.cpuTime >= last.cpu {
                    usage.cpu += (process.cpuTime - last.cpu) / (now - last.time) * 100
                    usage.cpuReady = true
                }
            } else { usage.unreadable += 1 }
            usages[owner] = usage
        }
        // Normalize once so each app, sorting, diagnostics and the summary all
        // use the same share of the whole Mac's logical CPU capacity.
        let capacity = Double(max(1, ProcessInfo.processInfo.activeProcessorCount))
        for id in Array(usages.keys) {
            usages[id]!.cpu /= capacity
        }
        return SampleResult(usages: usages, processOwners: owners, processes: processes, success: true)
    }
}

struct AppRow: Identifiable {
    let descriptor: AppDescriptor
    let usage: AppUsage
    let icon: NSImage
    var id: String { descriptor.id }
}

enum SortChoice: String, CaseIterable {
    case memory = "Memory", cpu = "CPU", name = "Name"
}

final class MonitorModel: ObservableObject {
    @Published var rows: [AppRow] = []
    @Published var query = ""
    @Published var searchExpanded = false
    @Published var sort: SortChoice = .memory
    @Published var descending = true
    @Published var paused = false
    @Published var includeMenuApps = true
    @Published var status: String?
    @Published var pending: Set<String> = []
    @Published var updatedAt: Date?
    private let queue = DispatchQueue(label: "app-overview.sampling", qos: .utility)
    private let sampler = ProcessSampler()
    private var timer: Timer?
    private var sampling = false
    private var iconCache: [String: NSImage] = [:]

    var visibleRows: [AppRow] {
        rows.filter { (includeMenuApps || !$0.descriptor.menuOnly) &&
            (query.isEmpty || $0.descriptor.name.localizedCaseInsensitiveContains(query)) }
            .sorted { a, b in
                let comparison: Bool
                switch sort {
                case .memory:
                    if a.usage.memory == b.usage.memory { return a.descriptor.name < b.descriptor.name }
                    comparison = a.usage.memory < b.usage.memory
                case .cpu:
                    if a.usage.cpu == b.usage.cpu { return a.descriptor.name < b.descriptor.name }
                    comparison = a.usage.cpu < b.usage.cpu
                case .name: comparison = a.descriptor.name.localizedStandardCompare(b.descriptor.name) == .orderedAscending
                }
                return descending ? !comparison : comparison
            }
    }
    var includedRows: [AppRow] { rows.filter { includeMenuApps || !$0.descriptor.menuOnly } }
    var totalMemory: UInt64 { includedRows.reduce(0) { $0 + $1.usage.memory } }
    var totalCPU: Double { includedRows.reduce(0) { $0 + $1.usage.cpu } }

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self, !self.paused else { return }; self.refresh()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    func changeSort(_ choice: SortChoice) {
        if sort == choice { descending.toggle() }
        else { sort = choice; descending = choice != .name }
    }
    func refresh() {
        guard !sampling else { return }
        sampling = true
        let apps = runningApps()
        queue.async { [weak self] in
            guard let self = self else { return }
            let result = self.sampler.sample(apps: apps)
            DispatchQueue.main.async {
                self.sampling = false
                guard result.success else { self.status = "Usage data is temporarily unavailable. Please refresh again."; return }
                self.rows = apps.compactMap { app in
                    guard app.pids.contains(where: { NSRunningApplication(processIdentifier: $0)?.isTerminated == false }) else { return nil }
                    let icon = self.iconCache[app.id] ?? NSWorkspace.shared.icon(forFile: app.path)
                    self.iconCache[app.id] = icon
                    return AppRow(descriptor: app, usage: result.usages[app.id] ?? AppUsage(), icon: icon)
                }
                self.pending.formIntersection(Set(self.rows.map(\.id)))
                self.iconCache = self.iconCache.filter { key, _ in apps.contains { $0.id == key } }
                self.updatedAt = Date()
            }
        }
    }
    func isProtected(_ row: AppRow) -> Bool {
        row.descriptor.pids.contains { NSRunningApplication(processIdentifier: $0)?.bundleIdentifier == "com.apple.finder" }
    }
    func activate(_ row: AppRow) {
        row.descriptor.pids.compactMap { NSRunningApplication(processIdentifier: $0) }.first?.activate()
    }
    func terminate(_ row: AppRow, force: Bool = true) {
        guard !isProtected(row) else { return }
        let apply = { [weak self] in
            guard let self = self else { return }
            let targets = row.descriptor.pids.compactMap { NSRunningApplication(processIdentifier: $0) }.filter {
                !$0.isTerminated && $0.bundleURL?.resolvingSymlinksInPath().path == row.descriptor.path
            }
            guard !targets.isEmpty else { self.refresh(); return }
            // Capture helper identities before the main app exits and its children
            // are reparented. Force cleanup is limited to executables inside this
            // exact app bundle; shared system XPC services are never signalled.
            let forceSnapshot = force ? ProcessSampler().sample(apps: runningApps()) : nil
            let ownedHelpers = forceSnapshot?.processes.filter {
                forceSnapshot?.processOwners[$0.pid] == row.id &&
                !row.descriptor.pids.contains($0.pid) &&
                $0.path.hasPrefix(row.descriptor.path + "/")
            } ?? []
            var accepted = true
            for app in targets {
                let result = force ? app.forceTerminate() : app.terminate()
                accepted = result && accepted
            }
            self.pending.insert(row.id)
            self.status = accepted ? "Requested \(force ? "force quit" : "quit") for \(row.descriptor.name)." : "\(row.descriptor.name) did not accept the quit request."
            if force && accepted {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    let current = ProcessSampler().sample(apps: []).processes
                    let identities = Dictionary(uniqueKeysWithValues: current.map { ($0.pid, $0.identity) })
                    for helper in ownedHelpers where identities[helper.pid] == helper.identity {
                        kill(helper.pid, SIGKILL)
                    }
                    self?.refresh()
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
                guard let self = self else { return }
                if targets.contains(where: { !$0.isTerminated }) {
                    self.pending.remove(row.id)
                    self.status = "\(row.descriptor.name) is still running. Try the Quit button again."
                }
                self.refresh()
            }
            self.refresh()
        }
        guard force else { apply(); return }
        let alert = NSAlert()
        alert.messageText = "Force quit \(row.descriptor.name)?"
        alert.informativeText = "Unsaved changes may be lost. The app and its bundled helpers will be closed."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Force Quit")
        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window) { if $0 == .alertSecondButtonReturn { apply() } }
        } else if alert.runModal() == .alertSecondButtonReturn { apply() }
    }
}

func memoryText(_ bytes: UInt64) -> String {
    let value = Double(bytes) / 1_048_576
    return value >= 1024 ? String(format: "%.2f GB", value / 1024) : String(format: "%.0f MB", value)
}
