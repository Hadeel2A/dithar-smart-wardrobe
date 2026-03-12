import Foundation
import AVFoundation
import UIKit

// MARK: - مساعد دِثار الصوتي
/// نظام مساعد صوتي متكامل لتطبيق دِثار
/// يعمل بالتنسيق مع AccessibilityManager لضمان عدم التداخل مع VoiceOver

final class DitharVoiceAssistant {
    
    // MARK: - Singleton
    static let shared = DitharVoiceAssistant()
    
    // MARK: - Properties
    private let accessibilityManager = AccessibilityManager.shared
    
    // MARK: - Initialization
    private init() {
        // التهيئة الخاصة
    }
    
    // MARK: - Main Functions
    
    /// نطق نص معين
    /// - Parameters:
    ///   - text: النص المراد نطقه
    ///   - interrupt: هل يتم مقاطعة النطق الحالي؟ (افتراضي: true)
    ///   - language: كود اللغة (افتراضي: ar-SA)
    func speak(_ text: String, interrupt: Bool = true, language: String = "ar-SA") {
        accessibilityManager.speak(text, interrupt: interrupt, language: language)
    }
    
    /// إعلان تغيير الصفحة
    /// - Parameter message: رسالة الإعلان
    func announceScreenChange(_ message: String) {
        accessibilityManager.announceScreenChange(message)
    }
    
    /// إعلان تغيير في التخطيط
    /// - Parameter message: رسالة الإعلان
    func announceLayoutChange(_ message: String) {
        accessibilityManager.announceLayoutChange(message)
    }
    
    /// إيقاف النطق الحالي
    func stopSpeaking() {
        accessibilityManager.stopSpeaking()
    }
    
    /// هل يتم النطق حالياً؟
    var isSpeaking: Bool {
        return accessibilityManager.isSpeaking
    }
    
    // MARK: - Convenience Functions
    
    /// نطق رسالة ترحيب
    /// - Parameter userName: اسم المستخدم
    func speakWelcome(userName: String) {
        speak("مرحباً \(userName)، أهلاً بك في تطبيق دِثار")
    }
    
    /// نطق رسالة نجاح
    /// - Parameter message: رسالة النجاح
    func speakSuccess(_ message: String) {
        speak("تم بنجاح، \(message)")
    }
    
    /// نطق رسالة خطأ
    /// - Parameter message: رسالة الخطأ
    func speakError(_ message: String) {
        speak("حدث خطأ، \(message)")
    }
    
    /// نطق عدد العناصر
    /// - Parameters:
    ///   - count: عدد العناصر
    ///   - itemType: نوع العنصر (قطعة، إطلالة، إلخ)
    func speakItemCount(_ count: Int, itemType: String) {
        let text: String
        if count == 0 {
            text = "لا توجد \(itemType) حالياً"
        } else if count == 1 {
            text = "لديك \(itemType) واحدة"
        } else if count == 2 {
            text = "لديك \(itemType)تان"
        } else if count <= 10 {
            text = "لديك \(count) \(itemType)"
        } else {
            text = "لديك \(count) \(itemType)"
        }
        speak(text)
    }
    
    /// نطق تفاصيل قطعة ملابس
    /// - Parameters:
    ///   - name: اسم القطعة
    ///   - category: الفئة
    ///   - color: اللون (اختياري)
    ///   - brand: الماركة (اختياري)
    func speakClothingItem(name: String, category: String, color: String? = nil, brand: String? = nil) {
        var parts: [String] = [name, "من فئة \(category)"]
        
        if let color = color, !color.isEmpty {
            parts.append("باللون \(color)")
        }
        if let brand = brand, !brand.isEmpty {
            parts.append("من علامة \(brand)")
        }
        
        speak(parts.joined(separator: "، "))
    }
    
    /// نطق تفاصيل إطلالة
    /// - Parameters:
    ///   - name: اسم الإطلالة
    ///   - itemsCount: عدد القطع
    ///   - occasion: المناسبة (اختياري)
    func speakOutfit(name: String, itemsCount: Int, occasion: String? = nil) {
        var parts: [String] = ["إطلالة \(name)", "تحتوي على \(itemsCount) قطعة"]
        
        if let occasion = occasion, !occasion.isEmpty {
            parts.append("مناسبة لـ \(occasion)")
        }
        
        speak(parts.joined(separator: "، "))
    }
    
    // MARK: - Status Check
    
    /// التحقق من حالة إمكانية الوصول
    var accessibilityStatus: String {
        return accessibilityManager.accessibilityStatusDescription
    }
    
    /// هل VoiceOver مفعّل؟
    var isVoiceOverRunning: Bool {
        return accessibilityManager.isVoiceOverRunning
    }
    
    /// هل يمكن استخدام AVSpeech؟
    var canUseAVSpeech: Bool {
        return accessibilityManager.canUseAVSpeech
    }
}

// MARK: - Usage Examples
/*
 
 // ✅ مثال 1: نطق نص بسيط
 DitharVoiceAssistant.shared.speak("مرحباً بك في تطبيق دِثار")
 
 // ✅ مثال 2: إعلان تغيير الصفحة
 DitharVoiceAssistant.shared.announceScreenChange("صفحة الخزانة")
 
 // ✅ مثال 3: نطق رسالة نجاح
 DitharVoiceAssistant.shared.speakSuccess("تم إضافة القطعة إلى خزانتك")
 
 // ✅ مثال 4: نطق تفاصيل قطعة
 DitharVoiceAssistant.shared.speakClothingItem(
     name: "قميص أزرق",
     category: "قمصان",
     color: "أزرق",
     brand: "زارا"
 )
 
 // ✅ مثال 5: نطق عدد القطع
 DitharVoiceAssistant.shared.speakItemCount(5, itemType: "قطعة")
 
 // ✅ مثال 6: التحقق من الحالة
 if DitharVoiceAssistant.shared.isVoiceOverRunning {
     print("VoiceOver مفعّل")
 }
 
 */
