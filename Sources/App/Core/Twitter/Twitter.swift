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

import Fluent
import Vapor


enum Twitter {

    private static let apiUrl: String = "https://api.twitter.com/1.1/statuses/update.json"
    static let tweetMaxLength = 260  // exactly 280 is rejected, plus leave some room for unicode accounting oddities

    struct Credentials {
        var apiKey: (key: String, secret: String)
        var accessToken: (key: String, secret: String)
    }

    static func post(client: Client, tweet: String) async throws {
        guard let credentials = Current.twitterCredentials() else {
            throw Social.Error.missingCredentials
        }
        let url: URL = URL(string: "\(apiUrl)?status=\(tweet.urlEncodedString())")!
        let signature = OhhAuth.calculateSignature(
            url: url,
            method: "POST",
            parameter: [:],
            consumerCredentials: credentials.apiKey,
            userCredentials: credentials.accessToken
        )

        var headers: HTTPHeaders = .init()
        headers.add(name: "Authorization", value: signature)
        headers.add(name: "Content-Type", value: "application/x-www-form-urlencoded")
        let response = try await client.post(URI(string: url.absoluteString), headers: headers)
        guard response.status == .ok else {
            throw Social.Error.requestFailed(response.status, response.body?.asString() ?? "")
        }
    }

}


private extension String {
    func urlEncodedString() -> String {
        var allowedCharacterSet: CharacterSet = .urlQueryAllowed
        allowedCharacterSet.remove(charactersIn: "\n:#/?@!$&'()*+,;=")
        allowedCharacterSet.insert(charactersIn: "[]")
        return self.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) ?? ""
    }
}