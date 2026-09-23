//
//  EventListView.swift
//  CycleTracker
//
//  Created by 何涛 on 2026-02-08.
//

import SwiftUI

struct EventListView: View {
    @EnvironmentObject var eventStore: EventStore
    @State private var showingAddEvent = false
    @State private var showingHistoryForEvent: TrackedEvent? = nil
    // 选中事件同时决定弹窗内容和是否展示，避免首次打开时状态不同步
    @State private var selectedEvent: TrackedEvent? = nil
    @State private var isEditing = false
    @State private var reminderEvent: TrackedEvent?
    // 暂存后续操作，等待操作弹窗完全关闭后再执行
    @State private var pendingAction: PendingAction?

    private enum PendingAction {
        case history(TrackedEvent)
        case reminder(TrackedEvent)
        case delete(TrackedEvent)
    }

    // 添加加载状态
    @State private var isLoading = true

    var body: some View {

        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // 上部1/3空间：置顶事件
                    if let pinnedEvent = eventStore.pinnedEvent {
                        PinnedEventView(event: pinnedEvent)
                            .frame(height: geometry.size.height * 0.33)
                            .onTapGesture {
                                if !isEditing {
                                    selectedEvent = pinnedEvent
                                }
                            }
                            .contextMenu {
                                Button(action: {
                                    eventStore.updateEvent(
                                        eventId: pinnedEvent.id,
                                        isPinned: false
                                    )
                                }) {
                                    Label(
                                        "取消置顶",
                                        systemImage: "pin.slash"
                                    )
                                }

                                Button(
                                    role: .destructive,
                                    action: {
                                        // 删除确认在下面的事件操作弹窗中处理
                                        selectedEvent = pinnedEvent
                                    }
                                ) {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "pin.slash")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("暂无置顶事件")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("在事件上长按，可选择置顶")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(height: geometry.size.height * 0.33)
                        .frame(maxWidth: .infinity)
                    }

                    Divider()

                    // 下部2/3空间：其他事件列表
                    List {
                        if eventStore.unpinnedEvents.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("暂无其他事件")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 200)
                            .listRowSeparator(.hidden)
                        } else {
                            ForEach(eventStore.unpinnedEvents) {
                                event in
                                UnpinnedEventRow(event: event)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if !isEditing {
                                            selectedEvent = event
                                        }
                                    }
                                    .contextMenu {
                                        Button(action: {
                                            eventStore.updateEvent(
                                                eventId: event.id,
                                                isPinned: true
                                            )
                                        }) {
                                            Label(
                                                "置顶",
                                                systemImage: "pin"
                                            )
                                        }

                                        Button(
                                            role: .destructive,
                                            action: {
                                                selectedEvent = event
                                            }
                                        ) {
                                            Label(
                                                "删除",
                                                systemImage: "trash"
                                            )
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            eventStore.updateEvent(
                                                eventId: event.id,
                                                isPinned: true
                                            )
                                        } label: {
                                            Label(
                                                "置顶",
                                                systemImage: "pin"
                                            )
                                        }
                                        .tint(.blue)
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            selectedEvent = event
                                        } label: {
                                            Label(
                                                "删除",
                                                systemImage: "trash"
                                            )
                                        }
                                    }
                            }
                            .onDelete(perform: deleteEvent)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("周期追踪")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                        .onTapGesture {
                            isEditing.toggle()
                        }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddEvent = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }

        .sheet(isPresented: $showingAddEvent) {
            AddEventView()
        }
        // 使用弹窗传入的事件构建全部操作，不再回退到置顶或列表首个事件
        .sheet(item: $selectedEvent, onDismiss: handleActionSheetDismiss) { event in
            EventActionSheetView(
                event: event,
                onRecord: {
                    eventStore.recordEvent(for: event.id)
                    selectedEvent = nil
                },
                onHistory: {
                    pendingAction = .history(event)
                    selectedEvent = nil
                },
                onReminder: {
                    pendingAction = .reminder(event)
                    selectedEvent = nil
                },
                onDelete: {
                    pendingAction = .delete(event)
                    selectedEvent = nil
                },
                onTogglePin: {
                    eventStore.updateEvent(
                        eventId: event.id,
                        isPinned: !event.isPinned
                    )
                    selectedEvent = nil
                }
            )
            .presentationDetents([.fraction(0.7), .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $showingHistoryForEvent) { event in
            EventHistoryView(event: event)
        }
        .sheet(item: $reminderEvent) { event in
            ReminderSettingsView(eventID: event.id)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // 关闭后再切换页面或删除已确认的事件，避免弹窗重叠及固定延时带来的不确定性
    private func handleActionSheetDismiss() {
        guard let action = pendingAction else { return }
        pendingAction = nil

        switch action {
        case .history(let event):
            showingHistoryForEvent = event
        case .reminder(let event):
            reminderEvent = event
        case .delete(let event):
            confirmDeleteEvent(event: event)
        }
    }

    private func deleteEvent(at offsets: IndexSet) {
        let unpinnedEvents = eventStore.unpinnedEvents
        var eventIdsToDelete: [UUID] = []

        for index in offsets {
            if index < unpinnedEvents.count {
                eventIdsToDelete.append(unpinnedEvents[index].id)
            }
        }

        eventStore.events.removeAll { event in
            eventIdsToDelete.contains(event.id)
        }

        eventStore.saveEvents()
    }

    private func confirmDeleteEvent(event: TrackedEvent) {
        eventStore.events.removeAll { $0.id == event.id }
        eventStore.saveEvents()
    }
}
