//
//  HistoryRowView.swift
//  CycleTracker
//
//  Created by 何涛 on 2026-02-08.
//

import SwiftUI

// 历史记录行视图
struct HistoryRowView: View {
    let entry: TrackedEvent.HistoryEntry
    let onDelete: () -> Void

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(dateFormatter.string(from: entry.date))
                    .font(.headline)

                HStack(spacing: 12) {
                    if let interval = entry.daysSincePrevious {
                        Text("间隔: \(interval)天")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                    } else {
                        Text("首次记录")
                            .font(.subheadline)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(6)
                    }

                    Text("距今: \(entry.daysSinceNow)天")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}
