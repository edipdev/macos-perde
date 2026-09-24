import Foundation

enum CommandMatcher {
    static func fuzzyScore(_ query: String, _ title: String) -> Int? {
        if query.isEmpty { return 0 }

        let queryChars = Array(query.lowercased())
        let titleChars = Array(title.lowercased())

        var score = 0
        var titleIndex = 0
        var lastMatchIndex: Int? = nil

        for queryChar in queryChars {
            var found: Int? = nil
            var searchIndex = titleIndex
            while searchIndex < titleChars.count {
                if titleChars[searchIndex] == queryChar {
                    found = searchIndex
                    break
                }
                searchIndex += 1
            }

            guard let matchIndex = found else { return nil }

            score += 5
            if matchIndex == 0 {
                score += 15
            } else if titleChars[matchIndex - 1] == " " {
                score += 10
            }
            if let last = lastMatchIndex, matchIndex == last + 1 {
                score += 10
            }

            lastMatchIndex = matchIndex
            titleIndex = matchIndex + 1
        }

        return score
    }
}
