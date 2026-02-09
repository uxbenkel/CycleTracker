//
//  EventRowView.swift
//  CycleTracker
//
//  Created by 何涛 on 2026-02-08.
//

import SwiftUI

// 普通事件行视图组件
struct EventRowView: View {
    let event: TrackedEvent

    var body: some View {
        HStack {
            // 事件名称
            Text(event.name)
                .font(.body)
            Spacer()
            // 天数显示，带有突出样式
            if let days = event.daysSinceLastEvent {
                Text("\(days)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(colorForDays(days).opacity(0.9))
                    )
                Text("天前")
                    .foregroundColor(.secondary)
            } else {
                Text("暂无记录")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
    }

    private func colorForDays(_ days: Int) -> Color {
        switch days {
        case 0..<30: return .blue
        case 30..<60: return .orange
        default: return .pink
        }
    }
}
