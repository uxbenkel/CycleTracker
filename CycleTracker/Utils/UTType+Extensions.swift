//
//  UTType+Extensions.swift
//  CycleTracker
//
//  Created by 何涛 on 2026-02-08.
//

import SwiftUI
import UniformTypeIdentifiers

// 扩展 UTType 定义应用专属类型
extension UTType {
    static var cycleTrackerBackup: UTType {
        UTType(exportedAs: "com.example.cycletracker.backup")
    }

    static var importedText: UTType {
        UTType.plainText
    }
}
