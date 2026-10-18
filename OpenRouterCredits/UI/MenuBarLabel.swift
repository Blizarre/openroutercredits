import SwiftUI

struct MenuBarLabel: View {
    @Environment(CreditsStore.self) private var store

    var body: some View {
        Label(store.menuBarText, systemImage: "creditcard.fill")
            .labelStyle(.titleAndIcon)
            .monospacedDigit()
    }
}
