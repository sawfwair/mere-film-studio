import Foundation

/// Locates the Pi executable for embedding in film runs, falling back from
/// the user's PATH to mere.run-managed installations under
/// `~/Library/Application Support/MereRun/agents/pi`.
public enum PiExecutableResolver {
    public static func resolve(_ value: String = "pi") throws -> URL {
        if let executable = try? FilmToolClient.resolveExecutable(value) {
            return executable
        }
        guard value == "pi", let bundled = bundledCandidates().first else {
            throw FilmToolError.executableNotFound(value)
        }
        return bundled
    }

    static func bundledCandidates(
        in agentsRoot: URL = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/MereRun/agents/pi")
    ) -> [URL] {
        let versions = (try? FileManager.default.contentsOfDirectory(
            at: agentsRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return versions
            .sorted { isNewer($0.lastPathComponent, than: $1.lastPathComponent) }
            .map { $0.appending(path: "pi/pi") }
            .filter { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    /// Internal for tests.
    static func versionComponents(_ value: String) -> [Int] {
        value
            .trimmingPrefix("v")
            .split(separator: ".")
            .map { Int($0.prefix(while: { $0.isNumber })) ?? 0 }
    }

    /// Internal for tests.
    static func isNewer(_ lhs: String, than rhs: String) -> Bool {
        let lhsComponents = versionComponents(lhs)
        let rhsComponents = versionComponents(rhs)
        for (left, right) in zip(lhsComponents, rhsComponents) where left != right {
            return left > right
        }
        return lhsComponents.count > rhsComponents.count
    }
}
