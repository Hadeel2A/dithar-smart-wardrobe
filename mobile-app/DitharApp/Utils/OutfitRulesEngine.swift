import SwiftUI

// MARK: - نظام قواعد التنسيق والألوان (محدث)

// MARK: - قواعد تناسق الألوان
struct ColorMatchingRules {
    
    // الألوان المحايدة التي تناسب كل شيء
    static let neutralColors = ["أسود", "أبيض", "رمادي", "بيج", "بني"] // those color match everything, will not follow the bellow rules
    
    // قواعد تناسق الألوان
    static let colorMatching: [String: [String]] = [
        "أسود": ["أبيض", "رمادي", "أحمر", "ذهبي", "فضي", "بيج", "أزرق", "أخضر", "وردي"],
        "أبيض": ["أسود", "أزرق", "أحمر", "أخضر", "بني", "رمادي", "وردي", "اصفر"],
        "رمادي": ["أسود", "أبيض", "أزرق", "وردي", "اصفر", "بنفسجي"],
        "بيج": ["أبيض", "بني", "أزرق", "أخضر", "ذهبي"],
        "بني": ["أبيض", "بيج", "أخضر", "برتقالي"],
        "أزرق": ["أبيض", "رمادي", "بيج", "بني", "اصفر", "برتقالي"],
        "أحمر": ["أسود", "أبيض", "رمادي", "بيج", "ذهبي"],
        "أخضر": ["أبيض", "بيج", "بني", "أسود"],
        "اصفر": ["أبيض", "رمادي", "أزرق", "أسود"],
        "وردي": ["رمادي", "أبيض", "أسود", "بيج"],
        "بنفسجي": ["رمادي", "أبيض", "أسود"],
        "برتقالي": ["أزرق", "أبيض", "بني", "بيج"],
        "ذهبي": ["أسود", "أبيض", "بيج", "أحمر"],
        "فضي": ["أسود", "أبيض", "رمادي", "أزرق"],
        "سماوي": ["أبيض", "رمادي", "بيج", "بني"]
    ]
    
    // التحقق من تناسق لونين
    static func colorsMatch(_ color1: String?, _ color2: String?) -> Bool {
        guard let c1 = color1?.trimmingCharacters(in: .whitespaces).lowercased(),
              let c2 = color2?.trimmingCharacters(in: .whitespaces).lowercased() else {
            return true
        }
        
        if c1 == c2 { return true }
        
        if neutralColors.contains(where: { $0.lowercased() == c1 }) ||
           neutralColors.contains(where: { $0.lowercased() == c2 }) {
            return true
        }
        
        for (baseColor, matchingColors) in colorMatching {
            if baseColor.lowercased() == c1 {
                return matchingColors.contains(where: { $0.lowercased() == c2 })
            }
            if baseColor.lowercased() == c2 {
                return matchingColors.contains(where: { $0.lowercased() == c1 })
            }
        }
        
        return false
    }
    
    static func colorsMatchGroup(_ colors: [String?]) -> Bool {
        let validColors = colors.compactMap { $0 }
        guard validColors.count > 1 else { return true }
        
        for i in 0..<validColors.count {
            for j in (i+1)..<validColors.count {
                if !colorsMatch(validColors[i], validColors[j]) {
                    return false
                }
            }
        }
        return true
    }
}

// MARK: - محرك التنسيق التلقائي (محدث حسب المخطط)
class OutfitGenerator {
    
    /// توليد تنسيق بناءً على فئات محددة ولون واحد اختياري
    static func generateOutfitWithCategories(
        from clothingItems: [ClothingItem],
        categories: [String],
        preferredColor: String? = nil
    ) -> [ClothingItem]? {
        
        // التحقق من وجود قطع كافية
        guard clothingItems.count >= categories.count else {
            return nil
        }
        
        let availableItems = clothingItems
        
        // محاولة إنشاء التنسيق عدة مرات
        for _ in 0..<10 {
            var selectedItems: [ClothingItem] = []
            var tempAvailable = availableItems
            var usedCategories: Set<String> = []
            var selectedColorValue: String? = nil // اللون الفعلي للقطعة المختارة
            
            // إذا كان هناك لون محدد، ابحث عنه أولاً في جميع الفئات
            if let preferredColor = preferredColor {
                var foundColorItem = false
                
                for category in categories.shuffled() {
                    if foundColorItem { break }
                    
                    let categoryItems = tempAvailable.filter { $0.category == category }
                    let coloredItems = categoryItems.filter { item in
                        guard let itemColor = item.color else { return false }
                        return itemColor.trimmingCharacters(in: .whitespaces).lowercased() ==
                               preferredColor.trimmingCharacters(in: .whitespaces).lowercased()
                    }
                    
                    if let coloredItem = coloredItems.randomElement() {
                        selectedItems.append(coloredItem)
                        tempAvailable.removeAll { $0.id == coloredItem.id }
                        usedCategories.insert(category)
                        selectedColorValue = coloredItem.color
                        foundColorItem = true
                    }
                }
                
                // إذا لم نجد القطعة الملونة، فشل التنسيق
                if !foundColorItem {
                    continue
                }
            }
            
            // الآن اختر باقي القطع من الفئات المتبقية
            let remainingCategories = categories.filter { !usedCategories.contains($0) }
            
            for category in remainingCategories.shuffled() {
                let categoryItems = tempAvailable.filter { $0.category == category }
                
                guard !categoryItems.isEmpty else {
                    break
                }
                
                var foundMatch = false
                
                // إذا كان هناك لون أساسي (من القطعة الملونة)، اختر قطع متناسقة معه
                if let baseColor = selectedColorValue {
                    // فلترة القطع التي تتناسق مع اللون الأساسي
                    let matchingItems = categoryItems.filter { item in
                        guard let itemColor = item.color else { return true } // قطع بدون لون مقبولة
                        return ColorMatchingRules.colorsMatch(baseColor, itemColor)
                    }
                    
                    // إذا وجدنا قطع متناسقة، اختر منها
                    if !matchingItems.isEmpty {
                        if let matchedItem = matchingItems.randomElement() {
                            selectedItems.append(matchedItem)
                            tempAvailable.removeAll { $0.id == matchedItem.id }
                            usedCategories.insert(category)
                            foundMatch = true
                        }
                    } else {
                        // إذا لم نجد قطع متناسقة، اختر أي قطعة متاحة
                        if let anyItem = categoryItems.randomElement() {
                            selectedItems.append(anyItem)
                            tempAvailable.removeAll { $0.id == anyItem.id }
                            usedCategories.insert(category)
                            foundMatch = true
                        }
                    }
                } else {
                    // لا يوجد لون محدد، اختر قطعة عادية مع مراعاة التناسق
                    let currentColors = selectedItems.compactMap { $0.color }
                    
                    // حاول إيجاد قطعة تتناسق مع الألوان الموجودة
                    let matchingItems = categoryItems.filter { item in
                        guard let itemColor = item.color else { return true }
                        return ColorMatchingRules.colorsMatchGroup(currentColors + [itemColor])
                    }
                    
                    if !matchingItems.isEmpty {
                        if let matchedItem = matchingItems.randomElement() {
                            selectedItems.append(matchedItem)
                            tempAvailable.removeAll { $0.id == matchedItem.id }
                            usedCategories.insert(category)
                            foundMatch = true
                        }
                    } else {
                        // إذا لم نجد قطع متناسقة، اختر أي قطعة متاحة
                        if let anyItem = categoryItems.randomElement() {
                            selectedItems.append(anyItem)
                            tempAvailable.removeAll { $0.id == anyItem.id }
                            usedCategories.insert(category)
                            foundMatch = true
                        }
                    }
                }
                
                // إذا لم نجد قطعة مناسبة، توقف
                if !foundMatch {
                    break
                }
            }
            
            // التحقق من نجاح التنسيق
            if selectedItems.count == categories.count && usedCategories.count == categories.count {
                // إذا تم تحديد لون، تأكد من أن إحدى القطع على الأقل لها هذا اللون
                if let color = preferredColor {
                    let hasColorInOutfit = selectedItems.contains { item in
                        guard let itemColor = item.color else { return false }
                        return itemColor.trimmingCharacters(in: .whitespaces).lowercased() ==
                               color.trimmingCharacters(in: .whitespaces).lowercased()
                    }
                    if hasColorInOutfit {
                        return selectedItems
                    }
                } else {
                    return selectedItems
                }
            }
        }
        
        return nil
    }
}
