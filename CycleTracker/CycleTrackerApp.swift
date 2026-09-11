//
//  CycleTrackerApp.swift
//  CycleTracker
//
//  Created by 何涛 on 2026-02-08.
//

import SwiftUI

@main
struct CycleTrackerApp: App {
    // 使用 StateObject 在应用级别创建并持有数据模型
    @StateObject private var eventStore = EventStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(eventStore)  // 注入环境对象
                // 不固定色彩模式，所有页面和弹窗随系统切换深浅色
                // 进入前台立即刷新后续通知排期，持续在前台时每小时刷新；不改变提醒频率和计时起点
                // 离开活跃状态后停止刷新，已安排的通知仍由系统发送
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    repeat {
                        await eventStore.refreshReminders()
                        do { try await Task.sleep(for: .seconds(3600)) }
                        catch { return }
                    } while !Task.isCancelled
                }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            EventListView()
                .tabItem {
                    Label("事件", systemImage: "list.bullet")
                }
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
        }
    }
}
