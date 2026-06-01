import Foundation
import OSLog

public enum ClackinatorLogger {
    private static var subsystem: String {
        Bundle.main.bundleIdentifier ?? "com.clackinator.runtime"
    }

    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let audio = Logger(subsystem: subsystem, category: "audio")
    public static let input = Logger(subsystem: subsystem, category: "input")
    public static let permissions = Logger(subsystem: subsystem, category: "permissions")
}
