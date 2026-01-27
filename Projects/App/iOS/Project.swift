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
                    "UILaunchScreen": [:]
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
                    "WKCompanionAppBundleIdentifier": "com.sangau.gabbun.app"
                ]
            ),
            sources: ["../Watch/Sources/**"],
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
                )
            ]
        )
    ]
)
