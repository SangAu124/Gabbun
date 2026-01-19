import ProjectDescription

let project = Project(
    name: "GabbunApp",
    targets: [
        .target(
            name: "GabbunApp",
            destinations: .iOS,
            product: .app,
            bundleId: "com.gabbun.app",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(
                with: [
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
