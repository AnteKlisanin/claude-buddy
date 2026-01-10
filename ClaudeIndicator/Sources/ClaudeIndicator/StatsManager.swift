import Foundation

struct DayStats: Codable {
    var date: String // "2024-01-15" format
    var alertCount: Int
    var dismissedCount: Int
    var clickedCount: Int
    var totalResponseTimeMs: Int // Sum of response times for averaging
    var responseCount: Int // Number of responses (for averaging)

    var averageResponseTime: Double? {
        guard responseCount > 0 else { return nil }
        return Double(totalResponseTimeMs) / Double(responseCount) / 1000.0
    }
}

struct StatsData: Codable {
    var days: [String: DayStats]
    var allTimeAlerts: Int
    var allTimeClicks: Int
    var allTimeDismisses: Int
    var firstUsed: Date?

    static var empty: StatsData {
        StatsData(days: [:], allTimeAlerts: 0, allTimeClicks: 0, allTimeDismisses: 0, firstUsed: nil)
    }
}

class StatsManager: ObservableObject {
    static let shared = StatsManager()

    @Published private(set) var stats: StatsData

    private let fileURL: URL
    private let dateFormatter: DateFormatter
    private var pendingAlertTimes: [String: Date] = [:] // alertID -> timestamp
    private let maxDaysToKeep = 30

    private init() {
        // Store in ~/.claude/claude-indicator-stats.json
        let claudeDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
        fileURL = claudeDir.appendingPathComponent("claude-indicator-stats.json")

        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // Load existing stats
        stats = StatsManager.load(from: fileURL) ?? .empty

        // Cleanup old days
        cleanupOldDays()
    }

    private static func load(from url: URL) -> StatsData? {
        guard let data = try? Data(contentsOf: url),
              let stats = try? JSONDecoder().decode(StatsData.self, from: data) else {
            return nil
        }
        return stats
    }

    private func save() {
        // Save asynchronously to not block
        let data = stats
        let url = fileURL
        DispatchQueue.global(qos: .utility).async {
            if let encoded = try? JSONEncoder().encode(data) {
                try? encoded.write(to: url, options: .atomic)
            }
        }
    }

    private func cleanupOldDays() {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -maxDaysToKeep, to: Date()) ?? Date()
        let cutoffString = dateFormatter.string(from: cutoffDate)

        stats.days = stats.days.filter { $0.key >= cutoffString }
        save()
    }

    private func todayKey() -> String {
        dateFormatter.string(from: Date())
    }

    private func ensureTodayExists() {
        let key = todayKey()
        if stats.days[key] == nil {
            stats.days[key] = DayStats(
                date: key,
                alertCount: 0,
                dismissedCount: 0,
                clickedCount: 0,
                totalResponseTimeMs: 0,
                responseCount: 0
            )
        }
    }

    // MARK: - Public API

    func recordAlert(id: String) {
        ensureTodayExists()
        let key = todayKey()
        stats.days[key]?.alertCount += 1
        stats.allTimeAlerts += 1
        pendingAlertTimes[id] = Date()

        if stats.firstUsed == nil {
            stats.firstUsed = Date()
        }

        save()
        objectWillChange.send()
    }

    func recordClick(id: String) {
        ensureTodayExists()
        let key = todayKey()
        stats.days[key]?.clickedCount += 1
        stats.allTimeClicks += 1

        recordResponseTime(for: id)
        save()
        objectWillChange.send()
    }

    func recordDismiss(id: String) {
        ensureTodayExists()
        let key = todayKey()
        stats.days[key]?.dismissedCount += 1
        stats.allTimeDismisses += 1

        recordResponseTime(for: id)
        save()
        objectWillChange.send()
    }

    private func recordResponseTime(for id: String) {
        guard let startTime = pendingAlertTimes.removeValue(forKey: id) else { return }
        let responseTime = Int(Date().timeIntervalSince(startTime) * 1000)

        let key = todayKey()
        stats.days[key]?.totalResponseTimeMs += responseTime
        stats.days[key]?.responseCount += 1
    }

    // MARK: - Computed Stats

    var todayStats: DayStats? {
        stats.days[todayKey()]
    }

    var thisWeekAlerts: Int {
        let calendar = Calendar.current
        let today = Date()
        var total = 0

        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let key = dateFormatter.string(from: date)
                total += stats.days[key]?.alertCount ?? 0
            }
        }
        return total
    }

    var last7DaysData: [(date: String, count: Int)] {
        let calendar = Calendar.current
        let today = Date()
        var result: [(String, Int)] = []

        for i in (0..<7).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                let key = dateFormatter.string(from: date)
                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "EEE"
                let label = dayFormatter.string(from: date)
                result.append((label, stats.days[key]?.alertCount ?? 0))
            }
        }
        return result
    }

    var streakDays: Int {
        let calendar = Calendar.current
        var streak = 0
        var date = Date()

        // Check if today has activity, if not start from yesterday
        let todayKey = dateFormatter.string(from: date)
        if stats.days[todayKey]?.alertCount ?? 0 == 0 {
            date = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        }

        while true {
            let key = dateFormatter.string(from: date)
            if stats.days[key]?.alertCount ?? 0 > 0 {
                streak += 1
                date = calendar.date(byAdding: .day, value: -1, to: date) ?? date
            } else {
                break
            }
        }
        return streak
    }
}
