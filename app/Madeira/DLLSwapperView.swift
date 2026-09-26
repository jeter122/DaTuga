import SwiftUI

/// DLSS-Swapper-style screen: pick which build provides each graphics DLL.
/// Selections apply on the next launch.
struct DLLSwapperView: View {
    @ObservedObject private var store = DLLSwapperStore.shared

    var body: some View {
        List {
            Section {
                ForEach(DLLSwapperStore.slots) { slot in
                    NavigationLink {
                        DLLVersionPickerView(slot: slot)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(slot.displayName)
                                Text(slot.fileName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(store.selectedVersion(for: slot))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("Graphics DLLs")
            } footer: {
                Text("Choose which build provides each graphics DLL. "
                    + "The built-in set ships with the app; extra versions appear here "
                    + "when they are added to the app bundle. Applies on the next launch.")
            }
        }
        .navigationTitle("DLL Swapper")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DLLVersionPickerView: View {
    let slot: GraphicsDLLSlot
    @ObservedObject private var store = DLLSwapperStore.shared

    var body: some View {
        List {
            ForEach(store.versions(for: slot)) { version in
                Button {
                    store.select(version.name, for: slot)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(version.name)
                            if version.isBuiltIn {
                                Text("Ships with the app")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        if store.selectedVersion(for: slot) == version.name {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .foregroundColor(.primary)
            }
        }
        .navigationTitle(slot.fileName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
