import Foundation

class FileWatcher {
    private let triggerFilePath: String
    private var fileDescriptor: Int32 = -1
    private var dispatchSource: DispatchSourceFileSystemObject?
    private let queue = DispatchQueue(label: "com.claudeindicator.filewatcher", qos: .utility)
    private var lastReadPosition: UInt64 = 0

    var onTrigger: ((pid_t) -> Void)?

    init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        triggerFilePath = homeDir.appendingPathComponent(".claude/claude-indicator-trigger").path
    }

    func start() {
        ensureTriggerFileExists()
        startWatching()
    }

    func stop() {
        dispatchSource?.cancel()
        dispatchSource = nil
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    private func ensureTriggerFileExists() {
        let claudeDir = (triggerFilePath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: claudeDir, withIntermediateDirectories: true)

        if !FileManager.default.fileExists(atPath: triggerFilePath) {
            FileManager.default.createFile(atPath: triggerFilePath, contents: nil)
        }

        // Initialize read position to end of file
        if let attrs = try? FileManager.default.attributesOfItem(atPath: triggerFilePath),
           let size = attrs[.size] as? UInt64 {
            lastReadPosition = size
        }
    }

    private func startWatching() {
        fileDescriptor = open(triggerFilePath, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            print("Failed to open trigger file for watching")
            return
        }

        dispatchSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .rename, .delete],
            queue: queue
        )

        dispatchSource?.setEventHandler { [weak self] in
            self?.handleFileChange()
        }

        dispatchSource?.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
            }
            self?.fileDescriptor = -1
        }

        dispatchSource?.resume()
    }

    private func handleFileChange() {
        // Re-check if file exists (might have been deleted and recreated)
        guard FileManager.default.fileExists(atPath: triggerFilePath) else {
            // File was deleted, recreate and restart
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.stop()
                self?.start()
            }
            return
        }

        // Read new content from file
        guard let fileHandle = FileHandle(forReadingAtPath: triggerFilePath) else { return }
        defer { try? fileHandle.close() }

        // Seek to last read position
        try? fileHandle.seek(toOffset: lastReadPosition)

        // Read new data
        guard let data = try? fileHandle.readToEnd(),
              !data.isEmpty,
              let content = String(data: data, encoding: .utf8) else {
            return
        }

        // Update read position
        lastReadPosition += UInt64(data.count)

        // Parse PIDs from new content
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let pid = Int32(trimmed), pid > 0 {
                DispatchQueue.main.async { [weak self] in
                    self?.onTrigger?(pid)
                }
            }
        }

        // Periodically clear the file to prevent it from growing too large
        cleanupTriggerFile()
    }

    private func cleanupTriggerFile() {
        // If file is larger than 10KB, clear it
        if let attrs = try? FileManager.default.attributesOfItem(atPath: triggerFilePath),
           let size = attrs[.size] as? UInt64,
           size > 10240 {
            try? "".write(toFile: triggerFilePath, atomically: true, encoding: .utf8)
            lastReadPosition = 0
        }
    }
}
