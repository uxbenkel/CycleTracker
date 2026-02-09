//
//  SettingsView.swift
//  CycleTracker
//
//  Created by 何涛 on 2026-02-08.
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var eventStore: EventStore
    @State private var showingImportPicker = false
    @State private var showingExportPicker = false
    @State private var showingBackupRestorePicker = false
    @State private var backupDocument: CycleTrackerBackupDocument?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "提示"

    // 恢复相关状态
    @State private var showingRestoreConfirm = false
    @State private var pendingRestoreEvents: [TrackedEvent]? = nil

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: { showingImportPicker = true }) {
                        SettingsRowView(
                            iconName: "square.and.arrow.down",
                            title: "导入数据",
                            subtitle: "从文本文件导入事件记录"
                        )
                    }
                    .fileImporter(
                        isPresented: $showingImportPicker,
                        allowedContentTypes: [.importedText],
                        allowsMultipleSelection: false
                    ) { result in
                        handleImportFile(result: result)
                    }

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
                        defaultFilename:
                            "CycleTracker_Backup_\(formattedDate()).ctbackup"
                    ) { result in
                        handleExportFile(result: result)
                    }

                    Button(action: { showingBackupRestorePicker = true }) {
                        SettingsRowView(
                            iconName: "arrow.clockwise",
                            title: "恢复数据",
                            subtitle: "从备份文件恢复数据"
                        )
                    }
                    .fileImporter(
                        isPresented: $showingBackupRestorePicker,
                        allowedContentTypes: [.cycleTrackerBackup],
                        allowsMultipleSelection: false
                    ) { result in
                        handleRestoreBackup(result: result)
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
            .alert(alertTitle, isPresented: $showingAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
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
                    let eventCount = events.count
                    let totalRecords = events.reduce(0) {
                        $0 + $1.history.count
                    }

                    return Text(
                        "确定要恢复备份数据吗？\n\n" + "这将覆盖当前的所有数据。\n" + "备份包含：\n"
                            + "• \(eventCount) 个事件\n"
                            + "• \(totalRecords) 条历史记录\n\n" + "此操作不可撤销。"
                    )
                } else {
                    return Text("没有要恢复的数据。")
                }
            }
        }
    }

    // 导入文本文件的处理逻辑
    private func handleImportFile(result: Result<[URL], Error>) {
        do {
            guard let selectedFile = try result.get().first else {
                alertMessage = "未选择文件。"
                showingAlert = true
                return
            }

            // 重要：需要先请求安全访问权限
            guard selectedFile.startAccessingSecurityScopedResource() else {
                alertMessage = "无法访问文件，权限被拒绝。"
                showingAlert = true
                return
            }

            defer { selectedFile.stopAccessingSecurityScopedResource() }

            let fileContent = try String(
                contentsOf: selectedFile,
                encoding: .utf8
            )
            let dateStrings = fileContent.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "zh_CN")

            // 支持多种日期格式
            let dateFormats = [
                "yyyy-MM-dd",
                "yyyy/MM/dd",
                "yyyy.MM.dd",
                "yyyy年MM月dd日",
                "MM/dd/yyyy",
                "dd/MM/yyyy",
            ]

            var parsedDates: [Date] = []
            var failedDates: [String] = []

            for dateString in dateStrings {
                var dateParsed: Date?
                for format in dateFormats {
                    dateFormatter.dateFormat = format
                    if let date = dateFormatter.date(from: dateString) {
                        dateParsed = date
                        break
                    }
                }

                if let validDate = dateParsed {
                    parsedDates.append(validDate)
                } else {
                    failedDates.append(dateString)
                }
            }

            if !parsedDates.isEmpty {

                // 导入到置顶事件
                if let pinnedEvent = eventStore.pinnedEvent {
                    // 确保日期正确排序
                    let sortedDates = parsedDates.sorted(by: >)
                    eventStore.importDates(
                        sortedDates,
                        forEventId: pinnedEvent.id
                    )

                    alertTitle = "导入成功"
                    alertMessage =
                        "已成功将 \(parsedDates.count) 条日期记录导入到置顶事件「\(pinnedEvent.name)」。\n\n日期已按从新到旧排序。"
                    showingAlert = true
                } else {
                    // 如果没有置顶事件，导入到第一个事件
                    if let firstEventId = eventStore.events.first?.id,
                        let firstEvent = eventStore.events.first
                    {
                        let sortedDates = parsedDates.sorted(by: >)
                        eventStore.importDates(
                            sortedDates,
                            forEventId: firstEventId
                        )

                        alertTitle = "导入成功"
                        alertMessage =
                            "没有置顶事件，已将 \(parsedDates.count) 条日期记录导入到第一个事件「\(firstEvent.name)」。\n\n日期已按从新到旧排序。"
                        showingAlert = true
                    } else {
                        alertTitle = "导入失败"
                        alertMessage = "没有找到可导入的事件。请先创建一个事件。"
                        showingAlert = true
                    }
                }
            } else {
                alertTitle = "导入失败"
                if !failedDates.isEmpty {
                    alertMessage =
                        "文件中的日期格式无法识别。\n支持的格式：YYYY-MM-DD, YYYY/MM/DD, YYYY.MM.DD"
                } else {
                    alertMessage = "文件中没有找到有效的日期数据。"
                }
            }
            showingAlert = true

        } catch {
            alertTitle = "导入失败"
            alertMessage = "读取文件失败: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    // 准备备份文件
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
            alertMessage = "创建备份文件失败: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    private func handleExportFile(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            alertTitle = "备份成功"
            alertMessage = "备份文件已保存到：\n\(url.lastPathComponent)"
        case .failure(let error):
            alertTitle = "导出失败"
            alertMessage = "导出失败: \(error.localizedDescription)"
        }
        showingAlert = true
        backupDocument = nil
    }

    // 从备份文件恢复
    private func handleRestoreBackup(result: Result<[URL], Error>) {
        do {
            guard let selectedFile = try result.get().first else {
                alertMessage = "未选择文件。"
                showingAlert = true
                return
            }

            guard selectedFile.startAccessingSecurityScopedResource() else {
                alertMessage = "无法访问文件，权限被拒绝。"
                showingAlert = true
                return
            }

            defer { selectedFile.stopAccessingSecurityScopedResource() }

            let data = try Data(contentsOf: selectedFile)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let restoredEvents = try decoder.decode(
                [TrackedEvent].self,
                from: data
            )

            if !restoredEvents.isEmpty {
                // 显示确认对话框
                pendingRestoreEvents = restoredEvents
                showingRestoreConfirm = true
            } else {
                alertTitle = "恢复失败"
                alertMessage = "备份文件中没有找到有效数据。"
                showingAlert = true
            }

        } catch let DecodingError.dataCorrupted(context) {
            alertTitle = "恢复失败"
            alertMessage = "数据损坏: \(context.debugDescription)"
            showingAlert = true
        } catch let DecodingError.keyNotFound(key, context) {
            alertTitle = "恢复失败"
            alertMessage =
                "键 '\(key.stringValue)' 未找到: \(context.debugDescription)\n路径: \(context.codingPath)"
            showingAlert = true
        } catch let DecodingError.valueNotFound(value, context) {
            alertTitle = "恢复失败"
            alertMessage =
                "值 '\(value)' 未找到: \(context.debugDescription)\n路径: \(context.codingPath)"
            showingAlert = true
        } catch let DecodingError.typeMismatch(type, context) {
            alertTitle = "恢复失败"
            alertMessage =
                "类型 '\(type)' 不匹配: \(context.debugDescription)\n路径: \(context.codingPath)"
            showingAlert = true
        } catch {
            alertTitle = "恢复失败"
            alertMessage = "读取备份失败: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
}
