import Foundation
import ComposableArchitecture
import SharedDomain

// MARK: - SetupSettings

public struct SetupSettings: Codable, Equatable, Sendable {
    public var wakeTimeHour: Int
    public var wakeTimeMinute: Int
    public var windowMinutes: Int
    public var sensitivity: AlarmSchedule.Sensitivity
    public var enabled: Bool

    public init(
        wakeTimeHour: Int,
        wakeTimeMinute: Int,
        windowMinutes: Int,
        sensitivity: AlarmSchedule.Sensitivity,
        enabled: Bool
    ) {
        self.wakeTimeHour = wakeTimeHour
        self.wakeTimeMinute = wakeTimeMinute
        self.windowMinutes = windowMinutes
        self.sensitivity = sensitivity
        self.enabled = enabled
    }
}

// MARK: - SetupStoreClient

@DependencyClient
public struct SetupStoreClient: Sendable {
    public var load: @Sendable () throws -> SetupSettings = {
        SetupSettings(
            wakeTimeHour: 7,
            wakeTimeMinute: 30,
            windowMinutes: 30,
            sensitivity: .balanced,
            enabled: true
        )
    }
    public var save: @Sendable (SetupSettings) throws -> Void = { _ in }
}

extension SetupStoreClient: DependencyKey {
    public static let liveValue = SetupStoreClient(
        load: {
            let url = try Self.preparedStoreURL()
            guard FileManager.default.fileExists(atPath: url.path) else {
                return SetupSettings(
                    wakeTimeHour: 7,
                    wakeTimeMinute: 30,
                    windowMinutes: 30,
                    sensitivity: .balanced,
                    enabled: true
                )
            }
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(SetupSettings.self, from: data)
        },
        save: { settings in
            let url = try Self.preparedStoreURL()
            let encoder = JSONEncoder()
            let data = try encoder.encode(settings)
            try data.write(to: url, options: .atomic)
        }
    )

    public static let testValue = SetupStoreClient()

    private static func preparedStoreURL() throws -> URL {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw SetupStoreError.directoryNotFound
        }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("setup_settings.json")
    }

    private enum SetupStoreError: LocalizedError {
        case directoryNotFound
        var errorDescription: String? { "Application Support 디렉토리를 찾을 수 없습니다." }
    }
}

extension DependencyValues {
    public var setupStoreClient: SetupStoreClient {
        get { self[SetupStoreClient.self] }
        set { self[SetupStoreClient.self] = newValue }
    }
}
