//
//  PinnedEventView.swift
//  CycleTracker
//
//  Created by 何涛 on 2026-02-08.
//

import SwiftUI

// 置顶事件视图 - 使用大号数字显示
struct PinnedEventView: View {
    let event: TrackedEvent

    var body: some View {
        VStack(spacing: 4) {
            Spacer()

            Text(event.name)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            if let days = event.daysSinceLastEvent {
                // 大号数字显示
                Text("\(days)")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .foregroundColor(colorForDays(days))
                    .padding(.vertical, 5)

                Text("天之前")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
            } else {
                Text("--")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                    .padding(.vertical, 5)

                Text("暂无记录")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
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
