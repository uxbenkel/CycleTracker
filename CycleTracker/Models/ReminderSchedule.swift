import Foundation

// 提醒频率：原始值表示间隔天数
enum ReminderInterval: Int, Codable, CaseIterable, Identifiable, Sendable {
    case one = 1, two = 2, three = 3, four = 4, five = 5
    case seven = 7, ten = 10, fourteen = 14, thirty = 30

    var id: Int { rawValue }
    var title: String { "每 \(rawValue) 天" }
}

// 提醒日期计算，不依赖系统通知，方便单独验证计时逻辑
struct ReminderSchedule {
    // 以事件最新一次记录日期为计时起点
    let anchor: Date
    let interval: ReminderInterval
    var calendar: Calendar = .current

    // 计算第 occurrence 次提醒的日期，次数从 1 开始
    func date(for occurrence: Int) -> Date? {
        // 按日历天数累加，适应夏令时切换，避免固定 24 小时造成时间偏移
        return calendar.date(byAdding: .day, value: occurrence * interval.rawValue, to: anchor)
    }

    // 获取接下来指定数量的提醒日期，跳过已经到期的提醒，不补发
    func upcoming(after now: Date, count: Int) -> [Date] {
        guard count > 0 else { return [] }
        let elapsed = (calendar.dateComponents([.day], from: anchor, to: now).day ?? 0) / interval.rawValue
        // 起点在未来时，也从首次提醒开始计算
        var occurrence = max(1, elapsed + 1)
        var result: [Date] = []
        while result.count < count, let next = date(for: occurrence) {
            if next > now { result.append(next) }
            occurrence += 1
        }
        return result
    }

    // 正文显示从最新记录到提醒日期的累计天数
    func body(eventName: String, at date: Date) -> String {
        let days = max(0, calendar.dateComponents([.day], from: anchor, to: date).day ?? 0)
        return "距离上次\(eventName)已经\(days)天了"
    }
}
