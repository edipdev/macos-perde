import Foundation

struct AudioProcessInfo: Equatable {
    let objectID: UInt32
    let pid: Int32
    let bundleID: String
    let isRunningOutput: Bool
}

struct AudioApp: Identifiable, Equatable {
    let bundleID: String
    let name: String
    let objectIDs: [UInt32]
    let isPlaying: Bool
    var id: String { bundleID }

    static func parentBundle(_ bundleID: String) -> String {
        if let range = bundleID.range(of: ".helper", options: [.caseInsensitive]) {
            return String(bundleID[..<range.lowerBound])
        }
        return bundleID
    }

    static func grouped(from processes: [AudioProcessInfo], name: (String) -> String) -> [AudioApp] {
        var byBundle: [String: [AudioProcessInfo]] = [:]
        for p in processes where !p.bundleID.isEmpty {
            byBundle[parentBundle(p.bundleID), default: []].append(p)
        }
        return byBundle.map { bundle, procs in
            AudioApp(
                bundleID: bundle,
                name: name(bundle),
                objectIDs: procs.map(\.objectID),
                isPlaying: procs.contains { $0.isRunningOutput }
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
