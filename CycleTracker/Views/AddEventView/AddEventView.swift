//
//  AddEventView.swift
//  CycleTracker
//
//  Created by 何涛 on 2026-02-08.
//

import SwiftUI

struct AddEventView: View {
    @EnvironmentObject var eventStore: EventStore
    @Environment(\.dismiss) var dismiss
    @State private var eventName = ""
    @State private var isPinned = false
    @FocusState private var isNameFieldFocused: Bool
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("事件名称，例如：剪头发、健身、车辆保养", text: $eventName)
                        .focused($isNameFieldFocused)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isNameFieldFocused = true
                            }
                        }
                } header: {
                    Text("事件名称")
                } footer: {
                    Text("输入你想要周期性记录的事情。")
                }

                Section {
                    Toggle("置顶显示", isOn: $isPinned)
                } footer: {
                    Text("注意：设置新事件为置顶时，会自动取消当前置顶事件。")
                }
            }
            .navigationTitle("新建事件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        addNewEvent()
                    }
                    .disabled(eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("错误", isPresented: $showingError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func addNewEvent() {
        let trimmedName = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "事件名称不能为空"
            showingError = true
            return
        }
        
        // 检查是否已存在同名事件
        if eventStore.events.contains(where: { $0.name == trimmedName }) {
            errorMessage = "已存在同名事件，请使用不同的名称"
            showingError = true
            return
        }
        
        // 检查置顶状态是否会导致冲突
        if isPinned && eventStore.events.contains(where: { $0.isPinned }) {
        }
        
        eventStore.addEvent(name: trimmedName, isPinned: isPinned)
        dismiss()
    }
}
