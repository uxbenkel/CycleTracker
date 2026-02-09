//
//  EventActionSheetView.swift
//  CycleTracker
//
//  Created by 何涛 on 2026-02-08.
//

import SwiftUI

// 扩展 EventActionSheetView 支持更多操作
struct EventActionSheetView: View {
    let event: TrackedEvent
    let onRecord: () -> Void
    let onHistory: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirm = false

    var body: some View {
        VStack(spacing: 16) {
            Text("操作: \(event.name)")
                .font(.headline)
                .padding(.top, 20)

            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    Button(action: onRecord) {
                        ActionButton(
                            icon: "checkmark.circle.fill",
                            title: "记录一次",
                            color: .blue
                        )
                    }

                    Button(action: onHistory) {
                        ActionButton(
                            icon: "clock.fill",
                            title: "查看历史",
                            color: .green
                        )
                    }

                    Button(action: onTogglePin) {
                        ActionButton(
                            icon: event.isPinned ? "pin.slash" : "pin",
                            title: event.isPinned ? "取消置顶" : "设为置顶",
                            color: .orange
                        )
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        ActionButton(
                            icon: "trash",
                            title: "删除事件",
                            color: .red
                        )
                    }
                }
                .padding(.horizontal)
            }

            Spacer()

            Button("取消") {
                dismiss()
            }
            .font(.headline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray5))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .alert("确认删除", isPresented: $showingDeleteConfirm) {
            Button("删除", role: .destructive) {
                onDelete()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定要删除事件'\(event.name)'吗？\n此操作将删除该事件的所有记录。")
        }
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .font(.title3)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding()
        .background(Color(.systemGray5))
        .cornerRadius(10)
    }
}
