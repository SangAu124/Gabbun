import ProjectDescription

let project = Project(
    name: "SharedDomain",
    targets: [
        .target(
            name: "SharedDomain",
            destinations: [.iPhone, .appleWatch],
            product: .framework,
            bundleId: "com.sangau.gabbun.shared.domain",
            deploymentTargets: .multiplatform(iOS: "17.0", watchOS: "10.0"),
            infoPlist: .default,
            sources: ["Sources/**"],
            dependencies: []
        ),
        .target(
            name: "SharedDomainTests",
            destinations: [.iPhone],
            product: .unitTests,
            bundleId: "com.sangau.gabbun.shared.domain.tests",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .default,
            sources: ["Tests/**"],
            dependencies: [
                .target(name: "SharedDomain")
            ]
        )
    ]
)
