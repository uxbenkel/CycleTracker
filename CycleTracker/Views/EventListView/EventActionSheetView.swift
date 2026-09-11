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
    let onReminder: () -> Void
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

                    Button(action: onReminder) {
                        ActionButton(icon: "bell", title: "设置提醒", color: .purple)
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

            Button {
                dismiss()
            } label: {
                Text("取消")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        // 使用不透明的系统背景和按钮描边，深浅色下都能区分按钮与弹窗
        .background(Color(.systemGroupedBackground))
        .presentationBackground(Color(.systemGroupedBackground))
        .buttonStyle(EventActionButtonStyle())
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
                .font(.title3)
                .frame(width: 28)
            Text(title)
                .font(.title3)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding()
    }
}

// 统一操作按钮样式：浅色下使用淡细边框，不添加额外阴影，保留轻微按下反馈
struct EventActionButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? Color(.systemGray5) : Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        colorScheme == .light ? Color(.systemGray3).opacity(0.75) : Color(.systemGray2),
                        lineWidth: colorScheme == .light ? 0.5 : 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
