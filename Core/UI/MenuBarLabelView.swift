import SwiftUI

public struct MenuBarLabelView: View {
    @ObservedObject private var coordinator: KeyTokCoordinator

    public init(coordinator: KeyTokCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        Image(systemName: coordinator.menuBarSymbolName)
            .symbolRenderingMode(.hierarchical)
    }
}
