// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import Plot

extension ReadyForSwift6Show {
    class View: PublicPage {
        let model: Model

        init(path: String, model: Model) {
            self.model = model
            super.init(path: path)
        }

        override func pageTitle() -> String? {
            return "Ready for Swift 6"
        }

        override func breadcrumbs() -> [Breadcrumb] {
            [
                Breadcrumb(title: "Home", url: SiteURL.home.relativeURL()),
                Breadcrumb(title: "Ready for Swift 6")
            ]
        }

        override func postHead() -> Node<HTML.HeadContext> {
            .script(
                .src("https://cdn.jsdelivr.net/npm/vega@5"),
                .data(named: "turbolinks-track", value: "reload")
            )
        }

        override func content() -> Node<HTML.BodyContext> {
            .group(
                .h2("Ready for Swift 6"),
                .p("Swift 6 is lorem ipsum dolor sit amet, consectetur adipiscing elit. Vestibulum ut ante vel diam sagittis hendrerit id eget nunc. Proin non ex eget dolor tristique lacinia placerat et turpis. In dui dui, malesuada eu lectus nec, rhoncus feugiat nisi."),
                .p("Get started by [reading the migration guide]or this [guide to Swift 6 on Swift.org]."),
                .p("To measure compatibility with Swift 6 across packages in the index, we are tracking compatibility across a set of packages under active development where they have at least one git commit in the past 12 months. The charts below visualise the results of our testing."),
                .h3("Total packages compatible with Swift 6"),
                .p("This chart shows the total number of packages that will compile with  Swift 6:"),
                .input(
                    .id("toggle-line"),
                    .type(.checkbox)
                ),
                .readyForSwift6Chart(chartIdentifier: "rfs6-packages"),
                .h3("Total Swift 6 concurrency errors"),
                .p("This chart shows the total number of Swift concurrency errors across the entire selection of testing packages:"),
                .readyForSwift6Chart(chartIdentifier: "rfs6-errors"),
                .h3("List of compatible packages"),
                .p("Here are all the compatible packages!")
            )
        }
    }
}

private extension Node where Context: HTML.BodyContext {
    static func readyForSwift6Chart(chartIdentifier: String) -> Self {
        let scriptPath = Current.fileManager.workingDirectory().appending("Resources/Charts/vega-charts.js")
        let chartPath = Current.fileManager.workingDirectory().appending("Resources/Charts/\(chartIdentifier).json")
        guard let scriptData = Current.fileManager.contents(atPath: scriptPath),
              let script = String(data: scriptData, encoding: .utf8)?.replacingOccurrences(of: "###", with: chartIdentifier), //.compactJavaScript(),
              let chartSpec = Current.fileManager.contents(atPath: chartPath)?.compactJson()
        else {
            return .p(
                .text("Failed to load "),
                .text(chartIdentifier),
                .text(".")
            )
        }

        return .group(
            .div(
                .class("vega-chart"),
                .id("vega-chart-\(chartIdentifier)")
            ),
            .script(
                .id("vega-spec-\(chartIdentifier)"),
                .attribute(named: "type", value: "application/json"),
                .raw(chartSpec)
            ),
            .script(
                .raw(script.compactJavaScript())
            )
        )
    }
}

private extension String {
    func compactJavaScript() -> String {
        self.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: ";")
    }
}

private extension Data {
    func compactJson() -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: self),
              let compactedJsonData = try? JSONSerialization.data(withJSONObject: json),
              let compactJson = String(data: compactedJsonData, encoding: .utf8)
        else { return nil }
        return compactJson
    }
}
