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

@testable import App
import Foundation


extension Release {
    static func mock(description: String?,
                     descriptionHTML: String? = nil,
                     isDraft: Bool = false,
                     publishedAt: Int? = nil,
                     tagName: String,
                     url: String = "") -> Self {
        .init(description: description,
              descriptionHTML: descriptionHTML,
              isDraft: isDraft,
              publishedAt: publishedAt
                .map(TimeInterval.init)
                .map(Date.init(timeIntervalSince1970:)),
              tagName: tagName,
              url: url)
    }
}
