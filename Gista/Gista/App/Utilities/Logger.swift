//
//  Logger.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/2/25.
//

import Foundation

public enum Logger {
    public enum LogLevel {
        case debug
        case info
        case warning
        case error
        
        public var prefix: String {
            switch self {
            case .debug: return "🔍 DEBUG"
            case .info: return "ℹ️ INFO"
            case .warning: return "⚠️ WARNING"
            case .error: return "❌ ERROR"
            }
        }
    }
    
    public static func log(
        _ message: String,
        level: LogLevel = .debug,
        context: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        let filename = (file as NSString).lastPathComponent
        let contextInfo = context.map { " - \($0)" } ?? ""
        let logMessage = "\(level.prefix)\(contextInfo) [\(filename):\(line)] \(function): \(message)"
        print(logMessage)
        #endif
    }
    
    public static func error(
        _ error: Error,
        context: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            error.localizedDescription,
            level: .error,
            context: context,
            file: file,
            function: function,
            line: line
        )
    }
}
