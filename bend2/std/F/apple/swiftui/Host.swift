import SwiftUI

@MainActor
final class NativeState: ObservableObject {
    @Published var packet: [String: Any] = [:]
    let emit: (NSDictionary) -> Void
    init(emit: @escaping (NSDictionary) -> Void) { self.emit = emit }
    func click(_ name: String) { emit(["action": "click", "name": name]) }
}

@objc(FSwiftUIHost)
@MainActor
final class FSwiftUIHost: NSObject {
    private static var state: NativeState?
    @objc(controllerWithAction:)
    static func controller(action: @escaping (NSDictionary) -> Void) -> UIViewController {
        let model = NativeState(emit: action)
        state = model
        return UIHostingController(rootView: NativeRoot(state: model))
    }
    @objc(apply:)
    static func apply(_ packet: NSDictionary) { state?.packet = packet as? [String: Any] ?? [:] }
}

struct NativeRoot: View {
    @ObservedObject var state: NativeState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        NavigationStack {
            NativeNode(node: state.packet["tree"] as? [String: Any] ?? [:], state: state)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .systemBackground))
                .navigationTitle(state.packet["title"] as? String ?? "Playground")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        ForEach(Array((state.packet["toolbar"] as? [[String: Any]] ?? []).enumerated()), id: \.offset) { _, node in
                            Button(node["text"] as? String ?? "", systemImage: node["symbol"] as? String ?? "circle") {
                                state.click(node["action"] as? String ?? "")
                            }.accessibilityIdentifier(node["id"] as? String ?? "")
                        }
                    }
                }
                .alert(state.packet["alertTitle"] as? String ?? "Review", isPresented: Binding(
                    get: { state.packet["alert"] as? Bool ?? false },
                    set: { _ in }
                )) {
                    Button("Cancel", role: .cancel) { state.click(state.packet["cancelAction"] as? String ?? "") }
                    Button(state.packet["confirmText"] as? String ?? "Confirm") { state.click(state.packet["confirmAction"] as? String ?? "") }
                } message: { Text(state.packet["alertMessage"] as? String ?? "") }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: state.packet["phase"] as? String)
        }
    }
}
