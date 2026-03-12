import SwiftUI
import AVFoundation
import UIKit

// MARK: - مدير إمكانية الوصول الشامل لتطبيق دِثار
/// هذا المدير يضمن عدم التداخل بين VoiceOver و AVSpeech
/// ويوفر واجهة موحدة لجميع ميزات إمكانية الوصول في التطبيق

final class AccessibilityManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = AccessibilityManager()
    
    // MARK: - Properties
    private let synthesizer = AVSpeechSynthesizer()
    
    /// حالة VoiceOver (يتم تحديثها تلقائياً)
    @Published private(set) var isVoiceOverRunning: Bool = UIAccessibility.isVoiceOverRunning
    
    /// حالة تفعيل AVSpeech من الإعدادات (للمكفوفين الجزئيين)
    @Published var isAVSpeechEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAVSpeechEnabled, forKey: "voiceDescriptionEnabled")
        }
    }
    
    // MARK: - Initialization
    private init() {
        // تحميل حالة AVSpeech من UserDefaults
        self.isAVSpeechEnabled = UserDefaults.standard.bool(forKey: "voiceDescriptionEnabled")
        
        // مراقبة تغييرات VoiceOver
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(voiceOverStatusChanged),
            name: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil
        )
        
        // إيقاف AVSpeech تلقائياً إذا تم تشغيل VoiceOver
        if UIAccessibility.isVoiceOverRunning && synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - VoiceOver Status Observer
    @objc private func voiceOverStatusChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
            
            // إيقاف AVSpeech فوراً إذا تم تشغيل VoiceOver
            if self.isVoiceOverRunning && self.synthesizer.isSpeaking {
                self.synthesizer.stopSpeaking(at: .immediate)
            }
        }
    }
    
    // MARK: - Main Speech Function
    /// الدالة الرئيسية للنطق - تختار تلقائياً بين VoiceOver و AVSpeech
    /// - Parameters:
    ///   - text: النص المراد نطقه
    ///   - interrupt: هل يتم مقاطعة النطق الحالي؟
    ///   - language: كود اللغة (افتراضي: ar-SA)
    func speak(_ text: String, interrupt: Bool = true, language: String = "ar-SA") {
        // ✅ الأولوية الأولى: VoiceOver
        // إذا كان VoiceOver مفعّل، نستخدمه حصرياً
        if UIAccessibility.isVoiceOverRunning {
            announceToVoiceOver(text)
            return
        }
        
        // ✅ الأولوية الثانية: AVSpeech
        // فقط إذا كان المستخدم فعّله من الإعدادات
        guard isAVSpeechEnabled else { return }
        
        speakWithAVSpeech(text, interrupt: interrupt, language: language)
    }
    
    // MARK: - VoiceOver Announcements
    /// إعلان نصي عبر VoiceOver
    private func announceToVoiceOver(_ text: String) {
        UIAccessibility.post(notification: .announcement, argument: text)
    }
    
    /// إعلان تغيير الصفحة عبر VoiceOver
    /// - Parameter message: رسالة الإعلان
    func announceScreenChange(_ message: String) {
        if UIAccessibility.isVoiceOverRunning {
            // إذا VoiceOver شغّال → نعلن تغيير شاشة
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                UIAccessibility.post(notification: .screenChanged, argument: message)
            }
        } else {
            // إذا VoiceOver مقفّل لكن الوصف الصوتي مفعّل → انطق النص بصوت
            speak(message, interrupt: true)
        }
    }

    /// إعلان تغيير في التخطيط (Layout)
    /// - Parameter message: رسالة الإعلان
    func announceLayoutChange(_ message: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        
        UIAccessibility.post(notification: .layoutChanged, argument: message)
    }
    
    /// تركيز VoiceOver على عنصر محدد
    /// - Parameter element: العنصر المراد التركيز عليه
    func focusOnElement(_ element: Any) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        
        UIAccessibility.post(notification: .screenChanged, argument: element)
    }
    
    // MARK: - AVSpeech Functions
    /// النطق باستخدام AVSpeech (للمكفوفين الجزئيين فقط)
    private func speakWithAVSpeech(_ text: String, interrupt: Bool, language: String) {
        // التأكد مرة أخرى أن VoiceOver غير مفعّل
        guard !UIAccessibility.isVoiceOverRunning else { return }
        
        if interrupt && synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = 0.47
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
    }
    
    /// إيقاف النطق الحالي
    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
    
    /// هل يتم النطق حالياً؟
    var isSpeaking: Bool {
        return synthesizer.isSpeaking
    }
    
    // MARK: - Utility Functions
    /// التحقق من إمكانية استخدام AVSpeech
    var canUseAVSpeech: Bool {
        return !UIAccessibility.isVoiceOverRunning && isAVSpeechEnabled
    }
    
    /// الحصول على وصف حالة إمكانية الوصول
    var accessibilityStatusDescription: String {
        if UIAccessibility.isVoiceOverRunning {
            return "VoiceOver مفعّل"
        } else if isAVSpeechEnabled {
            return "الوصف الصوتي مفعّل"
        } else {
            return "لا توجد ميزات إمكانية وصول مفعّلة"
        }
    }
}

// MARK: - SwiftUI Environment Key
struct AccessibilityManagerKey: EnvironmentKey {
    static let defaultValue = AccessibilityManager.shared
}

extension EnvironmentValues {
    var accessibilityManager: AccessibilityManager {
        get { self[AccessibilityManagerKey.self] }
        set { self[AccessibilityManagerKey.self] = newValue }
    }
}

// MARK: - View Extension للاستخدام السهل
extension View {
    /// إضافة دعم VoiceOver كامل لعنصر
    /// - Parameters:
    ///   - label: التسمية الوصفية
    ///   - hint: تلميح الاستخدام
    ///   - value: القيمة الحالية (اختياري)
    ///   - traits: السمات الإضافية
    func voiceOverAccessibility(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits)
    }
    
    /// تطبيق accessibility للأزرار بشكل سريع
    func buttonAccessibility(
        label: String,
        hint: String
    ) -> some View {
        self.voiceOverAccessibility(
            label: label,
            hint: hint,
            traits: .isButton
        )
    }
    
    /// إخفاء عنصر عن VoiceOver (للعناصر الزخرفية)
    func hideFromVoiceOver() -> some View {
        self.accessibilityHidden(true)
    }
}

// MARK: - Testing Helpers
#if DEBUG
extension AccessibilityManager {
    /// طباعة حالة إمكانية الوصول
    func printStatus() {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📊 حالة إمكانية الوصول:")
        print("   • VoiceOver: \(isVoiceOverRunning ? "✅ مفعّل" : "❌ غير مفعّل")")
        print("   • AVSpeech: \(isAVSpeechEnabled ? "✅ مفعّل" : "❌ غير مفعّل")")
        print("   • يمكن استخدام AVSpeech: \(canUseAVSpeech ? "✅ نعم" : "❌ لا")")
        print("   • حالة النطق: \(isSpeaking ? "🔊 ينطق" : "🔇 صامت")")
        print("   • الوصف: \(accessibilityStatusDescription)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
}
#endif
