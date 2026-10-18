import XCTest
@testable import OpenSuperWhisper

final class JournalLayoutTests: XCTestCase {
    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0, _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    private func recording(_ timestamp: Date, text: String = "text") -> Recording {
        let id = UUID()
        return Recording(id: id, timestamp: timestamp, fileName: Recording.fileName(for: id),
                         transcription: text, duration: 1, status: .completed, progress: 1)
    }

    private var now: Date { date(2026, 10, 18, 15) }

    private func titles(_ recordings: [Recording], now: Date? = nil) -> [String] {
        JournalLayout.groups(of: recordings, now: now ?? self.now, calendar: calendar, locale: locale).map(\.title)
    }

    // MARK: - Day grouping

    func testTodayYesterdayThenFullDate() {
        let list = [recording(date(2026, 10, 18, 9)), recording(date(2026, 10, 17, 22)), recording(date(2026, 10, 16, 8))]
        XCTAssertEqual(titles(list), ["Today", "Yesterday", "October 16, 2026"])
    }

    func testMidnightBoundaries() {
        let justAfterMidnight = recording(date(2026, 10, 18, 0, 0, 0))
        let justBeforeMidnight = recording(date(2026, 10, 17, 23, 59, 59))
        XCTAssertEqual(titles([justAfterMidnight, justBeforeMidnight]), ["Today", "Yesterday"])

        let lastSecondOfToday = date(2026, 10, 18, 23, 59, 59)
        XCTAssertEqual(titles([recording(date(2026, 10, 18, 0, 0, 1))], now: lastSecondOfToday), ["Today"])
        let firstSecondTomorrow = date(2026, 10, 19, 0, 0, 0)
        XCTAssertEqual(titles([recording(date(2026, 10, 18, 23, 59, 59))], now: firstSecondTomorrow), ["Yesterday"])
    }

    func testOlderDateThisYear() {
        XCTAssertEqual(titles([recording(date(2026, 3, 2))]), ["March 2, 2026"])
    }

    func testDateFromPreviousYear() {
        XCTAssertEqual(titles([recording(date(2025, 12, 31, 23, 30))]), ["December 31, 2025"])
    }

    func testYesterdayAcrossYearBoundary() {
        let newYear = date(2027, 1, 1, 10)
        XCTAssertEqual(titles([recording(date(2026, 12, 31, 20))], now: newYear), ["Yesterday"])
    }

    func testFullDateFollowsLocale() {
        let groups = JournalLayout.groups(of: [recording(date(2026, 10, 16))], now: now, calendar: calendar,
                                          locale: Locale(identifier: "de_DE"))
        XCTAssertEqual(groups.map(\.title), ["16. Oktober 2026"])
    }

    func testTimeZoneDecidesTheDay() {
        // 02:00 UTC on Oct 18 is still Oct 17 evening in New York.
        var utc = calendar
        utc.timeZone = TimeZone(identifier: "UTC")!
        let instant = utc.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 2))!
        let rec = recording(instant)
        let nyNow = date(2026, 10, 18, 15)
        XCTAssertEqual(JournalLayout.groups(of: [rec], now: nyNow, calendar: calendar, locale: locale).map(\.title), ["Yesterday"])
        let utcNow = utc.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 15))!
        XCTAssertEqual(JournalLayout.groups(of: [rec], now: utcNow, calendar: utc, locale: locale).map(\.title), ["Today"])
    }

    func testRecordingsWithinAGroupStayNewestFirst() {
        let early = recording(date(2026, 10, 18, 8))
        let late = recording(date(2026, 10, 18, 14))
        let mid = recording(date(2026, 10, 18, 11))
        let groups = JournalLayout.groups(of: [late, mid, early], now: now, calendar: calendar, locale: locale)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].recordings.map(\.id), [late.id, mid.id, early.id])
    }

    func testLayoutSortsNewestFirstEvenIfInputIsUnsorted() {
        let old = recording(date(2026, 10, 16))
        let newest = recording(date(2026, 10, 18, 14))
        let middle = recording(date(2026, 10, 18, 9))
        let layout = JournalLayout.layout(recordings: [old, newest, middle], searchQuery: "", now: now, calendar: calendar, locale: locale)
        XCTAssertEqual(layout.pinned?.id, newest.id)
        XCTAssertEqual(layout.groups.map(\.title), ["Today", "October 16, 2026"])
        XCTAssertEqual(layout.groups[0].recordings.map(\.id), [middle.id])
    }

    // MARK: - Latest pinned split

    func testNewestIsPinnedAndExcludedFromGroups() {
        let newest = recording(date(2026, 10, 18, 14))
        let older = recording(date(2026, 10, 18, 9))
        let layout = JournalLayout.layout(recordings: [newest, older], searchQuery: "", now: now, calendar: calendar, locale: locale)
        XCTAssertEqual(layout.pinned?.id, newest.id)
        XCTAssertEqual(layout.groups.flatMap(\.recordings).map(\.id), [older.id])
    }

    func testEmptyListHasNoPinAndNoGroups() {
        let layout = JournalLayout.layout(recordings: [], searchQuery: "", now: now, calendar: calendar, locale: locale)
        XCTAssertNil(layout.pinned)
        XCTAssertTrue(layout.groups.isEmpty)
    }

    func testSingleRecordingPinsWithNoGroups() {
        let only = recording(date(2026, 10, 18, 9))
        let layout = JournalLayout.layout(recordings: [only], searchQuery: "", now: now, calendar: calendar, locale: locale)
        XCTAssertEqual(layout.pinned?.id, only.id)
        XCTAssertTrue(layout.groups.isEmpty)
    }

    // MARK: - Search

    func testSearchHasNoPinAndKeepsEveryMatchInGroups() {
        let newest = recording(date(2026, 10, 18, 14), text: "hello world")
        let older = recording(date(2026, 10, 17, 9), text: "hello again")
        let layout = JournalLayout.layout(recordings: [newest, older], searchQuery: "hello", now: now, calendar: calendar, locale: locale)
        XCTAssertNil(layout.pinned)
        XCTAssertEqual(layout.groups.map(\.title), ["Today", "Yesterday"])
        XCTAssertEqual(layout.groups.flatMap(\.recordings).map(\.id), [newest.id, older.id])
    }

    func testSearchWithSingleMatchStillShowsItInAGroup() {
        let only = recording(date(2026, 10, 18, 9))
        let layout = JournalLayout.layout(recordings: [only], searchQuery: "x", now: now, calendar: calendar, locale: locale)
        XCTAssertNil(layout.pinned)
        XCTAssertEqual(layout.groups.flatMap(\.recordings).map(\.id), [only.id])
    }
}
