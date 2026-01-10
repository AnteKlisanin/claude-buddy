import SwiftUI

struct StatsView: View {
    @ObservedObject var stats = StatsManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    Text("Activity Stats")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 16)

                // Today's Stats
                todaySection

                // Weekly Chart
                weeklyChartSection

                // All Time Stats
                allTimeSection

                Spacer(minLength: 16)
            }
        }
        .frame(width: 320, height: 420)
    }

    private var todaySection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Today", icon: "sun.max.fill")

            HStack(spacing: 16) {
                StatCard(
                    value: "\(stats.todayStats?.alertCount ?? 0)",
                    label: "Alerts",
                    icon: "bell.fill",
                    color: .blue
                )

                StatCard(
                    value: "\(stats.todayStats?.clickedCount ?? 0)",
                    label: "Clicked",
                    icon: "hand.tap.fill",
                    color: .green
                )

                StatCard(
                    value: formatResponseTime(stats.todayStats?.averageResponseTime),
                    label: "Avg Response",
                    icon: "clock.fill",
                    color: .orange
                )
            }
            .padding(.horizontal)
        }
    }

    private var weeklyChartSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Last 7 Days", icon: "calendar")

            let data = stats.last7DaysData
            let maxCount = max(data.map { $0.count }.max() ?? 1, 1)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(data, id: \.date) { day in
                    VStack(spacing: 4) {
                        Text("\(day.count)")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(day.count > 0 ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 30, height: max(4, CGFloat(day.count) / CGFloat(maxCount) * 80))

                        Text(day.date)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 120)
            .padding(.horizontal)
        }
    }

    private var allTimeSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "All Time", icon: "infinity")

            VStack(spacing: 8) {
                AllTimeRow(label: "Total Alerts", value: "\(stats.stats.allTimeAlerts)", icon: "bell.fill")
                AllTimeRow(label: "Clicked", value: "\(stats.stats.allTimeClicks)", icon: "hand.tap.fill")
                AllTimeRow(label: "Dismissed", value: "\(stats.stats.allTimeDismisses)", icon: "xmark.circle.fill")
                AllTimeRow(label: "Current Streak", value: "\(stats.streakDays) days", icon: "flame.fill")

                if let firstUsed = stats.stats.firstUsed {
                    AllTimeRow(label: "Using Since", value: formatDate(firstUsed), icon: "calendar.badge.clock")
                }
            }
            .padding(.horizontal)
        }
    }

    private func formatResponseTime(_ time: Double?) -> String {
        guard let time = time else { return "-" }
        if time < 60 {
            return "\(Int(time))s"
        } else {
            return "\(Int(time / 60))m"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .font(.caption)
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal)
    }
}

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .monospacedDigit()

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
        )
    }
}

struct AllTimeRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)

            Text(label)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    StatsView()
}
