@testable import App

import Fluent
import SQLKit
import Vapor
import XCTest


class VersionReAnalyzerTests: AppTestCase {

    func test_reAnalyzeVersions() throws {
        // Basic end-to-end test
        // setup
        // - package dump does not include toolsVersion, targets to simulate an "old version"
        // - run analysis to create existing version
        // - validate that initial state is reflected
        // - then change input data in fields that are affecting existing versions (which `analysis` is "blind" to)
        // - run analysis again to confirm "blindness"
        // - run re-analysis and confirm changes are now reflected
        let pkg = try savePackage(on: app.db,
                                   "https://github.com/foo/1".url,
                                   processingStage: .ingestion)
        let repoId = UUID()
        try Repository(id: repoId,
                       package: pkg,
                       defaultBranch: "main",
                       releases: []).save(on: app.db).wait()
        var pkgDump = #"""
            {
              "name": "SPI-Server",
              "products": [],
              "targets": []
            }
            """#
        Current.shell.run = { cmd, path in
            if cmd.string == "git tag" { return "1.2.3" }
            if cmd.string.hasSuffix("swift package dump-package") {
                return pkgDump
            }
            if cmd.string.hasPrefix(#"git log -n1 --format=format:"%H-%ct""#) { return "sha-0" }
            if cmd.string == "git rev-list --count HEAD" { return "12" }
            if cmd.string == #"git log --max-parents=0 -n1 --format=format:"%ct""# { return "0" }
            if cmd.string == #"git log -n1 --format=format:"%ct""# { return "1" }
            return ""
        }
        do {
            // run initial analysis and assert initial state for versions
            try analyze(client: app.client,
                        database: app.db,
                        logger: app.logger,
                        threadPool: app.threadPool,
                        limit: 10).wait()
            let versions = try Version.query(on: app.db)
                .with(\.$targets)
                .all().wait()
            XCTAssertEqual(versions.map(\.toolsVersion), [nil, nil])
            XCTAssertEqual(versions.map { $0.targets.map(\.name) } , [[], []])
            XCTAssertEqual(versions.map(\.releaseNotes) , [nil, nil])
        }
        do {
            // Update state that would normally not be affecting existing versions, effectively simulating the situation where we only started parsing it after versions had already been created
            pkgDump = #"""
            {
              "name": "SPI-Server",
              "products": [],
              "targets": [{"name": "t1"}],
              "toolsVersion": {
                "_version": "5.3"
              }
            }
            """#
            // also, update release notes to ensure mergeReleaseInfo is being called
            let r = try XCTUnwrap(Repository.find(repoId, on: app.db).wait())
            r.releases = [
                .mock(descripton: "rel 1.2.3", tagName: "1.2.3")
            ]
            try r.save(on: app.db).wait()
        }
        do {  // assert running analysis again does not update existing versions
            try analyze(client: app.client,
                        database: app.db,
                        logger: app.logger,
                        threadPool: app.threadPool,
                        limit: 10).wait()
            let versions = try Version.query(on: app.db)
                .with(\.$targets)
                .all().wait()
            XCTAssertEqual(versions.map(\.toolsVersion), [nil, nil])
            XCTAssertEqual(versions.map { $0.targets.map(\.name) } , [[], []])
            XCTAssertEqual(versions.map(\.releaseNotes) , [nil, nil])
        }

        // MUT
        try reAnalyzeVersions(client: app.client,
                              database: app.db,
                              logger: app.logger,
                              threadPool: app.threadPool,
                              versionsLastUpdatedBefore: Date(),
                              limit: 10).wait()

        // validate that re-analysis has now updated existing versions
        let versions = try Version.query(on: app.db)
            .with(\.$targets)
            .all().wait()
        XCTAssertEqual(versions.map(\.toolsVersion), ["5.3", "5.3"])
        XCTAssertEqual(versions.map { $0.targets.map(\.name) } , [["t1"], ["t1"]])
        XCTAssertEqual(versions.compactMap(\.releaseNotes) , ["rel 1.2.3"])
    }

    func test_Package_fetchReAnalysisCandidates() throws {
        // Three packages with two versions:
        // 1) both versions updated before cutoff -> candidate
        // 2) one versino update before cutoff, one after -> candidate
        // 3) both version updated after cutoff -> no candidate
        let cutoff = Date(timeIntervalSince1970: 2)
        do {
            let p = Package(url: "1")
            try p.save(on: app.db).wait()
            try createVersion(app.db, p, updatedAt: 0)
            try createVersion(app.db, p, updatedAt: 1)
        }
        do {
            let p = Package(url: "2")
            try p.save(on: app.db).wait()
            try createVersion(app.db, p, updatedAt: 1)
            try createVersion(app.db, p, updatedAt: 3)
        }
        do {
            let p = Package(url: "3")
            try p.save(on: app.db).wait()
            try createVersion(app.db, p, updatedAt: 3)
            try createVersion(app.db, p, updatedAt: 4)
        }

        // MUT
        let res = try Package
            .fetchReAnalysisCandidates(app.db,
                                       versionsLastUpdatedBefore: cutoff,
                                       limit: 10).wait()

        // validate
        XCTAssertEqual(res.map(\.url), ["1", "2"])
    }

}


private func createVersion(_ db: Database,
                           _ package: Package,
                           updatedAt: Int) throws {
    let id = UUID()
    try Version(id: id, package: package).save(on: db).wait()
    let db = db as! SQLDatabase
    try db.raw("""
        update versions set updated_at = to_timestamp(\(bind: updatedAt))
        where id = \(bind: id)
        """)
        .run()
        .wait()
}
