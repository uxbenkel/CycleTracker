import Foundation
import UserNotifications

// App 在前台时也展示通知横幅并播放提示音
final class ReminderNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}

@MainActor
// 统一管理事件的本地通知调度
final class ReminderNotifications {
    // 通过前缀识别本功能的通知，清理时保留其他通知
    static let prefix = "cycletracker.reminder."
    private let center = UNUserNotificationCenter.current()
    // 通知中心弱引用代理，需要在这里持有，避免代理被释放
    private let delegate = ReminderNotificationDelegate()
    private var pendingUpdate: Task<String?, Never>?

    init() { center.delegate = delegate }

    // 用户保存提醒时申请通知权限
    func requestPermission() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    // 按顺序执行更新，避免旧数据的异步调度覆盖新记录；返回 nil 表示成功
    func synchronize(events: [TrackedEvent]) async -> String? {
        let previous = pendingUpdate
        let task = Task { @MainActor in
            _ = await previous?.value
            return await self.replaceRequests(events: events)
        }
        pendingUpdate = task
        return await task.value
    }

    // 清除旧的待发送提醒，再根据当前事件和最新记录重新安排
    private func replaceRequests(events: [TrackedEvent]) async -> String? {
        let pending = await center.pendingNotificationRequests()
        let owned = pending.filter { $0.identifier.hasPrefix(Self.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: owned.map(\.identifier))

        // 清理通知中心中已经失效的提醒，例如事件被删除、最新日期或频率发生变化
        let delivered = await center.deliveredNotifications()
        let validKeys = Set(events.compactMap { event -> String? in
            guard let interval = event.reminderInterval, let anchor = event.history.max() else { return nil }
            return key(event: event, interval: interval, anchor: anchor)
        })
        center.removeDeliveredNotifications(withIdentifiers: delivered.compactMap {
            guard $0.request.identifier.hasPrefix(Self.prefix),
                  !validKeys.contains($0.request.content.userInfo["scheduleKey"] as? String ?? "") else { return nil }
            return $0.request.identifier
        })

        // 没有历史记录的事件暂不安排通知，写入记录后会重新调度
        let active = events.filter { $0.reminderInterval != nil && !$0.history.isEmpty }
        guard !active.isEmpty else { return nil }
        let settings = await center.notificationSettings()
        guard [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus) else {
            return "通知权限未开启，请前往系统设置允许通知。"
        }
        // 按系统 64 条待发送通知的上限预留余量，并扣除其他功能已占用的数量
        let capacity = max(0, 60 - (pending.count - owned.count))
        guard active.count <= capacity else { return "提醒数量已达到系统上限，请减少启用提醒的事件。" }
        let now = Date()
        do {
            for (index, event) in active.enumerated() {
                guard let interval = event.reminderInterval, let anchor = event.history.max() else { continue }
                let schedule = ReminderSchedule(anchor: anchor, interval: interval)
                // 各事件平分可用名额，剩余名额依次分配，避免单个事件占满队列
                let count = capacity / active.count + (index < capacity % active.count ? 1 : 0)
                for date in schedule.upcoming(after: now, count: count) {
                    let content = UNMutableNotificationContent()
                    content.title = "周期提醒"
                    content.body = schedule.body(eventName: event.name, at: date)
                    content.sound = .default
                    // 保存所属事件、计划发送时间和设置标识，供界面展示及失效通知清理使用
                    content.userInfo = ["eventID": event.id.uuidString,
                                        "scheduledAt": date.timeIntervalSince1970,
                                        "scheduleKey": key(event: event, interval: interval, anchor: anchor)]
                    // 使用单次通知，让每次提醒显示不同的累计天数正文；至少延后 1 秒触发
                    let trigger = UNTimeIntervalNotificationTrigger(
                        timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
                    let request = UNNotificationRequest(
                        identifier: Self.prefix + event.id.uuidString + "." + String(date.timeIntervalSince1970),
                        content: content, trigger: trigger)
                    try await center.add(request)
                }
            }
            return nil
        } catch {
            return "安排提醒失败：\(error.localizedDescription)"
        }
    }

    // 组合当前提醒的关键属性，属性变化后旧通知的标识就不再有效
    private func key(event: TrackedEvent, interval: ReminderInterval, anchor: Date) -> String {
        "\(event.id.uuidString)|\(anchor.timeIntervalSince1970)|\(interval.rawValue)|\(event.name)"
    }
}
