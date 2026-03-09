import SwiftUI

struct StatsView: View {
    @Environment(\.dismiss) private var dismiss
    var repository: WordRepository

    @State private var displayedMonth = Date()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                summarySection
                progressSection
                calendarSection
            }
            .padding(28)
        }
        .frame(minWidth: 760, minHeight: 720)
    }
}

private extension StatsView {
    var summary: ReviewStatsSummary {
        repository.reviewStatsSummary()
    }

    var recentProgress: [ReviewDailyProgress] {
        repository.recentDailyProgress(days: 7)
    }

    var calendarDays: [ReviewCalendarDay] {
        repository.reviewCalendarMonth(referenceDate: displayedMonth)
    }

    var monthTitle: String {
        displayedMonth.formatted(.dateTime.year().month(.wide))
    }

    var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Learning Stats")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Track daily progress, due reviews, and your current streak.")
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(BorderedProminentButtonStyle())
            .pointingCursor()
        }
    }

    var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatsCard(title: "Completed", value: "\(summary.completedToday)", accent: .blue)
                StatsCard(title: "Accuracy", value: summary.completedToday == 0 ? "0%" : "\(Int(summary.accuracyToday * 100))%", accent: .green)
                StatsCard(title: "Streak", value: "\(summary.streakDays) days", accent: .orange)
                StatsCard(title: "New Words", value: "\(summary.newWordsToday)", accent: .purple)
                StatsCard(title: "Reviews", value: "\(summary.reviewWordsToday)", accent: .mint)
                StatsCard(title: "Due / Overdue", value: "\(summary.dueToday) / \(summary.overdue)", accent: .red)
            }
        }
    }

    var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 7 Days")
                .font(.headline)

            VStack(spacing: 10) {
                ForEach(recentProgress) { day in
                    HStack(spacing: 12) {
                        Text(day.date.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .frame(width: 60, alignment: .leading)
                            .foregroundColor(.secondary)

                        GeometryReader { geometry in
                            let ratio = max(0.08, min(1.0, CGFloat(day.completedCount) / CGFloat(maxCompletedCount)))

                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.07))
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(AppTheme.Colors.primaryGradient)
                                    .frame(width: geometry.size.width * ratio)
                            }
                        }
                        .frame(height: 12)

                        Text("\(day.completedCount)")
                            .font(.caption.monospacedDigit())
                            .frame(width: 28, alignment: .trailing)

                        Text("\(Int(day.accuracy * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(14)
        }
    }

    var calendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Review Calendar")
                    .font(.headline)

                Spacer()

                Button {
                    displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(BorderedButtonStyle())
                .pointingCursor()

                Text(monthTitle)
                    .font(.subheadline.weight(.medium))
                    .frame(minWidth: 150)

                Button {
                    displayedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(BorderedButtonStyle())
                .pointingCursor()
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Calendar.current.shortWeekdaySymbols, id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(calendarDays) { day in
                    CalendarDayCard(day: day)
                }
            }
        }
    }

    var maxCompletedCount: Int {
        max(recentProgress.map(\.completedCount).max() ?? 0, 1)
    }
}

private struct StatsCard: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct CalendarDayCard: View {
    let day: ReviewCalendarDay

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(day.date.formatted(.dateTime.day()))
                .font(.caption.weight(day.isToday ? .bold : .medium))
                .foregroundColor(day.isCurrentMonth ? .primary : .secondary.opacity(0.6))

            if day.dueCount > 0 {
                Text("Due \(day.dueCount)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.red.opacity(0.9))
            } else {
                Text("Due 0")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary.opacity(0.7))
            }

            if day.completedCount > 0 {
                Text("Done \(day.completedCount)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.green.opacity(0.9))
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .topLeading)
        .padding(8)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(day.isToday ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.06), lineWidth: day.isToday ? 1.5 : 1)
        )
        .cornerRadius(10)
    }

    private var background: some ShapeStyle {
        if day.isToday {
            return AnyShapeStyle(Color.accentColor.opacity(0.1))
        }
        if !day.isCurrentMonth {
            return AnyShapeStyle(Color.primary.opacity(0.03))
        }
        return AnyShapeStyle(Color(nsColor: .controlBackgroundColor))
    }
}
