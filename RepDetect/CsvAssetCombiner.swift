import Foundation

/// Merges bundled `pose/*.csv` into Documents, mirroring Android `combineCsvFiles`.
enum CsvAssetCombiner {
    /// 兼容三种常见打包方式：① `Bundle/.../pose/name.csv`（文件夹引用）；② `Bundle/.../name.csv`（文件直接进资源）；③ `.../Resources/pose/name.csv` 物理路径。
    private static func bundledCsvURL(baseName: String) -> URL? {
        let base = baseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else { return nil }
        if let u = Bundle.main.url(forResource: base, withExtension: "csv", subdirectory: "pose") {
            return u
        }
        if let u = Bundle.main.url(forResource: base, withExtension: "csv") {
            return u
        }
        if let r = Bundle.main.resourceURL {
            let p = r.appendingPathComponent("pose/\(base).csv")
            if FileManager.default.fileExists(atPath: p.path) {
                return p
            }
        }
        return nil
    }

    static func combinedCsvURL() throws -> URL {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "CsvAssetCombiner", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法访问文档目录"])
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
            throw NSError(domain: "CsvAssetCombiner", code: 1, userInfo: [NSLocalizedDescriptionKey: "当前计划没有可用的训练数据文件"])
        }

        var missing: [String] = []
        for base in names {
            if bundledCsvURL(baseName: base) == nil {
                missing.append("\(base).csv")
            }
        }
        if !missing.isEmpty {
            let msg = """
            未在应用包内找到 CSV：\(missing.joined(separator: "、"))。
            请在 Xcode 将仓库内 `Resources/pose` 以「文件夹引用（蓝色文件夹）」拖入应用 Target，并勾选 Copy Bundle Resources；或把各 `.csv` 加入该 Target，使运行时能解析为 `pose/文件名.csv` 或 Bundle 根目录下的 `文件名.csv`。
            """
            throw NSError(domain: "CsvAssetCombiner", code: 3, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        var data = Data()
        let nl = "\n".data(using: .utf8)!
        for base in names {
            guard let url = bundledCsvURL(baseName: base) else {
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
            throw NSError(domain: "CsvAssetCombiner", code: 2, userInfo: [NSLocalizedDescriptionKey: "CSV 文件存在但合并后为空，请检查文件内容"])
        }
        try data.write(to: outURL, options: .atomic)
        return outURL
    }
}
