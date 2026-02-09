//
//  ContentView.swift
//  CycleTracker
//
//  Created by 何涛 on 2026-02-08.
//

import SwiftUI

struct ContentView: View {
    // 在应用级别创建并注入 EventStore
    @StateObject private var eventStore = EventStore()

    var body: some View {
        TabView {
            // 第一个 Tab：事件列表页
            EventListView()
                .tabItem {
                    Label("事件", systemImage: "list.bullet")
                }
                .tag(0)
                .environmentObject(eventStore)

            // 第二个 Tab：设置页
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
                .tag(1)
                .environmentObject(eventStore)
        }
        .accentColor(.blue)  // 设置 TabView 选中颜色
    }
}

// 预览提供程序
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
