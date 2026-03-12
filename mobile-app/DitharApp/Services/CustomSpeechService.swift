import Foundation
import AVFoundation
import UIKit

// MARK: - خدمة النطق المخصصة
/// خدمة نطق متقدمة باستخدام AVSpeech
/// تعمل بالتنسيق مع AccessibilityManager لضمان عدم التداخل مع VoiceOver

final class CustomSpeechService {
    
    // MARK: - Properties
    private let accessibilityManager = AccessibilityManager.shared
    
    // MARK: - Initialization
    init() {
        // التهيئة الخاصة
    }
    
    // MARK: - Main Functions
    
    /// نطق نص معين
    /// - Parameters:
    ///   - text: النص المراد نطقه
    ///   - languageCode: كود اللغة (افتراضي: ar-SA)
    func speak(text: String, languageCode: String = "ar-SA") {
        accessibilityManager.speak(text, language: languageCode)
    }
    
    /// إيقاف النطق الحالي
    func stopSpeaking() {
        accessibilityManager.stopSpeaking()
    }
    
    /// هل يتم النطق حالياً؟
    var isSpeaking: Bool {
        return accessibilityManager.isSpeaking
    }
    
    // MARK: - Advanced Functions
    
    /// نطق نص بلغة محددة
    /// - Parameters:
    ///   - text: النص المراد نطقه
    ///   - language: اللغة (عربي أو إنجليزي)
    func speak(text: String, language: SpeechLanguage) {
        speak(text: text, languageCode: language.code)
    }
    
    /// نطق قائمة من النصوص بالتتابع
    /// - Parameter texts: قائمة النصوص
    func speakSequence(_ texts: [String]) {
        let combinedText = texts.joined(separator: "، ")
        speak(text: combinedText)
    }
    
    // MARK: - Status Check
    
    /// هل يمكن استخدام النطق؟
    var canSpeak: Bool {
        return accessibilityManager.canUseAVSpeech
    }
}

// MARK: - Speech Language Enum
extension CustomSpeechService {
    enum SpeechLanguage {
        case arabic
        case english
        
        var code: String {
            switch self {
            case .arabic:
                return "ar-SA"
            case .english:
                return "en-US"
            }
        }
    }
}

// MARK: - Usage Examples
/*
 
 // ✅ مثال 1: استخدام أساسي
 let speechService = CustomSpeechService()
 speechService.speak(text: "مرحباً بك")
 
 // ✅ مثال 2: نطق بالإنجليزية
 speechService.speak(text: "Welcome to Dithar", language: .english)
 
 // ✅ مثال 3: نطق قائمة
 speechService.speakSequence([
     "قطعة جديدة",
     "تم إضافتها بنجاح",
     "إلى خزانتك"
 ])
 
 // ✅ مثال 4: إيقاف النطق
 speechService.stopSpeaking()
 
 // ✅ مثال 5: التحقق من الحالة
 if speechService.canSpeak {
     speechService.speak(text: "النطق متاح")
 }
 
 */
