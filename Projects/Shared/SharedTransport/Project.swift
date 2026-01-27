import ProjectDescription

let project = Project(
    name: "SharedTransport",
    targets: [
        .target(
            name: "SharedTransport",
            destinations: [.iPhone, .appleWatch],
            product: .framework,
            bundleId: "com.sangau.gabbun.shared.transport",
            deploymentTargets: .multiplatform(iOS: "17.0", watchOS: "10.0"),
            infoPlist: .default,
            sources: ["Sources/**"],
            dependencies: [
                .project(
                    target: "SharedDomain",
                    path: .relativeToRoot("Projects/Shared/SharedDomain")
                ),
                .external(name: "ComposableArchitecture")
            ]
        ),
        .target(
            name: "SharedTransportTests",
            destinations: [.iPhone],
            product: .unitTests,
            bundleId: "com.sangau.gabbun.shared.transport.tests",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .default,
            sources: ["Tests/**"],
            dependencies: [
                .target(name: "SharedTransport")
            ]
        )
    ]
)
