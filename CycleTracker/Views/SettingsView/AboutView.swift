//
//  AboutView.swift
//  CycleTracker
//
//  Created by 何涛 on 2026-02-08.
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 20) {
                    Image(systemName: "repeat.circle.fill")
                        .font(.system(size: 70))
                        .foregroundColor(.blue)
                        .padding(.top)
                    Text("周期事件记录器")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("版本 1.0.0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section("简介") {
                Text(
                    "这是一个简洁的个人工具，用于追踪生活中那些不严格规律但又周期性发生的事件，例如剪头发、车辆保养、更换滤芯、体检等。"
                )
                .font(.body)
                .padding(.vertical, 4)
            }

            Section("主要功能") {
                Label("记录事件发生日期", systemImage: "checkmark.circle.fill")
                Label("清晰展示距离上次事件的天数", systemImage: "checkmark.circle.fill")
                Label("查看完整历史记录与间隔", systemImage: "checkmark.circle.fill")
                Label("数据导入、备份与恢复", systemImage: "checkmark.circle.fill")
            }

            Section("使用提示") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("• 在事件列表页点击任意事件，可“记录”新的一次或查看“历史”。")
                    Text("• 长按列表中的事件，可将其“置顶”或取消置顶。")
                    Text("• 置顶事件会显示在列表上方，并突出显示天数。")
                    Text("• 在设置页可管理您的数据。")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, 4)
            }

            Section {
                HStack {
                    Text("开发者")
                    Spacer()
                    Text("taoheeee")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("技术栈")
                    Spacer()
                    Text("SwiftUI, Swift 5.9")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}
