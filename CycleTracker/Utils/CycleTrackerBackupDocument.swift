//
//  CycleTrackerBackupDocument.swift
//  CycleTracker
//
//  Created by 何涛 on 2026-02-08.
//

import SwiftUI
import UniformTypeIdentifiers

// 用于文件导出的文档模型
struct CycleTrackerBackupDocument: FileDocument {
    var data: Data

    static var readableContentTypes: [UTType] { [.cycleTrackerBackup] }
    static var writableContentTypes: [UTType] { [.cycleTrackerBackup] }

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let fileData = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = fileData
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
