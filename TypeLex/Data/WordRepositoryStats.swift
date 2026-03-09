import Foundation

struct WordRepositoryStatsCalculator {
    let words: [WordEntry]
    let reviewEvents: [ReviewEvent]

    func reviewStatsSummary(now: Date = Date(), calendar: Calendar = .current) -> ReviewStatsSummary {
        let startOfToday = calendar.startOfDay(for: now)
        let todayEvents = reviewEvents.filter { calendar.isDate($0.reviewedAt, inSameDayAs: now) }
        let successfulToday = todayEvents.filter(\.wasSuccessful).count
        let dueToday = words.filter { word in
            guard let nextReviewAt = word.nextReviewAt else { return false }
            return calendar.isDate(nextReviewAt, inSameDayAs: now)
        }.count
        let overdue = words.filter { word in
            guard let nextReviewAt = word.nextReviewAt else { return false }
            return nextReviewAt < startOfToday
        }.count

        return ReviewStatsSummary(
            completedToday: todayEvents.count,
            accuracyToday: todayEvents.isEmpty ? 0 : Double(successfulToday) / Double(todayEvents.count),
            newWordsToday: todayEvents.filter(\.wasNewWord).count,
            reviewWordsToday: todayEvents.filter { !$0.wasNewWord }.count,
            dueToday: dueToday,
            overdue: overdue,
            streakDays: currentStreakDays(calendar: calendar, now: now)
        )
    }

    func recentDailyProgress(days: Int = 7, now: Date = Date(), calendar: Calendar = .current) -> [ReviewDailyProgress] {
        guard days > 0 else { return [] }

        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -(days - offset - 1), to: now) else { return nil }
            let dayEvents = reviewEvents.filter { calendar.isDate($0.reviewedAt, inSameDayAs: date) }

            return ReviewDailyProgress(
                date: calendar.startOfDay(for: date),
                completedCount: dayEvents.count,
                successfulCount: dayEvents.filter(\.wasSuccessful).count,
                newWordCount: dayEvents.filter(\.wasNewWord).count
            )
        }
    }

    func reviewCalendarMonth(referenceDate: Date = Date(), calendar: Calendar = .current) -> [ReviewCalendarDay] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: referenceDate),
            let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
            let lastWeekAnchor = calendar.date(byAdding: DateComponents(day: -1), to: monthInterval.end),
            let lastWeek = calendar.dateInterval(of: .weekOfMonth, for: lastWeekAnchor)
        else {
            return []
        }

        var days: [ReviewCalendarDay] = []
        var cursor = firstWeek.start

        while cursor < lastWeek.end {
            let dueCount = words.filter { word in
                guard let nextReviewAt = word.nextReviewAt else { return false }
                return calendar.isDate(nextReviewAt, inSameDayAs: cursor)
            }.count

            let completedCount = reviewEvents.filter { calendar.isDate($0.reviewedAt, inSameDayAs: cursor) }.count

            days.append(
                ReviewCalendarDay(
                    date: cursor,
                    dueCount: dueCount,
                    completedCount: completedCount,
                    isCurrentMonth: calendar.isDate(cursor, equalTo: referenceDate, toGranularity: .month),
                    isToday: calendar.isDateInToday(cursor)
                )
            )

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = nextDay
        }

        return days
    }

    private func currentStreakDays(calendar: Calendar, now: Date) -> Int {
        var streak = 0
        var currentDate = calendar.startOfDay(for: now)

        while true {
            let hasEvent = reviewEvents.contains { calendar.isDate($0.reviewedAt, inSameDayAs: currentDate) }
            guard hasEvent else { break }
            streak += 1

            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
            currentDate = previousDay
        }

        return streak
    }
}
