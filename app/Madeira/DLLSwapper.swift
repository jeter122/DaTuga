import Foundation

/// DLSS-Swapper-style graphics DLL management for Da Tuga (ml814).
///
/// Each graphics DLL the engine ships (d3d11.dll, dxgi.dll, ...) is a "slot".
/// A slot resolves to the built-in copy, or to a version dropped into the app
/// bundle under `GraphicsDLLs/<dll>/<version>/[<arch-subdir>/]<dll>`.
///
/// This follows the repo's settings contract: `UserDefaults` is the durable
/// copy (it survives a reinstall of the app bundle) and
/// `Documents/madeira-dlls.txt` is the contract with the engine, rewritten on
/// every change. The file is what the launch sequence reads, and the Files app
/// stays a valid escape hatch: one `dllname=version` per line, an absent line
/// (or absent file) means the built-in copy.
struct GraphicsDLLSlot: Identifiable, Hashable {
    /// File name, e.g. "d3d11.dll". Also the Identifiable id.
    let fileName: String
    /// Human label, e.g. "Direct3D 11".
    let displayName: String
    var id: String { fileName }
}

struct GraphicsDLLVersion: Identifiable, Hashable {
    let name: String
    let isBuiltIn: Bool
    var id: String { name }
}

final class DLLSwapperStore: ObservableObject {
    static let shared = DLLSwapperStore()

    static let slots: [GraphicsDLLSlot] = [
        GraphicsDLLSlot(fileName: "d3d11.dll", displayName: "Direct3D 11"),
        GraphicsDLLSlot(fileName: "dxgi.dll", displayName: "DXGI"),
        GraphicsDLLSlot(fileName: "d3d10core.dll", displayName: "Direct3D 10"),
        GraphicsDLLSlot(fileName: "d3d9.dll", displayName: "Direct3D 9"),
        GraphicsDLLSlot(fileName: "d3d12.dll", displayName: "Direct3D 12"),
        GraphicsDLLSlot(fileName: "winemetal.dll", displayName: "WineMetal"),
    ]

    static let builtInName = "Built-in"
    static let overrideFileName = "madeira-dlls.txt"

    private static let defaultsPrefix = "DaTuga.GraphicsDLL."

    /// fileName -> selected version name. Absent means built-in.
    @Published private(set) var selections: [String: String] = [:]

    private init() { reload() }

    static func defaultsKey(for slot: GraphicsDLLSlot) -> String {
        defaultsPrefix + slot.fileName
    }

    /// The built-in version plus every version folder found in the bundle.
    func versions(for slot: GraphicsDLLSlot) -> [GraphicsDLLVersion] {
        var out = [GraphicsDLLVersion(name: Self.builtInName, isBuiltIn: true)]
        let fm = FileManager.default
        if let dir = Bundle.main.resourceURL?
            .appendingPathComponent("GraphicsDLLs/" + slot.fileName, isDirectory: true),
            let entries = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]) {
            for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: entry.path, isDirectory: &isDir), isDir.boolValue {
                    out.append(GraphicsDLLVersion(name: entry.lastPathComponent, isBuiltIn: false))
                }
            }
        }
        return out
    }

    func selectedVersion(for slot: GraphicsDLLSlot) -> String {
        selections[slot.fileName] ?? Self.builtInName
    }

    func select(_ version: String, for slot: GraphicsDLLSlot) {
        let key = Self.defaultsKey(for: slot)
        if version == Self.builtInName {
            UserDefaults.standard.removeObject(forKey: key)
            selections[slot.fileName] = nil
        } else {
            UserDefaults.standard.set(version, forKey: key)
            selections[slot.fileName] = version
        }
        syncOverrideFile()
    }

    func reload() {
        var fresh: [String: String] = [:]
        for slot in Self.slots {
            if let v = UserDefaults.standard.string(forKey: Self.defaultsKey(for: slot)) {
                fresh[slot.fileName] = v
            }
        }
        selections = fresh
        syncOverrideFile()
    }

    /// Rewrite the engine contract file from the durable selections.
    /// Deleting (not writing a default) when everything is built-in matters:
    /// an absent file is the engine default, and a hand-written file must not
    /// be clobbered with our guesses.
    private func syncOverrideFile() {
        guard let dir = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first else { return }
        let url = dir.appendingPathComponent(Self.overrideFileName)
        if selections.isEmpty {
            try? FileManager.default.removeItem(at: url)
            return
        }
        let lines = Self.slots.compactMap { slot -> String? in
            guard let v = selections[slot.fileName] else { return nil }
            return "\(slot.fileName)=\(v)"
        }
        try? lines.joined(separator: "\n").appending("\n")
            .write(to: url, atomically: true, encoding: .utf8)
    }
}
