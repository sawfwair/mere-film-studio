import Foundation

public struct MereRunAgentStatus: Codable, Sendable, Equatable {
    public let models: [MereRunAgentModel]
    public let pi: MereRunAgentPi

    public var bestInstalledModel: MereRunAgentModel? {
        models
            .filter { $0.installed && $0.startableByMereRun }
            .max { $0.recommendedUnifiedMemoryGB < $1.recommendedUnifiedMemoryGB }
    }
}

public struct MereRunAgentModel: Codable, Sendable, Equatable {
    public let id: String
    public let displayName: String
    public let installed: Bool
    public let recommendedUnifiedMemoryGB: Int
    public let servingEngine: String
    public let startableByMereRun: Bool
}

public struct MereRunAgentPi: Codable, Sendable, Equatable {
    public let installed: Bool
    public let path: String?
    public let version: String?
}

public struct MereRunAgentClient: Sendable {
    public let executable: String

    public init(executable: String = "mere.run") {
        self.executable = executable
    }

    public func status() async throws -> MereRunAgentStatus {
        let result = try await FilmToolClient(executable: executable).run(["agent", "status", "--json"])
        do {
            return try JSONDecoder().decode(MereRunAgentStatus.self, from: Data(result.stdout.utf8))
        } catch {
            throw FilmToolError.invalidJSON("mere.run agent status: \(error.localizedDescription)")
        }
    }
}
