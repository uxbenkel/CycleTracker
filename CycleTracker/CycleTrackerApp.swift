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

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(eventStore)  // 注入环境对象
                .preferredColorScheme(.light)  // 可选：设置默认色彩模式
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
