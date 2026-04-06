//
//  CycleTrackerWidget.swift
//  CycleTracker
//
//  Created by 何涛 on 2026-04-04.
//

import WidgetKit
import SwiftUI

// 轻量级数据模型，用于小组件
struct WidgetTrackedEvent: Codable {
    let name: String
    var history: [Date]
    var isPinned: Bool
    
    var daysSinceLastEvent: Int? {
        guard let lastDate = history.first else { return nil }
        return Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), pinnedEvent: WidgetTrackedEvent(name: "示例事件", history: [Date().addingTimeInterval(-5 * 24 * 3600)], isPinned: true))
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), pinnedEvent: loadPinnedEvent())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entries = [SimpleEntry(date: Date(), pinnedEvent: loadPinnedEvent())]
        // 每小时刷新一次
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadPinnedEvent() -> WidgetTrackedEvent? {
        let suiteName = "group.com.taohe.CycleTracker"
        let saveKey = "TrackedEventsData"
        let storage = UserDefaults(suiteName: suiteName) ?? .standard
        
        guard let data = storage.data(forKey: saveKey) else { return nil }
        do {
            let events = try JSONDecoder().decode([WidgetTrackedEvent].self, from: data)
            return events.first(where: { $0.isPinned })
        } catch {
            return nil
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let pinnedEvent: WidgetTrackedEvent?
}

struct CycleTrackerWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(spacing: 4) {
            if let event = entry.pinnedEvent {
                Text(event.name)
                    .font(.headline)
                    .foregroundColor(.secondary)

                if let days = event.daysSinceLastEvent {
                    Text("\(days)")
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .foregroundColor(colorForDays(days))
                    
                    Text("天之前")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("--")
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                    Text("暂无记录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("暂无置顶事件")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("请在 App 中设置")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
    
    private func colorForDays(_ days: Int) -> Color {
        switch days {
        case 0..<30: return .green
        case 30..<45: return .orange
        case 45...55: return .yellow
        default: return .red
        }
    }
}

struct CycleTrackerWidget: Widget {
    let kind: String = "CycleTrackerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CycleTrackerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("周期追踪")
        .description("显示置顶事件的距离天数")
        .supportedFamilies([.systemMedium])
    }
}

struct CycleTrackerWidget_Previews: PreviewProvider {
    static var previews: some View {
        CycleTrackerWidgetEntryView(entry: SimpleEntry(
            date: Date(),
            pinnedEvent: WidgetTrackedEvent(
                name: "剪头发",
                history: [Date().addingTimeInterval(-25 * 24 * 3600)],
                isPinned: true
            )
        ))
        .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
