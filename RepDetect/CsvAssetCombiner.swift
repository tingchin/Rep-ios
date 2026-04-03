import Foundation

/// Merges bundled `pose/*.csv` into Documents, mirroring Android `combineCsvFiles`.
enum CsvAssetCombiner {
    static func combinedCsvURL() throws -> URL {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "CsvAssetCombiner", code: 0, userInfo: [NSLocalizedDescriptionKey: "No documents directory"])
        }
        return dir.appendingPathComponent("combined_poses.csv")
    }

    /// Maps plan exercise display names to bundle resource names (without `.csv`).
    static func bundleCsvResourceNames(for exercises: [String]) -> [String] {
        var files: [String] = []
        var seen = Set<String>()

        func add(_ name: String) {
            if seen.insert(name).inserted { files.append(name) }
        }

        if exercises.isEmpty {
            [
                "squats", "lunges", "neutral_standing", "pushups", "situps",
                "chestpress", "deadlift", "shoulderpress", "warrioryoga", "treeyoga"
            ].forEach(add)
            return files
        }

        for ex in exercises {
            switch ex.lowercased() {
            case let s where s == "squat":
                add("squats")
                add("neutral_standing")
            case let s where s == "push up":
                add("pushups")
            case let s where s == "sit up":
                add("situps")
            case let s where s == "lunge":
                add("lunges")
                add("neutral_standing")
            case let s where s == "chest press":
                add("chestpress")
            case let s where s == "dead lift":
                add("deadlift")
            case let s where s == "shoulder press":
                add("shoulderpress")
            case let s where s == "warrior yoga":
                add("warrioryoga")
            case let s where s == "tree yoga":
                add("treeyoga")
            case let s where s == "jump rope":
                break
            default:
                break
            }
        }
        return files
    }

    static func combineToDocuments(planExerciseNames: [String]) throws -> URL {
        let outURL = try combinedCsvURL()
        if FileManager.default.fileExists(atPath: outURL.path) {
            try FileManager.default.removeItem(at: outURL)
        }
        FileManager.default.createFile(atPath: outURL.path, contents: nil)

        let names = bundleCsvResourceNames(for: planExerciseNames)
        guard !names.isEmpty else {
            throw NSError(domain: "CsvAssetCombiner", code: 1, userInfo: [NSLocalizedDescriptionKey: "No CSV assets for plan"])
        }

        var data = Data()
        let nl = "\n".data(using: .utf8)!
        for base in names {
            guard let url = Bundle.main.url(forResource: base, withExtension: "csv", subdirectory: "pose") else {
                continue
            }
            var chunk = try Data(contentsOf: url)
            if !chunk.isEmpty, chunk.last != UInt8(ascii: "\n") {
                chunk.append(nl)
            }
            data.append(chunk)
            data.append(nl)
        }
        guard !data.isEmpty else {
            throw NSError(domain: "CsvAssetCombiner", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not read any CSV from bundle"])
        }
        try data.write(to: outURL, options: .atomic)
        return outURL
    }
}
