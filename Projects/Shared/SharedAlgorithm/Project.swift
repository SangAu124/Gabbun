import ProjectDescription

let project = Project(
    name: "SharedAlgorithm",
    targets: [
        .target(
            name: "SharedAlgorithm",
            destinations: [.iPhone, .appleWatch],
            product: .framework,
            bundleId: "com.gabbun.shared.algorithm",
            deploymentTargets: .multiplatform(iOS: "17.0", watchOS: "10.0"),
            infoPlist: .default,
            sources: ["Sources/**"],
            dependencies: [
                .project(
                    target: "SharedDomain",
                    path: .relativeToRoot("Projects/Shared/SharedDomain")
                )
            ]
        ),
        .target(
            name: "SharedAlgorithmTests",
            destinations: [.iPhone],
            product: .unitTests,
            bundleId: "com.gabbun.shared.algorithm.tests",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .default,
            sources: ["Tests/**"],
            dependencies: [
                .target(name: "SharedAlgorithm")
            ]
        )
    ]
)
