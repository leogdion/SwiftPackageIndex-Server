import Fluent
import Foundation


typealias PackageCollectionModel = JSONPackageCollectionModel.V1
typealias PackageCollection = PackageCollectionModel.Collection


extension PackageCollection {

    static func generate(db: Database,
                         packageURLs: [String],
                         authorName: String? = nil,
                         collectionName: String,
                         keywords: [String]? = nil,
                         overview: String? = nil,
                         revision: Int? = nil) -> EventLoopFuture<PackageCollection> {
        packageQuery(db: db)
            .filter(\.$url ~~ packageURLs)
            .all()
            .mapEachCompact { Package.init(package:$0, keywords: keywords) }
            .map {
                PackageCollection.init(
                    name: collectionName,
                    overview: overview,
                    keywords: keywords,
                    packages: $0,
                    formatVersion: .v1_0,
                    revision: revision,
                    generatedAt: Current.date(),
                    generatedBy: authorName.map(Author.init(name:)))
            }
    }

    static func generate(db: Database,
                         owner: String,
                         authorName: String? = nil,
                         collectionName: String,
                         keywords: [String]? = nil,
                         overview: String? = nil,
                         revision: Int? = nil) -> EventLoopFuture<PackageCollection> {
        packageQuery(db: db)
            .join(Repository.self, on: \App.Package.$id == \Repository.$package.$id)
            .filter(Repository.self, \.$owner == owner)
            .all()
            .mapEachCompact { Package.init(package:$0, keywords: keywords) }
            .map {
                PackageCollection.init(
                    name: collectionName,
                    overview: overview,
                    keywords: keywords,
                    packages: $0,
                    formatVersion: .v1_0,
                    revision: revision,
                    generatedAt: Current.date(),
                    generatedBy: authorName.map(Author.init(name:)))
            }
    }

}


extension PackageCollection {

    private static func packageQuery(db: Database) -> QueryBuilder<App.Package> {
        App.Package.query(on: db)
            .with(\.$repositories)
            .with(\.$versions) {
                $0.with(\.$builds)
                $0.with(\.$products)
                $0.with(\.$targets)
            }
    }

}


// MARK: - Initializers to transform SPI entities to Package Collection Model entities


extension PackageCollection.Package {
    init?(package: App.Package, keywords: [String]?) {
        let license = PackageCollectionModel.License(
            name: package.repository?.license.shortName,
            url: package.repository?.licenseUrl
        )

        guard let url = URL(string: package.url) else { return nil }

        self.init(
            url: url,
            summary: package.repository?.summary,
            keywords: keywords,
            versions: .init(versions: package.versions, license: license),
            readmeURL: package.repository?.readmeUrl.flatMap(URL.init(string:)),
            license: license
        )
    }
}


extension PackageCollection.Package.Version {
    init?(version: App.Version, license: PackageCollectionModel.License?) {
        guard
            let semVer = version.reference?.semVer,
            let packageName = version.packageName,
            let toolsVersion = version.toolsVersion
        else {
            return nil
        }
        self.init(
            version: "\(semVer)",
            packageName: packageName,
            targets: version.targets
                .map(PackageCollectionModel.Target.init(target:)),
            products: version.products
                .compactMap(PackageCollectionModel.Product.init(product:)),
            toolsVersion: toolsVersion,
            minimumPlatformVersions: version.supportedPlatforms
                .map(PackageCollectionModel.PlatformVersion.init(platform:)),
            verifiedCompatibility: .init(builds: version.builds),
            license: license
        )
    }
}


private extension Array where Element == PackageCollection.Package.Version {
    init(versions: [App.Version], license: PackageCollectionModel.License?) {
        self.init(
            versions.compactMap {
                Element.init(version: $0, license: license)
            }
            .sorted { $0.version > $1.version }
        )
    }
}


extension PackageCollectionModel.License {
    init?(name: String?, url: String?) {
        guard let url = url.flatMap(URL.init(string:)) else { return nil }
        self.init(name: name, url: url)
    }
}


extension PackageCollectionModel.PlatformVersion {
    init(platform: App.Platform) {
        self.init(name: platform.name.rawValue, version: platform.version)
    }
}


private extension PackageCollectionModel.Target {
    init(target: App.Target) {
        self.init(name: target.name, moduleName: nil)
    }
}


private extension PackageCollectionModel.Product {
    init?(product: App.Product) {
        guard let type = PackageCollectionModel
                .ProductType(productType: product.type)
        else { return nil }
        self.init(name: product.name,
                  type: type,
                  targets: product.targets)
    }
}


private extension PackageCollectionModel.ProductType {
    init?(productType: App.Product.`Type`) {
        switch productType {
            case .executable:
                self = .executable
            case .library:  // TODO: wire up detailed data
                self = .library(.automatic)
        }
    }
}


private extension Array where Element == PackageCollectionModel.Compatibility {
    // Helper struct to work around Compatibility not being Hashable
    struct Pair: Hashable {
        var platform: PackageCollectionModel.Platform
        var version: String
    }

    init(builds: [Build]) {
        self.init(
            // Gather up build via a Set to de-duplicate various
            // macOS build variants - spm, xcodebuild, ARM
            Set<Pair>(
                builds.map { Pair.init(platform: .init(platform: $0.platform),
                                       version: $0.swiftVersion.displayName) }
            )
            .map { Element.init(platform: $0.platform, swiftVersion: $0.version) }
            .sorted()
        )
    }
}


private extension PackageCollectionModel.Platform {
    init(platform: Build.Platform) {
        switch platform {
            case .ios, .tvos, .watchos, .linux:
                self.init(name: platform.rawValue)
            case .macosSpmArm, .macosXcodebuildArm, .macosSpm, .macosXcodebuild:
                self.init(name: "macos")
        }
    }
}


// MARK: - Hashable and Comparable conformances


extension PackageCollectionModel.Platform: Hashable {
    public var hashValue: Int { name.hashValue }
    public func hash(into hasher: inout Hasher) {
        name.hash(into: &hasher)
    }
}


extension PackageCollectionModel.Platform: Comparable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.name < rhs.name
    }
}


extension PackageCollectionModel.Compatibility: Comparable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.platform != rhs.platform { return lhs.platform < rhs.platform }
        return lhs.swiftVersion < rhs.swiftVersion
    }
}
