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
    @State private var showingActionSheet = false
    @State private var selectedEvent: TrackedEvent? = nil
    @State private var isEditing = false

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
                                    showingActionSheet = true
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
                                        showingActionSheet = true
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
                                            showingActionSheet = true
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
                                                showingActionSheet =
                                                    true
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
                                            showingActionSheet = true
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
        .sheet(isPresented: $showingActionSheet) {
            // 强制使用一个事件
            if let event =
                selectedEvent ?? eventStore.pinnedEvent ?? eventStore
                .unpinnedEvents.first ?? eventStore.events.first
            {
                EventActionSheetView(
                    event: event,
                    onRecord: {
                        eventStore.recordEvent(for: event.id)
                        showingActionSheet = false
                    },
                    onHistory: {
                        showingHistoryForEvent = event
                        showingActionSheet = false
                    },
                    onDelete: {
                        showingActionSheet = false
                        // 延迟执行，确保弹窗先关闭
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            confirmDeleteEvent(event: event)
                        }
                    },
                    onTogglePin: {
                        eventStore.updateEvent(
                            eventId: event.id,
                            isPinned: !event.isPinned
                        )
                        showingActionSheet = false
                    }
                ).presentationDetents([.fraction(0.56)])
                    .presentationDragIndicator(.visible)
            } else {
                // 如果事件为空，显示空视图
                VStack(spacing: 20) {
                    Text("暂无事件")
                        .font(.headline)
                    Text("请先添加一个事件")
                        .foregroundColor(.secondary)
                    Button("添加事件") {
                        showingActionSheet = false
                        showingAddEvent = true
                    }
                    .padding()
                    Button("关闭") {
                        showingActionSheet = false
                    }
                }
            }
        }
        .sheet(item: $showingHistoryForEvent) { event in
            EventHistoryView(event: event)
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
