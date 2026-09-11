import Foundation

// 独立回归测试：用 swiftc 与 TrackedEvent.swift、ReminderSchedule.swift 一起编译运行
@main
struct ReminderScheduleTests {
    @MainActor
    static func main() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 10))!

        // 验证全部正式频率及第二、三次提醒的累计天数
        for interval in ReminderInterval.allCases {
            let schedule = ReminderSchedule(anchor: anchor, interval: interval, calendar: calendar)
            let dates = schedule.upcoming(after: anchor, count: 3)
            for (index, date) in dates.enumerated() {
                let days = (index + 1) * interval.rawValue
                assert(calendar.dateComponents([.day], from: anchor, to: date).day == days)
                assert(schedule.body(eventName: "剪头发", at: date) == "距离上次剪头发已经\(days)天了")
            }
            // 重新打开 App 时不补发已经到期的提醒
            assert(schedule.upcoming(after: dates[1], count: 1).first == dates[2])
        }

        // 最新记录变化后重新计时，清除之前累计的周期
        let weekly = ReminderSchedule(anchor: anchor, interval: .seven, calendar: calendar)
        let newAnchor = calendar.date(byAdding: .day, value: 16, to: anchor)!
        let reset = ReminderSchedule(anchor: newAnchor, interval: .seven, calendar: calendar)
        let next = reset.upcoming(after: newAnchor, count: 1)[0]
        assert(next == calendar.date(byAdding: .day, value: 23, to: anchor))
        assert(reset.body(eventName: "健身", at: next) == "距离上次健身已经7天了")
        assert(next != weekly.upcoming(after: newAnchor, count: 1)[0])

        // 验证未来起点和空结果
        assert(weekly.upcoming(after: anchor.addingTimeInterval(-100), count: 1)[0] == weekly.date(for: 1))
        assert(weekly.upcoming(after: anchor, count: 0).isEmpty)

        // 跨夏令时仍按日历天数计算，保持记录对应的本地时刻
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let dstAnchor = calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 10))!
        let dst = ReminderSchedule(anchor: dstAnchor, interval: .one, calendar: calendar)
        let dstNext = dst.upcoming(after: dstAnchor, count: 1)[0]
        assert(calendar.component(.hour, from: dstNext) == 10)
        assert(dstNext.timeIntervalSince(dstAnchor) == 23 * 3600)
        assert(dst.body(eventName: "保养", at: dstNext) == "距离上次保养已经1天了")

        // 验证旧数据兼容、提醒设置的存储与备份恢复，以及删除提醒
        let legacy = """
        [{"id":"01234567-89AB-CDEF-0123-456789ABCDEF","name":"剪头发","history":[0],"isPinned":true}]
        """.data(using: .utf8)!
        var events = try JSONDecoder().decode([TrackedEvent].self, from: legacy)
        assert(events[0].reminderInterval == nil)
        // 已保存的测试提醒升级后关闭，事件及历史记录保持完整
        let retiredTest = String(data: legacy, encoding: .utf8)!
            .replacingOccurrences(of: "\"isPinned\":true", with: "\"isPinned\":true,\"reminderInterval\":0")
            .data(using: .utf8)!
        let migrated = try JSONDecoder().decode([TrackedEvent].self, from: retiredTest)
        assert(migrated == events)
        let migratedEncoder = JSONEncoder()
        migratedEncoder.dateEncodingStrategy = .iso8601
        let retiredBackup = String(data: try migratedEncoder.encode(events), encoding: .utf8)!
            .replacingOccurrences(of: "\"isPinned\":true", with: "\"isPinned\":true,\"reminderInterval\":0")
            .data(using: .utf8)!
        let migratedDecoder = JSONDecoder()
        migratedDecoder.dateDecodingStrategy = .iso8601
        assert(tryDecodeBackup(retiredBackup, decoder: migratedDecoder) == events)
        events[0].reminderInterval = .fourteen
        let stored = try JSONEncoder().encode(events)
        assert(tryDecode(stored)[0].reminderInterval == .fourteen)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let restored = try decoder.decode([TrackedEvent].self, from: encoder.encode(events))
        assert(restored[0].reminderInterval == .fourteen)
        events[0].reminderInterval = nil
        let removed = try JSONEncoder().encode(events)
        assert(tryDecode(removed)[0].reminderInterval == nil)
        print("PASS: intervals, cumulative content, reset, overdue dates, retired-test migration, future dates, DST, legacy data, backup round-trip, removal")
    }

    @MainActor
    static func tryDecode(_ data: Data) -> [TrackedEvent] {
        try! JSONDecoder().decode([TrackedEvent].self, from: data)
    }

    @MainActor
    static func tryDecodeBackup(_ data: Data, decoder: JSONDecoder) -> [TrackedEvent] {
        try! decoder.decode([TrackedEvent].self, from: data)
    }
}
