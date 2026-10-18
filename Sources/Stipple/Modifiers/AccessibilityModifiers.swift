/// What a view is, for screen readers (Ink's `aria-role`).
public enum AccessibilityRole: String, Hashable, Sendable, CaseIterable {
    /// A button.
    case button
    /// A checkbox.
    case checkbox
    /// A combo box.
    case combobox
    /// A list.
    case list
    /// A list box.
    case listbox
    /// An item of a list.
    case listitem
    /// A menu.
    case menu
    /// An item of a menu.
    case menuitem
    /// An option of a list box.
    case option
    /// A progress bar.
    case progressbar
    /// A radio button.
    case radio
    /// A group of radio buttons.
    case radiogroup
    /// A tab.
    case tab
    /// A list of tabs.
    case tablist
    /// A table.
    case table
    /// A text field.
    case textbox
    /// A timer.
    case timer
    /// A toolbar.
    case toolbar
}

/// States screen readers announce, such as "checked" (Ink's `aria-state`).
public struct AccessibilityState: OptionSet, Hashable, Sendable {
    /// The raw bit mask.
    public let rawValue: UInt16

    /// Creates states from a raw bit mask.
    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    /// Busy.
    public static let busy = Self(rawValue: 1 << 0)
    /// Checked.
    public static let checked = Self(rawValue: 1 << 1)
    /// Disabled.
    public static let disabled = Self(rawValue: 1 << 2)
    /// Expanded.
    public static let expanded = Self(rawValue: 1 << 3)
    /// Accepts multiple lines.
    public static let multiline = Self(rawValue: 1 << 4)
    /// Allows selecting several items.
    public static let multiselectable = Self(rawValue: 1 << 5)
    /// Read-only.
    public static let readonly = Self(rawValue: 1 << 6)
    /// Required.
    public static let required = Self(rawValue: 1 << 7)
    /// Selected.
    public static let selected = Self(rawValue: 1 << 8)

    /// The announced names, in Ink's order.
    var names: [String] {
        let all: [(Self, String)] = [
            (.busy, "busy"), (.checked, "checked"), (.disabled, "disabled"), (.expanded, "expanded"),
            (.multiline, "multiline"), (.multiselectable, "multiselectable"), (.readonly, "readonly"),
            (.required, "required"), (.selected, "selected"),
        ]
        return all.filter { contains($0.0) }.map(\.1)
    }
}

/// Accessibility information attached to a node.
struct AccessibilityInfo {
    var label: String?
    var isHidden = false
    var role: AccessibilityRole?
    var state: AccessibilityState = []
}

extension View {
    /// What a screen reader reads instead of the view's content (Ink's `aria-label`).
    public func accessibilityLabel(_ label: String) -> some View {
        behavior { $0.accessibility.label = label }
    }

    /// Hides the view from screen readers (Ink's `aria-hidden`).
    public func accessibilityHidden(_ hidden: Bool = true) -> some View {
        behavior { $0.accessibility.isHidden = hidden }
    }

    /// Announces the view with a role, e.g. `checkbox: Accept terms` (Ink's `aria-role`).
    public func accessibilityRole(_ role: AccessibilityRole) -> some View {
        behavior { $0.accessibility.role = role }
    }

    /// Announces states, e.g. `(checked) Accept terms` (Ink's `aria-state`).
    public func accessibilityState(_ state: AccessibilityState) -> some View {
        behavior { $0.accessibility.state = state }
    }
}
