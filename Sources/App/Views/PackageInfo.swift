// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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

struct PackageInfo {
    var title: String
    var description: String
    var url: String
}

extension PackageInfo {
    init?(package: Joined3<Package, Repository, Version>) {
        guard let repoName = package.repository?.name,
              let repoOwner = package.repository?.owner
        else { return nil }

        let title = package.version?.packageName ?? repoName

        self.init(title: title,
                  description: package.repository?.summary ?? "",
                  url: SiteURL.package(.value(repoOwner),
                                       .value(repoName),
                                       .none).relativeURL())
    }
}
