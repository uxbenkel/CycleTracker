//
//  EventHistoryView.swift
//  CycleTracker
//
//  Created by 何涛 on 2026-02-08.
//

import SwiftUI

struct EventHistoryView: View {

    let event: TrackedEvent
    @EnvironmentObject var eventStore: EventStore
    @Environment(\.dismiss) var dismiss

    @State private var expandedYears: Set<Int> = []
    @State private var showingDeleteAllConfirm = false
    @State private var showingDeleteConfirm: Date? = nil

    // 日期编辑相关状态
    @State private var showingEditDatePicker = false
    @State private var dateToEdit: Date? = nil
    @State private var newSelectedDate = Date()

    @State private var currentEvent: TrackedEvent

    init(event: TrackedEvent) {
        self.event = event
        _currentEvent = State(initialValue: event)
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()

    private var historyByYear: [Int: [TrackedEvent.HistoryEntry]] {
        let details = currentEvent.getEventHistoryDetails()
        let entries = details.enumerated().map { index, detail in
            TrackedEvent.HistoryEntry(
                date: detail.eventDate,
                daysSincePrevious: detail.daysSincePrevious,
                daysSinceNow: detail.daysSinceNow,
                originalIndex: index
            )
        }

        let calendar = Calendar.current
        return Dictionary(grouping: entries) { entry in
            calendar.component(.year, from: entry.date)
        }.mapValues { $0.sorted(by: { $0.date > $1.date }) }  // 确保新日期在上面
    }

    var body: some View {
        NavigationStack {
            Group {
                if currentEvent.history.isEmpty {
                    ContentUnavailableView(
                        "暂无历史记录",
                        systemImage: "clock.badge.xmark",
                        description: Text("点击'记录一次'开始追踪此事件")
                    )
                } else {
                    List {
                        ForEach(
                            Array(historyByYear.keys.sorted(by: >)),
                            id: \.self
                        ) { year in
                            Section {
                                if expandedYears.contains(year) {
                                    ForEach(
                                        historyByYear[year] ?? [],
                                        id: \.date
                                    ) { entry in
                                        HistoryRowView(
                                            entry: entry,
                                            onDelete: {
                                                showingDeleteConfirm =
                                                    entry.date
                                            }
                                        )
                                        // 添加左滑操作：删除和修改
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                showingDeleteConfirm = entry.date
                                            } label: {
                                                Label("删除", systemImage: "trash")
                                            }
                                            
                                            Button {
                                                dateToEdit = entry.date
                                                newSelectedDate = entry.date
                                                showingEditDatePicker = true
                                            } label: {
                                                Label("修改", systemImage: "pencil")
                                            }
                                            .tint(.blue)
                                        }
                                    }
                                }
                            } header: {
                                HStack {
                                    Text("\(year)年")
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    Spacer()

                                    Text(
                                        "共 \(historyByYear[year]?.count ?? 0) 条"
                                    )
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                    Button {
                                        withAnimation {
                                            if expandedYears.contains(year) {
                                                expandedYears.remove(year)
                                            } else {
                                                expandedYears.insert(year)
                                            }
                                        }
                                    } label: {
                                        Image(
                                            systemName: expandedYears.contains(
                                                year
                                            ) ? "chevron.down" : "chevron.right"
                                        )
                                        .foregroundColor(.gray)
                                    }
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation {
                                        if expandedYears.contains(year) {
                                            expandedYears.remove(year)
                                        } else {
                                            expandedYears.insert(year)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }.onChange(of: eventStore.events) { oldValue, newValue in
                if let updatedEvent = eventStore.events.first(where: {
                    $0.id == event.id
                }) {
                    currentEvent = updatedEvent
                }
            }
            .navigationTitle("\(event.name) 历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !event.history.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                showingDeleteAllConfirm = true
                            } label: {
                                Label("删除所有记录", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            // 修改日期的 Sheet
            .sheet(isPresented: $showingEditDatePicker) {
                NavigationStack {
                    Form {
                        DatePicker("发生日期", selection: $newSelectedDate, displayedComponents: .date)
                    }
                    .navigationTitle("修改记录日期")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") {
                                showingEditDatePicker = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("保存") {
                                if let oldDate = dateToEdit {
                                    eventStore.updateHistoryEntry(for: event.id, oldDate: oldDate, newDate: newSelectedDate)
                                }
                                showingEditDatePicker = false
                            }
                        }
                    }
                }
                .presentationDetents([.height(200)])
            }
            .alert(
                "删除记录",
                isPresented: .constant(showingDeleteConfirm != nil),
                presenting: showingDeleteConfirm
            ) { date in
                Button("删除", role: .destructive) {
                    deleteHistoryEntry(date: date)
                }
                Button("取消", role: .cancel) {
                    showingDeleteConfirm = nil
                }
            } message: { date in
                Text("确定要删除 \(dateFormatter.string(from: date)) 的记录吗？")
            }
            .alert("删除所有记录", isPresented: $showingDeleteAllConfirm) {
                Button("删除", role: .destructive) {
                    deleteAllHistory()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("确定要删除此事件的所有 \(event.history.count) 条历史记录吗？\n此操作不可撤销。")
            }
            .onAppear {
                // 默认展开最新年份
                if let latestYear = historyByYear.keys.max() {
                    expandedYears.insert(latestYear)
                }
            }
        }
    }

    private func deleteHistoryEntry(date: Date) {
        if let index = eventStore.events.firstIndex(where: { $0.id == event.id }
        ) {
            eventStore.events[index].history.removeAll { $0 == date }
            eventStore.saveEvents()
            currentEvent.history.removeAll { $0 == date }
        }
        showingDeleteConfirm = nil
    }

    private func deleteAllHistory() {
        if let index = eventStore.events.firstIndex(where: { $0.id == event.id }
        ) {
            eventStore.events[index].history.removeAll()
            eventStore.saveEvents()
            currentEvent.history.removeAll()

        }
    }
}
