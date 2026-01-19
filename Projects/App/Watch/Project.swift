import ProjectDescription

let project = Project(
    name: "GabbunWatchApp",
    targets: [
        .target(
            name: "GabbunWatchApp",
            destinations: .watchOS,
            product: .app,
            bundleId: "com.gabbun.app.watchkitapp",
            deploymentTargets: .watchOS("10.0"),
            infoPlist: .extendingDefault(
                with: [
                    "CFBundleShortVersionString": "1.0",
                    "CFBundleVersion": "1",
                    "WKApplication": true,
                    "WKWatchOnly": true
                ]
            ),
            sources: ["Sources/**"],
            resources: [],
            dependencies: [
                .project(
                    target: "SharedDomain",
                    path: "../../Shared/SharedDomain"
                ),
                .project(
                    target: "SharedAlgorithm",
                    path: "../../Shared/SharedAlgorithm"
                ),
                .project(
                    target: "SharedTransport",
                    path: "../../Shared/SharedTransport"
                )
            ]
        )
    ]
)
