import Foundation
import AppKit

struct PortResource: Codable, Identifiable {
    var id: String { port }
    let port: String
    let project: String
    let path: String?
    let started: String?
}

struct DatabaseResource: Codable, Identifiable {
    var id: String { name }
    let name: String
    let project: String
    let port: Int?
}

struct SimulatorResource: Codable, Identifiable {
    var id: String { udid }
    let udid: String
    let name: String
    let project: String
    let deviceType: String?
    let started: String?
}

struct SharedResources: Codable {
    var ports: [String: PortInfo]
    var databases: [String: DatabaseInfo]
    var redis: [String: RedisInfo]
    var simulators: [String: SimulatorInfo]
    var notes: String?

    struct PortInfo: Codable {
        let project: String
        let path: String?
        let started: String?
    }

    struct DatabaseInfo: Codable {
        let project: String
        let port: Int?
    }

    struct RedisInfo: Codable {
        let project: String
        let port: Int?
    }

    struct SimulatorInfo: Codable {
        let name: String
        let project: String
        let deviceType: String?
        let started: String?
    }

    static var empty: SharedResources {
        SharedResources(ports: [:], databases: [:], redis: [:], simulators: [:], notes: nil)
    }
}

class ResourcesManager: ObservableObject {
    static let shared = ResourcesManager()

    @Published private(set) var resources: SharedResources = .empty
    @Published private(set) var lastUpdated: Date?

    private let fileURL: URL
    private var fileWatcher: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1

    private init() {
        fileURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/shared-resources.json")

        loadResources()
        startWatching()
    }

    deinit {
        stopWatching()
    }

    // MARK: - File Operations

    func loadResources() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            resources = .empty
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            resources = try JSONDecoder().decode(SharedResources.self, from: data)
            lastUpdated = Date()
        } catch {
            print("Failed to load shared resources: \(error)")
            resources = .empty
        }

        objectWillChange.send()
    }

    func saveResources() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(resources)
            try data.write(to: fileURL, options: .atomic)
            lastUpdated = Date()
        } catch {
            print("Failed to save shared resources: \(error)")
        }
    }

    // MARK: - File Watching

    private func startWatching() {
        // Ensure file exists
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try? "{}".write(to: fileURL, atomically: true, encoding: .utf8)
        }

        fileDescriptor = open(fileURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        fileWatcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .rename],
            queue: .main
        )

        fileWatcher?.setEventHandler { [weak self] in
            self?.loadResources()
        }

        fileWatcher?.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
            }
            self?.fileDescriptor = -1
        }

        fileWatcher?.resume()
    }

    private func stopWatching() {
        fileWatcher?.cancel()
        fileWatcher = nil
    }

    // MARK: - Computed Properties

    var ports: [PortResource] {
        resources.ports.map { key, value in
            PortResource(port: key, project: value.project, path: value.path, started: value.started)
        }.sorted { $0.port < $1.port }
    }

    var databases: [DatabaseResource] {
        resources.databases.map { key, value in
            DatabaseResource(name: key, project: value.project, port: value.port)
        }.sorted { $0.name < $1.name }
    }

    var simulators: [SimulatorResource] {
        resources.simulators.map { key, value in
            SimulatorResource(udid: key, name: value.name, project: value.project, deviceType: value.deviceType, started: value.started)
        }.sorted { $0.name < $1.name }
    }

    var totalResourceCount: Int {
        resources.ports.count + resources.databases.count + resources.simulators.count + resources.redis.count
    }

    var activePortsCount: Int { resources.ports.count }
    var activeDatabasesCount: Int { resources.databases.count }
    var activeSimulatorsCount: Int { resources.simulators.count }

    // MARK: - Resource Management

    func addPort(_ port: String, project: String, path: String?) {
        resources.ports[port] = SharedResources.PortInfo(
            project: project,
            path: path,
            started: ISO8601DateFormatter().string(from: Date())
        )
        saveResources()
    }

    func removePort(_ port: String) {
        resources.ports.removeValue(forKey: port)
        saveResources()
    }

    func addSimulator(udid: String, name: String, project: String, deviceType: String?) {
        resources.simulators[udid] = SharedResources.SimulatorInfo(
            name: name,
            project: project,
            deviceType: deviceType,
            started: ISO8601DateFormatter().string(from: Date())
        )
        saveResources()
    }

    func removeSimulator(_ udid: String) {
        resources.simulators.removeValue(forKey: udid)
        saveResources()
    }

    func addDatabase(name: String, project: String, port: Int?) {
        resources.databases[name] = SharedResources.DatabaseInfo(
            project: project,
            port: port
        )
        saveResources()
    }

    func removeDatabase(_ name: String) {
        resources.databases.removeValue(forKey: name)
        saveResources()
    }

    // MARK: - Validation

    func isPortInUse(_ port: String) -> Bool {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "lsof -i :\(port) -t 2>/dev/null"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } catch {
            return false
        }
    }

    func cleanStaleEntries() {
        var modified = false

        // Check ports
        for port in resources.ports.keys {
            if !isPortInUse(port) {
                resources.ports.removeValue(forKey: port)
                modified = true
            }
        }

        // Check simulators (verify they're still booted)
        let bootedSimulators = getBootedSimulators()
        for udid in resources.simulators.keys {
            if !bootedSimulators.contains(udid) {
                resources.simulators.removeValue(forKey: udid)
                modified = true
            }
        }

        if modified {
            saveResources()
        }
    }

    private func getBootedSimulators() -> Set<String> {
        let task = Process()
        task.launchPath = "/usr/bin/xcrun"
        task.arguments = ["simctl", "list", "devices", "-j"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let devices = json["devices"] as? [String: [[String: Any]]] {
                var bootedUDIDs = Set<String>()
                for (_, deviceList) in devices {
                    for device in deviceList {
                        if let state = device["state"] as? String,
                           state == "Booted",
                           let udid = device["udid"] as? String {
                            bootedUDIDs.insert(udid)
                        }
                    }
                }
                return bootedUDIDs
            }
        } catch {
            print("Failed to get booted simulators: \(error)")
        }
        return []
    }

    // MARK: - Summary

    var summaryText: String {
        var parts: [String] = []

        if !resources.ports.isEmpty {
            parts.append("\(resources.ports.count) port\(resources.ports.count == 1 ? "" : "s")")
        }
        if !resources.databases.isEmpty {
            parts.append("\(resources.databases.count) db\(resources.databases.count == 1 ? "" : "s")")
        }
        if !resources.simulators.isEmpty {
            parts.append("\(resources.simulators.count) sim\(resources.simulators.count == 1 ? "" : "s")")
        }

        return parts.isEmpty ? "No active resources" : parts.joined(separator: ", ")
    }
}
