import SwiftUI
import Firebase
import FirebaseFirestore

// MARK: - نظام التوليد الذكي للإطلالات بناءً على المفضلات

struct FavoriteAnalysis {
    var colorFrequency: [String: Int] = [:]
    var categoryFrequency: [String: Int] = [:]
    var colorPairs: [String: Int] = [:] // مثل "أبيض-أسود": 5
    var usedItemIds: Set<String> = [] // لتجنب التكرار
    
    var topColors: [String] {
        colorFrequency.sorted { $0.value > $1.value }.map { $0.key }
    }
    
    var topCategories: [String] {
        categoryFrequency.sorted { $0.value > $1.value }.map { $0.key }
    }
}

class SmartOutfitGenerator {
    
    // MARK: - تصنيف القطع
    
    // القطع العلوية
    static let topCategories: Set<String> = ["قميص", "بلوزة", "كنزة", "معطف", "تيشيرت"]
    
    // القطع السفلية
    static let bottomCategories: Set<String> = ["بنطال", "تنورة", "شورت"]
    
    // القطع الكاملة
    static let fullBodyCategories: Set<String> = ["فستان", "شيال", "ثوب", "عباية"]
    
    // الأحذية
    static let shoesCategories: Set<String> = ["حذاء رياضي", "حذاء رسمي", "صندل", "كعب", "بوت", "حذاء"]
    
    // الإكسسوارات
    static let accessoriesCategories: Set<String> = ["سلسال", "اسورة", "حلق", "خاتم", "ساعة", "نظارة", "حقيبة", "حزام", "قبعة", "وشاح"]
    
    // دالة مساعدة للتحقق من نوع القطعة
    static func getCategoryType(_ category: String) -> String {
        if topCategories.contains(category) { return "top" }
        if bottomCategories.contains(category) { return "bottom" }
        if fullBodyCategories.contains(category) { return "fullBody" }
        if shoesCategories.contains(category) { return "shoes" }
        if accessoriesCategories.contains(category) { return "accessory" }
        return "unknown"
    }
    
    // MARK: - تحليل الإطلالات المفضلة
    static func analyzeFavoriteOutfits(_ favoriteOutfits: [Outfit]) -> FavoriteAnalysis {
        var analysis = FavoriteAnalysis()
        
        for outfit in favoriteOutfits {
            // تحليل كل قطعة في الإطلالة
            for item in outfit.items {
                // حفظ IDs القطع المستخدمة
                analysis.usedItemIds.insert(item.clothingItemId)
                
                // تحليل الفئات
                let category = item.category
                analysis.categoryFrequency[category, default: 0] += 1
            }
        }
        
        return analysis
    }
    
    // MARK: - تحليل متقدم مع معلومات القطع الكاملة
    static func analyzeWithClothingItems(
        favoriteOutfits: [Outfit],
        clothingItems: [ClothingItem]
    ) -> FavoriteAnalysis {
        var analysis = FavoriteAnalysis()
        
        // إنشاء خريطة للوصول السريع للقطع
        let itemsMap = Dictionary(uniqueKeysWithValues: clothingItems.map { ($0.id, $0) })
        
        for outfit in favoriteOutfits {
            var outfitColors: [String] = []
            
            for outfitItem in outfit.items {
                // حفظ IDs القطع المستخدمة
                analysis.usedItemIds.insert(outfitItem.clothingItemId)
                
                // الحصول على معلومات القطعة الكاملة
                guard let clothingItem = itemsMap[outfitItem.clothingItemId] else { continue }
                
                // تحليل الفئات
                analysis.categoryFrequency[clothingItem.category, default: 0] += 1
                
                // تحليل الألوان
                if let color = clothingItem.color?.trimmingCharacters(in: .whitespaces),
                   !color.isEmpty {
                    analysis.colorFrequency[color, default: 0] += 1
                    outfitColors.append(color)
                }
            }
            
            // تحليل أزواج الألوان (الألوان التي تظهر معاً)
            if outfitColors.count >= 2 {
                for i in 0..<outfitColors.count {
                    for j in (i+1)..<outfitColors.count {
                        let pair = [outfitColors[i], outfitColors[j]].sorted().joined(separator: "-")
                        analysis.colorPairs[pair, default: 0] += 1
                    }
                }
            }
        }
        
        return analysis
    }
    
    // MARK: - توليد تنسيق ذكي بناءً على التحليل (محدث)
    static func generateSmartOutfit(
        from clothingItems: [ClothingItem],
        analysis: FavoriteAnalysis,
        favoriteOutfits: [Outfit],
        minItems: Int = 2
    ) -> [ClothingItem]? {
        
        // يمكن استخدام جميع القطع (حتى المستخدمة في المفضلات)
        let availableItems = clothingItems
        
        guard availableItems.count >= minItems else { return nil }
        
        // تصنيف القطع حسب النوع
        let tops = availableItems.filter { topCategories.contains($0.category) }
        let bottoms = availableItems.filter { bottomCategories.contains($0.category) }
        let fullBody = availableItems.filter { fullBodyCategories.contains($0.category) }
        let shoes = availableItems.filter { shoesCategories.contains($0.category) }
        let accessories = availableItems.filter { accessoriesCategories.contains($0.category) }
        
        // محاولة إنشاء التنسيق عدة مرات
        for attempt in 0..<20 {
            var selectedItems: [ClothingItem] = []
            var usedCategories: Set<String> = []
            
            // استراتيجية 1 (المحاولات 1-7): قطعة علوية + قطعة سفلية
            if attempt < 7 && !tops.isEmpty && !bottoms.isEmpty {
                // اختيار قطعة علوية
                if let topItem = selectItemWithPreference(
                    from: tops,
                    analysis: analysis,
                    currentItems: selectedItems,
                    attempt: attempt
                ) {
                    selectedItems.append(topItem)
                    usedCategories.insert(topItem.category)
                }
                
                // اختيار قطعة سفلية متناسقة
                if let bottomItem = selectItemWithPreference(
                    from: bottoms,
                    analysis: analysis,
                    currentItems: selectedItems,
                    attempt: attempt
                ) {
                    selectedItems.append(bottomItem)
                    usedCategories.insert(bottomItem.category)
                }
                
                // إضافة حذاء إذا متوفر
                if !shoes.isEmpty,
                   let shoeItem = selectItemWithPreference(
                       from: shoes,
                       analysis: analysis,
                       currentItems: selectedItems,
                       attempt: attempt
                   ) {
                    selectedItems.append(shoeItem)
                    usedCategories.insert(shoeItem.category)
                }
                
                // إضافة إكسسوار إذا متوفر (اختياري)
                if !accessories.isEmpty && selectedItems.count >= 2,
                   let accessoryItem = selectItemWithPreference(
                       from: accessories,
                       analysis: analysis,
                       currentItems: selectedItems,
                       attempt: attempt
                   ) {
                    selectedItems.append(accessoryItem)
                    usedCategories.insert(accessoryItem.category)
                }
            }
            
            // استراتيجية 2 (المحاولات 8-14): قطعة كاملة + حذاء
            else if attempt < 14 && !fullBody.isEmpty {
                // اختيار قطعة كاملة
                if let fullBodyItem = selectItemWithPreference(
                    from: fullBody,
                    analysis: analysis,
                    currentItems: selectedItems,
                    attempt: attempt
                ) {
                    selectedItems.append(fullBodyItem)
                    usedCategories.insert(fullBodyItem.category)
                }
                
                // إضافة حذاء
                if !shoes.isEmpty,
                   let shoeItem = selectItemWithPreference(
                       from: shoes,
                       analysis: analysis,
                       currentItems: selectedItems,
                       attempt: attempt
                   ) {
                    selectedItems.append(shoeItem)
                    usedCategories.insert(shoeItem.category)
                }
                
                // إضافة إكسسوار (اختياري)
                if !accessories.isEmpty && selectedItems.count >= 2,
                   let accessoryItem = selectItemWithPreference(
                       from: accessories,
                       analysis: analysis,
                       currentItems: selectedItems,
                       attempt: attempt
                   ) {
                    selectedItems.append(accessoryItem)
                    usedCategories.insert(accessoryItem.category)
                }
            }
            
            // استراتيجية 3 (المحاولات 15-20): محاولة مع أي مزيج متاح
            else {
                // إذا كان هناك قطع علوية وسفلية
                if !tops.isEmpty && !bottoms.isEmpty {
                    if let top = tops.randomElement() {
                        selectedItems.append(top)
                        usedCategories.insert(top.category)
                    }
                    if let bottom = bottoms.randomElement() {
                        selectedItems.append(bottom)
                        usedCategories.insert(bottom.category)
                    }
                }
                // أو قطعة كاملة
                else if !fullBody.isEmpty {
                    if let full = fullBody.randomElement() {
                        selectedItems.append(full)
                        usedCategories.insert(full.category)
                    }
                }
                
                // إضافة حذاء
                if !shoes.isEmpty, let shoe = shoes.randomElement() {
                    selectedItems.append(shoe)
                    usedCategories.insert(shoe.category)
                }
            }
            
            // التحقق من صحة التنسيق
            if isValidOutfit(selectedItems) {
                // التحقق من عدم تكرار إطلالة كاملة
                if !isDuplicateOutfit(selectedItems, favoriteOutfits: favoriteOutfits) {
                    let colors = selectedItems.compactMap { $0.color }
                    if ColorMatchingRules.colorsMatchGroup(colors) {
                        return selectedItems
                    }
                }
            }
        }
        
        return nil
    }
    
    // MARK: - دالة مساعدة لاختيار قطعة بناءً على التفضيلات
    private static func selectItemWithPreference(
        from items: [ClothingItem],
        analysis: FavoriteAnalysis,
        currentItems: [ClothingItem],
        attempt: Int
    ) -> ClothingItem? {
        
        let currentColors = currentItems.compactMap { $0.color }
        
        // المحاولات الأولى: استخدام الفئات والألوان المفضلة
        if attempt < 10 {
            // فلترة القطع بالفئات المفضلة
            let preferredCategoryItems = items.filter { item in
                analysis.topCategories.prefix(5).contains(item.category)
            }
            
            // فلترة القطع بالألوان المفضلة
            let preferredColorItems = (preferredCategoryItems.isEmpty ? items : preferredCategoryItems).filter { item in
                guard let color = item.color else { return false }
                return analysis.topColors.prefix(5).contains(color)
            }
            
            // اختيار قطعة متناسقة مع الألوان الحالية
            let matchingItems = (preferredColorItems.isEmpty ? items : preferredColorItems).filter { item in
                guard let itemColor = item.color else { return true }
                return ColorMatchingRules.colorsMatchGroup(currentColors + [itemColor])
            }
            
            return matchingItems.randomElement() ?? items.randomElement()
        }
        
        // المحاولات المتأخرة: اختيار عشوائي مع مراعاة التناسق
        else {
            let matchingItems = items.filter { item in
                guard let itemColor = item.color else { return true }
                return ColorMatchingRules.colorsMatchGroup(currentColors + [itemColor])
            }
            
            return matchingItems.randomElement() ?? items.randomElement()
        }
    }
    
    // MARK: - التحقق من صحة التنسيق
    private static func isValidOutfit(_ items: [ClothingItem]) -> Bool {
        guard items.count >= 2 else { return false }
        
        var hasTop = false
        var hasBottom = false
        var hasFullBody = false
        
        for item in items {
            let type = getCategoryType(item.category)
            if type == "top" { hasTop = true }
            if type == "bottom" { hasBottom = true }
            if type == "fullBody" { hasFullBody = true }
        }
        
        // يجب أن يكون هناك إما:
        // 1. قطعة علوية + قطعة سفلية
        // 2. أو قطعة كاملة
        return (hasTop && hasBottom) || hasFullBody
    }
    
    // MARK: - التحقق من عدم تكرار إطلالة كاملة
    private static func isDuplicateOutfit(_ selectedItems: [ClothingItem], favoriteOutfits: [Outfit]) -> Bool {
        // استخراج IDs القطع المختارة
        let selectedItemIds = Set(selectedItems.map { $0.id })
        
        // التحقق من كل إطلالة مفضلة
        for outfit in favoriteOutfits {
            let outfitItemIds = Set(outfit.items.map { $0.clothingItemId })
            
            // إذا كانت القطع المختارة مطابقة تماماً لإطلالة مفضلة
            if selectedItemIds == outfitItemIds {
                return true // تكرار كامل ❌
            }
        }
        
        return false // تنسيق جديد ✅
    }
}
