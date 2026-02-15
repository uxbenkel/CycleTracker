//
//  SettingsView.swift
//  CycleTracker
//
//  Created by 何涛 on 2026-02-08.
//

import SwiftUI
import UniformTypeIdentifiers

import UIKit
// MARK: - UIKit 文件选择器包装器 (针对重签名环境优化)
struct DocumentPicker: UIViewControllerRepresentable {
    let types: [UTType]
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // asCopy: true 模式会将文件拷贝到沙盒内，解决重签名权限无法读取外部文件的问题
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker
        init(_ parent: DocumentPicker) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onCancel()
        }
    }
}

// MARK: - 3. 主视图
struct SettingsView: View {
    @EnvironmentObject var eventStore: EventStore
    
    // 状态控制
    @State private var showingPicker = false
    @State private var pickerMode: PickerMode = .none
    enum PickerMode { case none, importTxt, restoreBackup }
    
    @State private var showingExportPicker = false
    @State private var backupDocument: CycleTrackerBackupDocument?
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "提示"

    // 恢复确认相关
    @State private var showingRestoreConfirm = false
    @State private var pendingRestoreEvents: [TrackedEvent]? = nil

    var body: some View {
        NavigationStack {
            List {
                Section {
                    // 按钮 1：导入文本数据
                    Button(action: {
                        pickerMode = .importTxt
                        showingPicker = true
                    }) {
                        SettingsRowView(
                            iconName: "square.and.arrow.down",
                            title: "导入数据",
                            subtitle: "从文本文件导入事件记录"
                        )
                    }

                    // 按钮 2：备份数据
                    Button(action: { prepareAndExportBackup() }) {
                        SettingsRowView(
                            iconName: "square.and.arrow.up",
                            title: "备份数据",
                            subtitle: "导出所有事件和记录为备份文件"
                        )
                    }
                    .fileExporter(
                        isPresented: $showingExportPicker,
                        document: backupDocument,
                        contentType: .cycleTrackerBackup,
                        defaultFilename: "CycleTracker_Backup_\(formattedDate()).ctbackup"
                    ) { result in
                        handleExportFile(result: result)
                    }

                    // 按钮 3：恢复备份
                    Button(action: {
                        pickerMode = .restoreBackup
                        showingPicker = true
                    }) {
                        SettingsRowView(
                            iconName: "arrow.clockwise",
                            title: "恢复数据",
                            subtitle: "从备份文件恢复数据"
                        )
                    }
                } header: {
                    Text("数据管理")
                } footer: {
                    Text("导入功能支持每行一个日期的文本文件(.txt)。备份文件为.ctbackup格式。")
                }

                Section {
                    NavigationLink(destination: AboutView()) {
                        SettingsRowView(
                            iconName: "info.circle",
                            title: "关于",
                            subtitle: "版本信息与说明"
                        )
                    }
                }
            }
            .navigationTitle("设置")
            
            // MARK: - UIKit 文件选择器 Sheet
            .sheet(isPresented: $showingPicker) {
                DocumentPicker(
                    // 根据模式限定可选类型
                    types: pickerMode == .importTxt ? [.plainText] : [.cycleTrackerBackup],
                    onPick: { url in
                        handlePickedFile(url: url)
                    },
                    onCancel: {
                        pickerMode = .none
                    }
                )
            }
            
            // 通用提示 Alert
            .alert(alertTitle, isPresented: $showingAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            
            // 恢复确认对话框
            .alert("恢复确认", isPresented: $showingRestoreConfirm) {
                Button("恢复", role: .destructive) {
                    if let events = pendingRestoreEvents {
                        eventStore.restoreEvents(events)
                        alertTitle = "恢复成功"
                        alertMessage = "已成功恢复 \(events.count) 个事件。"
                        showingAlert = true
                    }
                    pendingRestoreEvents = nil
                }
                Button("取消", role: .cancel) {
                    pendingRestoreEvents = nil
                }
            } message: {
                if let events = pendingRestoreEvents {
                    let totalRecords = events.reduce(0) { $0 + $1.history.count }
                    return Text("确定要恢复备份数据吗？\n\n这将覆盖当前的所有数据。\n包含：\n• \(events.count) 个事件\n• \(totalRecords) 条记录\n\n此操作不可撤销。")
                } else {
                    return Text("没有要恢复的数据。")
                }
            }
        }
    }

    // MARK: - 结果分发逻辑
    private func handlePickedFile(url: URL) {
        // 在主线程处理读取逻辑
        DispatchQueue.main.async {
            if pickerMode == .importTxt {
                processImport(url: url)
            } else if pickerMode == .restoreBackup {
                processRestore(url: url)
            }
            pickerMode = .none
        }
    }

    // MARK: - 导入文本逻辑
    private func processImport(url: URL) {
        do {
            let fileContent = try String(contentsOf: url, encoding: .utf8)
            let dateStrings = fileContent.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "zh_CN")
            let dateFormats = ["yyyy-MM-dd", "yyyy/MM/dd", "yyyy.MM.dd", "yyyy年MM月dd日", "MM/dd/yyyy", "dd/MM/yyyy"]

            var parsedDates: [Date] = []
            for dateString in dateStrings {
                var dateParsed: Date?
                for format in dateFormats {
                    dateFormatter.dateFormat = format
                    if let date = dateFormatter.date(from: dateString) {
                        dateParsed = date
                        break
                    }
                }
                if let validDate = dateParsed { parsedDates.append(validDate) }
            }

            if !parsedDates.isEmpty {
                let sortedDates = parsedDates.sorted(by: >)
                if let pinnedEvent = eventStore.pinnedEvent {
                    eventStore.importDates(sortedDates, forEventId: pinnedEvent.id)
                    alertTitle = "导入成功"
                    alertMessage = "已成功导入 \(parsedDates.count) 条日期记录到「\(pinnedEvent.name)」。"
                } else if let firstEvent = eventStore.events.first {
                    eventStore.importDates(sortedDates, forEventId: firstEvent.id)
                    alertTitle = "导入成功"
                    alertMessage = "已将记录导入到「\(firstEvent.name)」。"
                } else {
                    alertTitle = "错误"
                    alertMessage = "没有找到可导入的事件。请先创建一个事件。"
                }
            } else {
                alertTitle = "导入失败"
                alertMessage = "未能识别文件中的日期数据，请确保格式正确。"
            }
            showingAlert = true
        } catch {
            alertTitle = "错误"
            alertMessage = "读取失败: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    // MARK: - 恢复备份逻辑
    private func processRestore(url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let restoredEvents = try decoder.decode([TrackedEvent].self, from: data)

            if !restoredEvents.isEmpty {
                pendingRestoreEvents = restoredEvents
                showingRestoreConfirm = true
            } else {
                alertTitle = "失败"
                alertMessage = "备份文件内没有发现有效数据。"
                showingAlert = true
            }
        } catch {
            alertTitle = "解析失败"
            alertMessage = "无法识别该备份文件，可能已损坏或格式不正确。"
            showingAlert = true
        }
    }

    // MARK: - 备份导出逻辑
    private func prepareAndExportBackup() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(eventStore.events)
            backupDocument = CycleTrackerBackupDocument(data: data)
            showingExportPicker = true
        } catch {
            alertTitle = "备份失败"
            alertMessage = error.localizedDescription
            showingAlert = true
        }
    }

    private func handleExportFile(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            alertTitle = "备份成功"
            alertMessage = "已成功保存: \(url.lastPathComponent)"
        case .failure(let error):
            alertTitle = "导出失败"
            alertMessage = error.localizedDescription
        }
        showingAlert = true
        backupDocument = nil
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
}
