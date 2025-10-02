//
//  Logger.swift
//  LeafReader
//
//  Created by xiaoxiao on 2025/10/2.
//

import Foundation
import os.log

/// Simple logging utility for debugging
enum Logger {
    
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.leafreader"
    
    // MARK: - Log Categories
    
    static let ui = OSLog(subsystem: subsystem, category: "UI")
    static let storage = OSLog(subsystem: subsystem, category: "Storage")
    static let epub = OSLog(subsystem: subsystem, category: "EPUB")
    static let reader = OSLog(subsystem: subsystem, category: "Reader")
    static let general = OSLog(subsystem: subsystem, category: "General")
    
    // MARK: - Logging Methods
    
    static func debug(_ message: String, log: OSLog = general, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let filename = URL(fileURLWithPath: file).lastPathComponent
        os_log(.debug, log: log, "[%{public}@:%{public}d] %{public}@: %{public}@", filename, line, function, message)
        #endif
    }
    
    static func info(_ message: String, log: OSLog = general) {
        os_log(.info, log: log, "%{public}@", message)
    }
    
    static func warning(_ message: String, log: OSLog = general) {
        os_log(.default, log: log, "⚠️ %{public}@", message)
    }
    
    static func error(_ message: String, error: Error? = nil, log: OSLog = general) {
        if let error = error {
            os_log(.error, log: log, "❌ %{public}@: %{public}@", message, error.localizedDescription)
        } else {
            os_log(.error, log: log, "❌ %{public}@", message)
        }
    }
    
    // MARK: - Specialized Logging
    
    static func logEPUBImport(fileName: String, bookId: String) {
        info("📚 Importing EPUB: \(fileName) with ID: \(bookId)", log: epub)
    }
    
    static func logBookOpened(title: String) {
        info("📖 Opening book: \(title)", log: reader)
    }
    
    static func logProgressSaved(bookId: String, progress: Double) {
        debug("💾 Progress saved for book \(bookId): \(Int(progress * 100))%", log: storage)
    }
    
    static func logNavigationEvent(_ event: String) {
        debug("🧭 Navigation: \(event)", log: ui)
    }
}
