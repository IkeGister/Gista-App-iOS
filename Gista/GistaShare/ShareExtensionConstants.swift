//
//  ShareExtensionConstants.swift
//  Gista
//
//  Created by Tony Nlemadim on 3/15/25.
//

import Foundation

// MARK: - Share Extension Constants
struct ShareExtensionConstants {
    static let appGroupId = "group.Voqa.io.Gista"
    static let shareQueueKey = "ShareQueue"
    static let sharedFilesDirectory = "SharedFiles"
}

// MARK: - Logger for Share Extension
struct Logger {
    static func log(_ message: String, level: LogLevel = .info) {
        print("[\(level.rawValue)] ShareExtension: \(message)")
    }
    
    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }
} 
