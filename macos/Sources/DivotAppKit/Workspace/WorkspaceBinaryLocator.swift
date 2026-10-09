import Foundation

/// Locates a window manager's CLI executable.
///
/// GUI apps do not inherit a shell's `PATH`, so the Homebrew prefixes are always
/// considered. The existence check is injectable so the ordering is testable
/// without touching the real filesystem. Each manager exposes a thin named
/// wrapper (`AeroSpaceBinaryLocator`, `YabaiBinaryLocator`) so call sites and
/// tests keep a manager-specific name.
public enum WorkspaceBinaryLocator {
    public static func candidatePaths(executableName: String,
                                      environment: [String: String] = ProcessInfo.processInfo.environment,
                                      homeDirectory: String = NSHomeDirectory()) -> [String] {
        var candidates: [String] = []
        if let path = environment["PATH"] {
            for directory in path.split(separator: ":") where !directory.isEmpty {
                candidates.append("\(directory)/\(executableName)")
            }
        }
        candidates.append("/opt/homebrew/bin/\(executableName)")
        candidates.append("/usr/local/bin/\(executableName)")
        candidates.append("\(homeDirectory)/.local/bin/\(executableName)")

        var seen = Set<String>()
        return candidates.filter { seen.insert($0).inserted }
    }

    public static func locate(executableName: String,
                              fileExists: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) },
                              environment: [String: String] = ProcessInfo.processInfo.environment,
                              homeDirectory: String = NSHomeDirectory()) -> String? {
        candidatePaths(executableName: executableName,
                       environment: environment,
                       homeDirectory: homeDirectory).first(where: fileExists)
    }
}

/// Locates the `yabai` executable.
public enum YabaiBinaryLocator {
    public static let executableName = "yabai"

    public static func candidatePaths(environment: [String: String] = ProcessInfo.processInfo.environment,
                                      homeDirectory: String = NSHomeDirectory()) -> [String] {
        WorkspaceBinaryLocator.candidatePaths(executableName: executableName,
                                              environment: environment,
                                              homeDirectory: homeDirectory)
    }

    public static func locate(fileExists: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) },
                              environment: [String: String] = ProcessInfo.processInfo.environment,
                              homeDirectory: String = NSHomeDirectory()) -> String? {
        WorkspaceBinaryLocator.locate(executableName: executableName,
                                      fileExists: fileExists,
                                      environment: environment,
                                      homeDirectory: homeDirectory)
    }
}
