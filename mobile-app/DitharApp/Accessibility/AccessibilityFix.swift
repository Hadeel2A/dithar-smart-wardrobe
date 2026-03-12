import SwiftUI

// حل عالمي لمنع الـ Dot Dot Dot
// وفرض أن VoiceOver يقرأ الـ Label المكتوب وليس محتوى الزر الداخلي
struct AccessibilityFix: ViewModifier {
    let label: String
    let hint: String?

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }
}

extension View {
    func vo(_ label: String, hint: String? = nil) -> some View {
        self.modifier(AccessibilityFix(label: label, hint: hint))
    }
}
