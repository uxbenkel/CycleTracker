//
//  EventStore.swift
//  CycleTracker
//
//  Created by 何涛 on 2026-02-08.
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class EventStore: ObservableObject {
    @Published var events: [TrackedEvent] = []

    // 使用 App Group 共享数据，以便小组件访问
    private let suiteName = "group.com.taohe.CycleTracker"
    private let saveKey = "TrackedEventsData"
    private var storage: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    init() {
        loadEvents()
        if events.isEmpty {
            let sampleEvent = TrackedEvent(
                name: "剪头发",
                history: [Date().addingTimeInterval(-50 * 24 * 3600)],
                isPinned: true,
                colorHex: "#007AFF"
            )
            events.append(sampleEvent)
            saveEvents()
        }
    }

        // 如果要置顶，先取消当前所有置顶 支持自定义初始日期的添加方法
    func addEvent(name: String, isPinned: Bool = false, initialDate: Date = Date()) {
        if isPinned {
            for index in events.indices {
                events[index].isPinned = false
            }
        }

        // 置顶事件应该显示在最前面
        var newEvent = TrackedEvent(name: name, isPinned: isPinned)
        newEvent.recordNewEvent(on: initialDate)
        if isPinned {
            events.insert(newEvent, at: 0)
        } else {
            events.append(newEvent)
        }
        saveEvents()
    }

    // 删除事件
    func deleteEvent(at indexSet: IndexSet) {
        events.remove(atOffsets: indexSet)
        saveEvents()
    }

    // 移动事件
    func moveEvent(from source: IndexSet, to destination: Int) {
        events.move(fromOffsets: source, toOffset: destination)
        saveEvents()
    }

    // 记录一次事件
    func recordEvent(for eventId: UUID, on date: Date = Date()) {
        if let index = events.firstIndex(where: { $0.id == eventId }) {
            events[index].recordNewEvent(on: date)
            events[index].history.sort(by: >)
            saveEvents()
        }
    }

    // 更新历史记录中的日期
    func updateHistoryEntry(for eventId: UUID, oldDate: Date, newDate: Date) {
        if let index = events.firstIndex(where: { $0.id == eventId }) {
            if let dateIndex = events[index].history.firstIndex(where: { $0 == oldDate }) {
                events[index].history[dateIndex] = newDate
                events[index].history.sort(by: >)
                saveEvents()
            }
        }
    }

    // 更新事件属性
    func updateEvent(
        eventId: UUID,
        name: String? = nil,
        isPinned: Bool? = nil,
        colorHex: String? = nil
    ) {
        if let index = events.firstIndex(where: { $0.id == eventId }) {
            if let newName = name {
                events[index].name = newName
            }

            // 重要：处理置顶逻辑
            if let pinned = isPinned {
                if pinned {
                    // 如果要设置为置顶，先取消当前所有置顶
                    for i in events.indices {
                        events[i].isPinned = false
                    }
                }
                events[index].isPinned = pinned
            }

            if let color = colorHex {
                events[index].colorHex = color
            }
            saveEvents()
        }
    }

    // 持久化保存
    func saveEvents() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(events)
            storage.set(data, forKey: saveKey)
        } catch {
            print("保存事件失败: \(error)")
        }
    }

    // 从 storage 加载
    private func loadEvents() {
        do {
            guard let data = storage.data(forKey: saveKey) else {
                events = []
                return
            }
            let decoder = JSONDecoder()
            let decoded = try decoder.decode([TrackedEvent].self, from: data)
            events = decoded
        } catch {
            print("加载事件失败: \(error)")
            events = []
        }
    }

    // 获取置顶事件
    var pinnedEvent: TrackedEvent? {
        events.first(where: { $0.isPinned })
    }

    // 获取非置顶事件
    var unpinnedEvents: [TrackedEvent] {
        events.filter { !$0.isPinned }
    }

    // 修改恢复事件的方法
    func restoreEvents(_ newEvents: [TrackedEvent]) {
        events = newEvents
        saveEvents()
    }

    // 导入日期记录
    func importDates(_ dates: [Date], forEventId eventId: UUID) {
        guard let index = events.firstIndex(where: { $0.id == eventId }) else {
            return
        }

        // 确保日期从新到旧排序
        let sortedDates = dates.sorted(by: >)

        // 将新日期添加到历史记录中
        events[index].history.append(contentsOf: sortedDates)
        // 重新排序确保正确顺序
        events[index].history.sort(by: >)
        // 移除可能的重复项
        events[index].history = Array(Set(events[index].history)).sorted(by: >)

        saveEvents()
    }
}
