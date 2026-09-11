import SwiftUI
import UserNotifications

// 事件提醒设置弹窗，支持频率选择、当前状态查看和删除提醒
struct ReminderSettingsView: View {
    let eventID: UUID
    @EnvironmentObject private var eventStore: EventStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: ReminderInterval = .one
    // 仅首次进入时回填频率，避免从系统设置返回后覆盖尚未保存的选择
    @State private var initialized = false
    @State private var isSaving = false
    @State private var message: String?
    // 从系统待发送通知中读取的计划日期，按时间升序排列
    @State private var dates: [Date] = []
    @State private var permissionDenied = false

    // 按 ID 获取最新事件，保存后立即展示更新的设置
    private var event: TrackedEvent? { eventStore.events.first { $0.id == eventID } }

    var body: some View {
        NavigationStack {
            Form {
                Section("提醒频率") {
                    Picker("每隔多久提醒一次", selection: $selection) {
                        ForEach(ReminderInterval.allCases) { interval in
                            Text(interval.title).tag(interval)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 150)
                }
                Section {
                    LabeledContent("提醒", value: event?.reminderInterval?.title ?? "未设置")
                    if let anchor = event?.history.max() {
                        LabeledContent("最新记录", value: formatted(anchor))
                    } else {
                        Text("暂无记录，添加记录后开始提醒。")
                    }
                    if event?.reminderInterval != nil {
                        // 每分钟排除已到期的日期，更新“下次提醒”的显示
                        TimelineView(.periodic(from: .now, by: 60)) { context in
                            let upcoming = dates.filter { $0 > context.date }
                            LabeledContent("下次提醒", value: upcoming.first.map(formatted) ?? "暂无已安排提醒")
                            if let last = upcoming.last {
                                LabeledContent("已安排至", value: formatted(last))
                            }
                        }
                    }
                    if permissionDenied {
                        Button("前往系统设置开启通知") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                    if let error = eventStore.reminderError {
                        Text(error).foregroundStyle(.red)
                    }
                } header: {
                    Text("当前设置")
                } footer: {
                    Text("从最新记录日期起每隔指定天数提醒，过去的提醒不会补发。新增、修改或导入记录后自动重新计算。打开 App 会补充后续提醒，请在已安排日期前再次打开。")
                }
                if event?.reminderInterval != nil {
                    Section {
                        Button("删除提醒", role: .destructive) {
                            Task {
                                isSaving = true
                                await eventStore.setReminder(for: eventID, interval: nil)
                                isSaving = false
                                dismiss()
                            }
                        }
                    }
                }
            }
            .disabled(isSaving)
            .navigationTitle("设置提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }.disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "保存中…" : "保存") {
                        Task { await save() }
                    }.disabled(isSaving || event == nil)
                }
            }
            // 进入页面或切换前后台时刷新权限和通知状态
            .task(id: scenePhase) {
                if !initialized {
                    selection = event?.reminderInterval ?? .one
                    initialized = true
                }
                await loadStatus()
            }
            .alert("提醒设置", isPresented: Binding(
                get: { message != nil }, set: { if !$0 { message = nil } }
            )) {
                Button("确定", role: .cancel) { message = nil }
            } message: { Text(message ?? "") }
        }
    }

    // 获得通知权限后保存频率，等待调度完成再刷新界面
    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            guard try await eventStore.reminders.requestPermission() else {
                permissionDenied = true
                message = "请先在系统设置中允许通知，再保存提醒。"
                return
            }
            await eventStore.setReminder(for: eventID, interval: selection)
            await loadStatus()
            if let error = eventStore.reminderError { message = error }
        } catch { message = "无法开启提醒：\(error.localizedDescription)" }
    }

    // 读取系统权限及该事件实际待发送的通知，避免只展示推算日期
    private func loadStatus() async {
        let center = UNUserNotificationCenter.current()
        permissionDenied = await center.notificationSettings().authorizationStatus == .denied
        let requests = await center.pendingNotificationRequests()
        dates = requests.filter { $0.content.userInfo["eventID"] as? String == eventID.uuidString }
            .compactMap { request in
                (request.content.userInfo["scheduledAt"] as? Double).map(Date.init(timeIntervalSince1970:))
            }.sorted()
    }

    // 日期显示到分钟，与正式提醒的查看需求保持一致
    private func formatted(_ date: Date) -> String {
        date.formatted(.dateTime.year().month().day().hour().minute())
    }
}
