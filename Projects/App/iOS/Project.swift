import ProjectDescription

let project = Project(
    name: "GabbunApp",
    targets: [
        // MARK: - iOS App
        .target(
            name: "GabbunApp",
            destinations: .iOS,
            product: .app,
            bundleId: "com.sangau.gabbun.app",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(
                with: [
                    "CFBundleDisplayName": "가뿐",
                    "CFBundleShortVersionString": "1.0",
                    "CFBundleVersion": "1",
                    "UILaunchScreen": [:],
                    "NSHealthShareUsageDescription": "수면 중 심박수를 읽어 최적의 기상 시점을 분석합니다.",
                    "NSHealthUpdateUsageDescription": "수면 세션을 HealthKit에 기록합니다.",
                    "NSUserNotificationsUsageDescription": "기상 시각에 워치 알람이 울리지 않을 경우 백업 알림을 보냅니다."
                ]
            ),
            sources: ["Sources/**"],
            resources: [],
            dependencies: [
                .external(name: "ComposableArchitecture"),
                .project(
                    target: "SharedDomain",
                    path: .relativeToRoot("Projects/Shared/SharedDomain")
                ),
                .project(
                    target: "SharedAlgorithm",
                    path: .relativeToRoot("Projects/Shared/SharedAlgorithm")
                ),
                .project(
                    target: "SharedTransport",
                    path: .relativeToRoot("Projects/Shared/SharedTransport")
                ),
                .target(name: "GabbunWatchApp")
            ]
        ),
        // MARK: - watchOS App (embedded in iOS app)
        .target(
            name: "GabbunWatchApp",
            destinations: .watchOS,
            product: .app,
            bundleId: "com.sangau.gabbun.app.watchkitapp",
            deploymentTargets: .watchOS("10.0"),
            infoPlist: .extendingDefault(
                with: [
                    "CFBundleDisplayName": "가뿐",
                    "CFBundleShortVersionString": "1.0",
                    "CFBundleVersion": "1",
                    "WKApplication": true,
                    "WKCompanionAppBundleIdentifier": "com.sangau.gabbun.app",
                    "NSHealthShareUsageDescription": "수면 중 심박수를 모니터링하여 최적의 기상 시점을 감지합니다.",
                    "WKBackgroundModes": ["workout-processing"]
                ]
            ),
            sources: ["../Watch/Sources/**"],
            resources: [
                .glob(
                    pattern: "../Watch/Resources/**",
                    excluding: [
                        "../Watch/Resources/Info.plist",
                        "../Watch/Resources/GabbunWatchApp.entitlements"
                    ]
                )
            ],
            entitlements: .file(path: .relativeToManifest("../Watch/Resources/GabbunWatchApp.entitlements")),
            dependencies: [
                .external(name: "ComposableArchitecture"),
                .project(
                    target: "SharedDomain",
                    path: .relativeToRoot("Projects/Shared/SharedDomain")
                ),
                .project(
                    target: "SharedAlgorithm",
                    path: .relativeToRoot("Projects/Shared/SharedAlgorithm")
                ),
                .project(
                    target: "SharedTransport",
                    path: .relativeToRoot("Projects/Shared/SharedTransport")
                )
            ]
        )
    ]
)
