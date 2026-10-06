import SwiftUI

struct NativeInput: View {
    let node: [String: Any]
    @ObservedObject var state: NativeState
    @State private var value = ""
    @State private var sent = ""
    @FocusState private var focused: Bool
    var body: some View {
        TextField(node["text"] as? String ?? "", text: $value, axis: .vertical)
            .lineLimit(2...4)
            .focused($focused)
            .accessibilityLabel(node["text"] as? String ?? "")
            .onAppear { value = node["value"] as? String ?? ""; sent = value }
            .onChange(of: value) { _, next in
                guard next != sent else { return }
                sent = next
                state.emit(["action": "input", "name": node["action"] as? String ?? "", "value": next])
            }
            .onChange(of: node["value"] as? String) { _, next in
                // The model acknowledges typing asynchronously; don't replay older text over an active edit.
                if !focused || next == sent { value = next ?? ""; sent = value }
            }
            .onChange(of: node["generation"] as? Int) { _, _ in
                value = node["value"] as? String ?? ""; sent = value
            }
            .onChange(of: state.packet["dismissKeyboard"] as? Bool) { _, dismiss in
                if dismiss == true { focused = false }
            }
    }
}

struct MockImage: View {
    let label: String
    var body: some View {
        ZStack {
            Color(uiColor: .secondarySystemBackground)
            VStack(spacing: 8) {
                Image(systemName: "cup.and.saucer.fill").font(.system(size: 44)).foregroundStyle(.brown)
                Text(label).font(.caption).foregroundStyle(.primary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
}
