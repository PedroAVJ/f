import SwiftUI

struct NativeNode: View {
    let node: [String: Any]
    @ObservedObject var state: NativeState
    private var text: String { node["text"] as? String ?? "" }
    private var children: [[String: Any]] { node["children"] as? [[String: Any]] ?? [] }
    private var spacing: CGFloat { CGFloat((node["spacing"] as? NSNumber)?.doubleValue ?? 12) }
    private var width: CGFloat? { (node["width"] as? NSNumber).map { CGFloat($0.doubleValue) } }
    private var height: CGFloat? { (node["height"] as? NSNumber).map { CGFloat($0.doubleValue) } }
    private var childViews: some View {
        ForEach(Array(children.enumerated()), id: \.offset) { _, child in NativeNode(node: child, state: state) }
    }
    var body: some View {
        content
            .padding(CGFloat((node["padding"] as? NSNumber)?.doubleValue ?? 0))
            .frame(width: width, height: height)
            .frame(maxWidth: node["expand"] as? Bool == true ? .infinity : nil,
                   maxHeight: node["flex"] as? Bool == true ? .infinity : nil)
            .modifier(NativeGlass(enabled: node["glass"] as? Bool == true))
            .accessibilityIdentifier(node["id"] as? String ?? "")
    }
    @ViewBuilder private var content: some View {
        switch node["type"] as? String {
        case "vstack": VStack(alignment: .leading, spacing: spacing) { childViews }
        case "hstack": HStack(alignment: .center, spacing: spacing) { childViews }
        case "overlay": ZStack(alignment: .bottomTrailing) { childViews }
        case "scroll": ScrollView { VStack(alignment: .leading, spacing: spacing) { childViews }.frame(maxWidth: .infinity, alignment: .leading) }
        case "spacer": Spacer(minLength: 0)
        case "divider": Divider()
        case "text":
            Text(text)
                .font(node["small"] as? Bool == true ? .caption : node["heading"] as? Bool == true ? .headline : .body)
                .foregroundStyle(node["secondary"] as? Bool == true ? .secondary : .primary)
                .fixedSize(horizontal: false, vertical: true)
        case "button": NativeButton(node: node) { state.click(node["action"] as? String ?? "") }
        case "input": NativeInput(node: node, state: state)
        case "image":
            Image(systemName: node["symbol"] as? String ?? "photo")
                .font(.system(size: CGFloat((node["size"] as? NSNumber)?.doubleValue ?? 24)))
                .accessibilityLabel(text)
        case "mockImage": MockImage(label: text)
        case "progress": ProgressView().accessibilityLabel(text)
        default: Text("Unsupported native node").foregroundStyle(.secondary)
        }
    }
}

struct NativeGlass: ViewModifier {
    let enabled: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ViewBuilder func body(content: Content) -> some View {
        if !enabled { content }
        else if reduceTransparency {
            content.background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24))
        } else if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
        } else {
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
    }
}

struct NativeButton: View {
    let node: [String: Any]
    let action: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private var button: some View {
        Button(action: action) {
            if let symbol = node["symbol"] as? String {
                Label(node["text"] as? String ?? "", systemImage: symbol)
                    .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
            } else {
                Text(node["text"] as? String ?? "").frame(minHeight: 36)
            }
        }
        .accessibilityLabel(node["text"] as? String ?? "")
        .disabled(node["disabled"] as? Bool == true)
    }
    @ViewBuilder var body: some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            if node["prominent"] as? Bool == true { button.buttonStyle(.glassProminent) }
            else { button.buttonStyle(.glass) }
        } else {
            if node["prominent"] as? Bool == true { button.buttonStyle(.borderedProminent) }
            else { button.buttonStyle(.bordered) }
        }
    }
}
