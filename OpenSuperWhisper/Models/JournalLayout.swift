import Foundation

/// Splits the history into the pinned latest recording and day groups (design/DESIGN.md section 4).
/// Pure: `now`, calendar and locale are injected so it tests without the system clock.
enum JournalLayout {
    struct DayGroup: Equatable {
        /// Start of the day in the injected calendar.
        let day: Date
        let title: String
        let recordings: [Recording]
    }

    struct Layout: Equatable {
        let pinned: Recording?
        let groups: [DayGroup]
    }

    /// While a search query is present nothing is pinned, so a match that would have been the latest
    /// still shows up in the day groups.
    static func layout(
        recordings: [Recording],
        searchQuery: String,
        now: Date,
        calendar: Calendar,
        locale: Locale
    ) -> Layout {
        let sorted = recordings.sorted { $0.timestamp > $1.timestamp }
        let isSearching = !searchQuery.isEmpty
        let pinned = isSearching ? nil : sorted.first
        let rest = isSearching ? sorted : Array(sorted.dropFirst())
        return Layout(pinned: pinned, groups: groups(of: rest, now: now, calendar: calendar, locale: locale))
    }

    /// Recordings arrive newest first; each group keeps that order.
    static func groups(of sorted: [Recording], now: Date, calendar: Calendar, locale: Locale) -> [DayGroup] {
        var result: [DayGroup] = []
        for recording in sorted {
            let day = calendar.startOfDay(for: recording.timestamp)
            if let last = result.last, last.day == day {
                result[result.count - 1] = DayGroup(day: day, title: last.title, recordings: last.recordings + [recording])
            } else {
                result.append(DayGroup(day: day, title: dayTitle(for: day, now: now, calendar: calendar, locale: locale),
                                       recordings: [recording]))
            }
        }
        return result
    }

    static func dayTitle(for date: Date, now: Date, calendar: Calendar, locale: Locale) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
