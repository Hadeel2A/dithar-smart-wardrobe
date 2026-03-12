import SwiftUI

// MARK: - مساعد الألوان

extension String {
    // تحويل اسم اللون العربي إلى Color
    func toColor() -> Color {
        let colorName = self.trimmingCharacters(in: .whitespaces).lowercased()
        
        switch colorName {
        case "أسود": return Color.black
        case "أبيض": return Color.white
        case "رمادي": return Color.gray
        case "بني": return Color.brown
        case "أحمر": return Color.red
        case "أزرق": return Color.blue
        case "أخضر": return Color.green
        case "اصفر", "أصفر": return Color.yellow
        case "برتقالي": return Color.orange
        case "بنفسجي": return Color.purple
        case "وردي": return Color.pink
        case "بيج": return Color(red: 0.96, green: 0.96, blue: 0.86)
        case "ذهبي": return Color(red: 1.0, green: 0.84, blue: 0.0)
        case "فضي": return Color(red: 0.75, green: 0.75, blue: 0.75)
        case "سماوي": return Color(red: 0.53, green: 0.81, blue: 0.92)
        default: return Color.gray
        }
    }
}

// MARK: - مكون دائرة اللون
struct ColorCircle: View {
    let colorName: String
    let isSelected: Bool
    let size: CGFloat
    
    init(colorName: String, isSelected: Bool = false, size: CGFloat = 40) {
        self.colorName = colorName
        self.isSelected = isSelected
        self.size = size
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(colorName.toColor())
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .overlay(
                    Circle()
                        .stroke(
                            isSelected
                            ? Color(red: 0.47, green: 0.58, blue: 0.44)
                            : Color.gray.opacity(0.3),
                            lineWidth: isSelected ? 3 : 1
                        )
                )
            
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2)
            }
        }
        // 🔊 إعدادات VoiceOver للّون (قراءة عند اللمس)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            colorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "لون غير محدد"
            : "اللون \(colorName)"
        )
        .accessibilityValue(isSelected ? "محدد" : "غير محدد")
        .accessibilityHint("اضغطي مرتين لاختيار اللون \(colorName)")
        // 🎙 نطق إضافي عند الضغط (دبل تاب مع VoiceOver)
        .onTapGesture {
            let trimmed = colorName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            DitharVoiceAssistant.shared.speak(
                "تم اختيار اللون \(trimmed)",
                interrupt: true
            )
        }
    }
}

