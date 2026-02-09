//
//  UnpinnedEventRow.swift
//  CycleTracker
//
//  Created by 何涛 on 2026-02-08.
//

import SwiftUI

// 非置顶事件行 - 数字用外框/底色突出显示
struct UnpinnedEventRow: View {
    let event: TrackedEvent

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // 事件名称
            Text(event.name)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()

            // 天数显示 - 用胶囊形状突出显示
            if let days = event.daysSinceLastEvent {
                Text("\(days)")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .foregroundColor(.white)
                    .frame(minWidth: 44, minHeight: 28)
                    .background(
                        Capsule()
                            .fill(backgroundColorForDays(days))
                    )
                    .overlay(
                        Capsule()
                            .stroke(borderColorForDays(days), lineWidth: 1.5)
                    )

                Text("天前")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("--")
                    .font(.system(size: 18, weight: .bold, design: .default))
                    .foregroundColor(.white)
                    .frame(minWidth: 44, minHeight: 28)
                    .background(
                        Capsule()
                            .fill(Color.gray)
                    )

                Text("从未记录")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
    }

    private func backgroundColorForDays(_ days: Int) -> Color {
        switch days {
        case 0..<30: return Color.blue.opacity(0.8)
        case 30..<45: return Color.orange.opacity(0.8)
        case 45...55: return Color.yellow.opacity(0.8)
        default: return Color.red.opacity(0.8)
        }
    }

    private func borderColorForDays(_ days: Int) -> Color {
        switch days {
        case 0..<30: return Color.blue.opacity(0.3)
        case 30..<45: return Color.orange.opacity(0.3)
        case 45...55: return Color.yellow.opacity(0.3)
        default: return Color.red.opacity(0.3)
        }
    }
}
