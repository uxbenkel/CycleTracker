import Combine
//
//  TrackedEvent.swift
//  CycleTracker
//
//  Created by 何涛 on 2026-02-08.
//
import Foundation
import SwiftUI

// 核心数据模型
struct TrackedEvent: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var name: String
    var history: [Date]
    var isPinned: Bool
    var colorHex: String?

    // 历史记录条目结构
    struct HistoryEntry {
        let date: Date
        let daysSincePrevious: Int?
        let daysSinceNow: Int
        let originalIndex: Int
    }

    init(
        id: UUID = UUID(),
        name: String,
        history: [Date] = [],
        isPinned: Bool = false,
        colorHex: String? = nil
    ) {
        self.id = id
        self.name = name
        self.history = history.sorted(by: >)
        self.isPinned = isPinned
        self.colorHex = colorHex
    }

    var daysSinceLastEvent: Int? {
        guard let lastDate = history.first else { return nil }
        return Calendar.current.dateComponents(
            [.day],
            from: lastDate,
            to: Date()
        ).day
    }

    func displayString() -> String {
        if let days = daysSinceLastEvent {
            return "\(days) 天前 \(name)"
        } else {
            return "从未记录过 \(name)"
        }
    }

    mutating func recordNewEvent(on date: Date = Date()) {
        // 插入到数组最前面，保持从新到旧
        history.insert(date, at: 0)
    }

    mutating func deleteHistoryEntry(at date: Date) {
        history.removeAll { $0 == date }
    }

    mutating func deleteAllHistory() {
        history.removeAll()
    }

    func getEventHistoryDetails() -> [(
        eventDate: Date, daysSincePrevious: Int?, daysSinceNow: Int
    )] {
        var details: [(Date, Int?, Int)] = []
        let calendar = Calendar.current
        let now = Date()

        // 确保日期从新到旧排列
        let sortedHistory = history.sorted(by: >)

        for (index, eventDate) in sortedHistory.enumerated() {
            let daysSinceNow =
                calendar.dateComponents([.day], from: eventDate, to: now).day
                ?? 0
            var daysSincePrevious: Int? = nil

            if index + 1 < sortedHistory.count {
                let previousDate = sortedHistory[index + 1]
                daysSincePrevious =
                    calendar.dateComponents(
                        [.day],
                        from: previousDate,
                        to: eventDate
                    ).day
            }
            details.append((eventDate, daysSincePrevious, daysSinceNow))
        }
        return details
    }
}
