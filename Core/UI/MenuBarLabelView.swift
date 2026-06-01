import SwiftUI

public struct MenuBarLabelView: View {
    @ObservedObject private var coordinator: ClackinatorCoordinator

    public init(coordinator: ClackinatorCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        Image(systemName: coordinator.menuBarSymbolName)
            .symbolRenderingMode(.hierarchical)
    }
}
