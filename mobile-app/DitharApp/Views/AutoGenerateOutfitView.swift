import SwiftUI
import Firebase
import FirebaseFirestore

struct AutoGenerateOutfitView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.accessibilityManager) private var accessibilityManager
    
    // MARK: - State Variables
    
    // Generation Mode Selection
    enum GenerationMode {
        case smart      // Based on favorites
        case manual     // Based on category selection
    }
    @State private var selectedMode: GenerationMode = .manual
    
    // Manual Selection State
    @State private var selectedMainCategories: Set<String> = []
    @State private var selectedSubcategories: Set<String> = []
    @State private var selectedColor: String? = nil
    
    // Smart Generation State
    @State private var favoriteOutfits: [Outfit] = []
    @State private var smartAnalysis: FavoriteAnalysis?
    
    // Available Options
    @State private var availableMainCategories: [String] = []
    @State private var availableSubcategories: [String: [String]] = [:]
    @State private var allAvailableSubcategories: [String] = []
    @State private var availableColors: [String] = []
    @State private var clothingItems: [ClothingItem] = []
    
    // UI State
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    @Binding var generatedItems: [OutfitItem]?
    
    // MARK: - Category Mappings
    
    private let darkGreen = Color(red: 0.35, green: 0.45, blue: 0.32)
    private let shadowColor = Color.black.opacity(0.12)
    
    private let mainCategoryMapping: [String: (icon: String?, imageName: String?)] = [
        "قطع علوية": (nil, "icons8-clothes-64"),
        "قطع سفلية": (nil, "icons8-trousers-64"),
        "قطع كاملة": (nil, "icons8-slip-dress-64"),
        "أحذية":     (nil, "icons8-trainers-64"),
        "إكسسوارات": (nil, "icons8-bag-64")
    ]
    
    private let subcategoryMapping: [String: [String]] = [
        "قطع علوية": ["قميص", "بلوزة", "كنزة", "معطف", "تيشيرت"],
        "قطع سفلية": ["بنطال", "تنورة", "شورت"],
        "قطع كاملة": ["فستان", "شيال", "ثوب", "عباية"],
        "أحذية": ["حذاء رياضي", "حذاء رسمي", "صندل", "كعب", "بوت"],
        "إكسسوارات": ["سلسال", "اسورة", "حلق", "خاتم", "ساعة", "نظارة", "حقيبة", "حزام", "قبعة", "وشاح"]
    ]
    
    let basicColors: [(String, Color)] = [
        ("أبيض", Color.white),
        ("أسود", Color.black.opacity(0.85)),          // أخف شوي من الأسود الصريح
        ("رمادي", Color.gray.opacity(0.55)),
        ("بني", Color.brown.opacity(0.55)),
        ("بيج", Color(red: 0.96, green: 0.96, blue: 0.86)),

        // ✅ نفس درجات صفحة الإحصائيات
        ("أخضر", SoftTheme.pastelGreen),
        ("أحمر", Color(red: 0.86, green: 0.28, blue: 0.30)),
        ("بنفسجي", SoftTheme.pastelPurple),
        ("برتقالي", SoftTheme.pastelOrange),

        // ✅ تخفيف ألوان النظام القوية
        ("أزرق", Color.blue.opacity(0.55)),
        ("أصفر", Color.yellow.opacity(0.55)),
        ("وردي", Color.pink.opacity(0.55)),
        ("سماوي", Color.cyan.opacity(0.55)),

        // ✅ ذهبي/فضي باستيل
        ("ذهبي", Color(red: 0.93, green: 0.84, blue: 0.45)),
        ("فضي", Color(red: 0.82, green: 0.82, blue: 0.85))
    ]
    
    private var displayedSubcategories: [String] {
        if selectedMainCategories.isEmpty {
            return allAvailableSubcategories
        } else {
            var subs: [String] = []
            for mainCat in selectedMainCategories {
                if let subcats = availableSubcategories[mainCat] {
                    subs.append(contentsOf: subcats)
                }
            }
            return subs
        }
    }
    
    // هل زر إنشاء التنسيق مفعل؟
    private var isGenerateEnabled: Bool {
        !isLoading &&
        !clothingItems.isEmpty &&
        (
            (selectedMode == .manual && selectedSubcategories.count >= 2) ||
            (selectedMode == .smart && !favoriteOutfits.isEmpty)
        )
    }
    
    enum AutoGenerateTab: String, CaseIterable {
        case manual = "من الفئات"
        case smart  = "من المفضلات"
    }

    @State private var selectedTab: AutoGenerateTab = .manual
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 25) {
                        header
                        
                        if clothingItems.isEmpty && !isLoading {
                            emptyStateView
                        } else {
                            modeSelectionButtons
                            
                            if selectedMode == .smart {
                                smartModeContent
                            } else {
                                manualModeContent
                            }
                            
                            generateButton
                                .padding(.top, 24)   // ← المسافة فوق الزر
                        }
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 24)                }
            }
            .navigationBarHidden(true)
            .onAppear {
                // إعلان الانتقال إلى هذه الشاشة لــ VoiceOver
                DitharVoiceAssistant.shared.announceScreenChange("شاشة التنسيق التلقائي لإنشاء إطلالة من خزانة الملابس")
                
                // وصف صوتي إضافي إذا المستخدم مفعّل الوصف الصوتي
                if accessibilityManager.canUseAVSpeech {
                    DitharVoiceAssistant.shared.speak(
                        "يمكنك اختيار التنسيق الذكي من المفضلات، أو اختيار الفئات والألوان يدويًا، ثم الضغط على زر إنشاء التنسيق.",
                        interrupt: true
                    )
                }
                
                loadClothingItems()
                loadFavoriteOutfits()
            }
            .alert("خطأ", isPresented: $showError) {
                Button("حسناً", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.gray)
                    .padding(10)
                    .clipShape(Circle())
            }
            .buttonAccessibility(
                label: "إغلاق شاشة التنسيق التلقائي",
                hint: "العودة إلى الشاشة السابقة"
            )
            
            Spacer()
            
            Text("تنسيق تلقائي")
                .font(.system(size: 22, weight: .bold))
                .accessibilityLabel("شاشة التنسيق التلقائي")
                .accessibilityAddTraits(.isHeader)
            
            Spacer()
            
            Color.clear
                .frame(width: 44)
                .hideFromVoiceOver()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tshirt")
                .font(.system(size: 60))
                .foregroundColor(.gray)
                .hideFromVoiceOver()
            
            Text("لا توجد قطع في الخزانة")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.gray)
            
            Text("أضف قطع ملابس لإنشاء تنسيقات")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .cornerRadius(15)
        .accessibilityElement(children: .ignore)
        .voiceOverAccessibility(
            label: "...",
            traits: .isStaticText
        )

    }
    
    // MARK: - Mode Selection Buttons
    
    private var modeSelectionButtons: some View {
        HStack(spacing: 0) {
            ForEach(AutoGenerateTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab

                    // ربط التبويب بالمنطق القديم
                    if tab == .smart {
                        selectedMode = .smart
                        analyzeSmartGeneration()
                    } else {
                        selectedMode = .manual
                    }
                }) {
                    VStack(spacing: 4) {
                        Text(tab.rawValue)
                            .font(.system(size: 16,
                                          weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(
                                selectedTab == tab
                                ? Color(red: 0.47, green: 0.58, blue: 0.44)
                                : .gray
                            )

                        if selectedTab == tab {
                            Capsule()
                                .fill(Color(red: 0.47, green: 0.58, blue: 0.44))
                                .frame(height: 3)
                                .transition(.opacity)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .environment(\.layoutDirection, .rightToLeft)
    }    // MARK: - Smart Mode Content
    
    private var smartModeContent: some View {
        VStack(alignment: .trailing, spacing: 16) {
            // Info Card
            VStack(alignment: .trailing, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundColor(Color(red: 0.47, green: 0.58, blue: 0.44))
                        .hideFromVoiceOver()
                    Text("التنسيق الذكي")
                        .font(.system(size: 18, weight: .bold))
                }
                
                if favoriteOutfits.isEmpty {
                    Text("لا توجد إطلالات مفضلة")
                        .font(.system(size: 14))
                        .foregroundColor(.red.opacity(0.8))
                    
                    Text("أضف إطلالات إلى المفضلة لاستخدام هذه الميزة")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                } else {
                    Text("سيتم إنشاء تنسيق مشابه لإطلالاتك المفضلة")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding()
            .background(favoriteOutfits.isEmpty ? Color.red.opacity(0.05) : Color.white)
            .cornerRadius(15)
        }
    }
    
    // MARK: - Manual Mode Content
    
    private var manualModeContent: some View {
        VStack(spacing: 16) {
            categorySelection
            colorSelection
        }
    }
    
    // MARK: - Category Selection
    
    private var categorySelection: some View {
        VStack(alignment: .trailing, spacing: 12) {

            Text("اختر فئتين على الأقل")
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 20)

            if availableMainCategories.isEmpty {
                Text("لا توجد فئات متوفرة")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            } else {

                // ✅ أيقونات الفئات (Full Width)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 18) {

                        // الكل
                        SmallCategoryIconButton(
                            icon: "square.grid.2x2",
                            imageName: nil,
                            label: "الكل",
                            isSelected: selectedMainCategories.isEmpty,
                            lightGreen: Color(red: 0.91, green: 0.93, blue: 0.88),
                            darkGreen: Color(red: 0.35, green: 0.45, blue: 0.32)
                        ) {
                            selectedMainCategories.removeAll()
                        }

                        ForEach(availableMainCategories, id: \.self) { category in
                            let mapped = mainCategoryMapping[category]

                            SmallCategoryIconButton(
                                icon: mapped?.icon,
                                imageName: mapped?.imageName,
                                label: category,
                                isSelected: selectedMainCategories.contains(category),
                                lightGreen: Color(red: 0.91, green: 0.93, blue: 0.88),
                                darkGreen: Color(red: 0.35, green: 0.45, blue: 0.32)
                            ) {
                                if selectedMainCategories.contains(category) {
                                    selectedMainCategories.remove(category)
                                } else {
                                    selectedMainCategories.insert(category)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 6)
                }
                .environment(\.layoutDirection, .rightToLeft)

                // ✅ Chips الفئات الفرعية (Full Width)
                if !displayedSubcategories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(displayedSubcategories, id: \.self) { sub in
                                SubCategoryChip(
                                    title: sub,
                                    isSelected: selectedSubcategories.contains(sub)
                                ) {
                                    if selectedSubcategories.contains(sub) {
                                        selectedSubcategories.remove(sub)
                                    } else {
                                        selectedSubcategories.insert(sub)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)   // ✅ مساحة للظل
                    }
                    .frame(height: 78)            // ✅ يوسع “الشريط” بحيث ما يبين أنه شريط
                    .scrollClipDisabledIfAvailable()
                    .environment(\.layoutDirection, .rightToLeft)
                    .padding(.top, 6)
                }
            }
        }
        .padding(.vertical, 8)      // بسيط بس عشان مسافة
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 0)    // خليها full width
    }
    // MARK: - Color Selection
    
    let baseSize: CGFloat = 48      // كان 54
    let selectedScale: CGFloat = 1.08  // تكبير بسيط جدًا عند الاختيار
    
    private var colorSelection: some View {
        VStack(alignment: .trailing, spacing: 12) {
            Text("اختر لون واحد (اختياري)")
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 20)

            if availableColors.isEmpty {
                Text("لا توجد ألوان متوفرة")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {

                        // ✅ كل الألوان (رينبو)
                        Button {
                            selectedColor = nil
                        } label: {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.red, .orange, .yellow, .green, .blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: baseSize, height: baseSize)
                                .shadow(color: shadowColor, radius: 10, x: 0, y: 6)
                                .scaleEffect(selectedColor == nil ? selectedScale : 1.0)
                                .animation(.spring(response: 0.22, dampingFraction: 0.75), value: selectedColor == nil)
                                .overlay(
                                    selectedColor == nil
                                    ? Image(systemName: "checkmark")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                    : nil
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("كل الألوان")
                        .accessibilityValue(selectedColor == nil ? "محدد" : "غير محدد")
                        .accessibilityHint("اضغط لإلغاء اختيار أي لون")

                        // ✅ الألوان المتاحة
                        ForEach(availableColors, id: \.self) { colorName in
                            if let colorValue = basicColors.first(where: { $0.0 == colorName })?.1 {
                                Button {
                                    selectedColor = (selectedColor == colorName ? nil : colorName)
                                } label: {
                                    Circle()
                                        .fill(colorValue)
                                        .frame(width: baseSize, height: baseSize)
                                        .shadow(color: shadowColor, radius: 10, x: 0, y: 6)
                                        .scaleEffect(selectedColor == colorName ? selectedScale : 1.0)
                                        .animation(.spring(response: 0.22, dampingFraction: 0.75), value: selectedColor == colorName)
                                        .overlay(
                                            selectedColor == colorName
                                            ? Image(systemName: "checkmark")
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundColor(
                                                    (colorValue == .white ||
                                                     colorValue == Color(red: 0.96, green: 0.96, blue: 0.86))
                                                    ? .black : .white
                                                )
                                            : nil
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("اللون \(colorName)")
                                .accessibilityValue(selectedColor == colorName ? "محدد" : "غير محدد")
                                .accessibilityHint("اضغط لاختيار هذا اللون")
                            }
                        }
                    }
                    // ✅ مهم: خليه يبدأ وينتهي عند حواف الصفحة مثل الأقسام الثانية
                    .padding(.horizontal, 20)
                    // ✅ مساحة للظل فوق/تحت عشان ما يبين قص
                    .padding(.vertical, 16)
                }
                .frame(height: 100) // ✅ يخلي الشادو ما ينقص ويبان كامل
                .scrollClipDisabledIfAvailable()
                .environment(\.layoutDirection, .rightToLeft)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    // MARK: - Generate Button
    
    private var generateButton: some View {
        Button(action: {
            generateOutfit()
        }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: isGenerateEnabled ? .white : .gray))
                        .accessibilityHidden(true)
                } else {
                    Text("إنشاء التنسيق")
                        .font(.system(size: 18, weight: .bold))
                }
            }
            .frame(width: UIScreen.main.bounds.width * 0.9)   // ✅ أقصر من عرض الصفحة
            .padding(.vertical, 16)
            .background(
                isGenerateEnabled
                ? Color(red: 0.47, green: 0.58, blue: 0.44)     // ✅ أخضر غامق (متاح)
                : Color(red: 0.91, green: 0.93, blue: 0.88)     // ✅ أخضر فاتح (غير متاح)
            )
            .foregroundColor(isGenerateEnabled ? .white : .gray) // ✅ قبل الاختيار رمادي
            .cornerRadius(15)                                   // ✅ كيرف أكثر
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
        }
        .disabled(!isGenerateEnabled)
        .buttonStyle(.plain)
        .buttonAccessibility(
            label: "إنشاء التنسيق",
            hint: "اضغط لإنشاء إطلالة جديدة من القطع المختارة"
        )
        .accessibilityValue(isGenerateEnabled ? "متاح" : "غير متاح")
        .padding(.top, 6)
    }
    // MARK: - Data Loading Functions
    
    private func loadClothingItems() {
        guard let userId = authManager.user?.uid else { return }
        
        isLoading = true
        let db = Firestore.firestore()
        db.collection("Clothes")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                isLoading = false
                
                if let _ = error {
                    errorMessage = "حدث خطأ في جلب القطع"
                    showError = true
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self.clothingItems = documents.compactMap { doc in
                    let data = doc.data()
                    
                    let name = (data["attrs"] as? [String: Any])?["description"] as? String ?? "بدون اسم"
                    let category = (data["analysis"] as? [String: Any])?["category"] as? String ?? "غير محدد"
                    let color = (data["analysis"] as? [String: Any])?["color"] as? String
                    let occasion = (data["attrs"] as? [String: Any])?["occasion"] as? String
                    let isFavorite = (data["meta"] as? [String: Any])?["isFavorite"] as? Bool ?? false
                    let isOutside = (data["meta"] as? [String: Any])?["isOutside"] as? Bool ?? false
                    let imageUrl = (data["image"] as? [String: Any])?["originalUrl"] as? String
                    let brand = (data["attrs"] as? [String: Any])?["brand"] as? String
                    let pattern = (data["analysis"] as? [String: Any])?["pattern"] as? String
                    
                    return ClothingItem(
                        id: doc.documentID,
                        name: name,
                        category: category,
                        color: color,
                        occasion: occasion,
                        brand: brand,
                        pattern: pattern,
                        isFavorite: isFavorite,
                        isOutside: isOutside,
                        localImageURLString: imageUrl
                    )
                }
                
                self.extractAvailableOptions()
            }
    }
    
    private func loadFavoriteOutfits() {
        guard let userId = authManager.user?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("outfits")
            .whereField("userId", isEqualTo: userId)
            .whereField("isFavorite", isEqualTo: true)
            .getDocuments { snapshot, error in
                if let _ = error {
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self.favoriteOutfits = documents.compactMap { doc -> Outfit? in
                    try? doc.data(as: Outfit.self)
                }
            }
    }
    
    private func extractAvailableOptions() {
        var mainCategories: Set<String> = []
        var subcategoriesDict: [String: Set<String>] = [:]
        var allSubs: Set<String> = []
        
        for item in clothingItems {
            let category = item.category
            
            for (mainCat, subcats) in subcategoryMapping {
                if subcats.contains(category) {
                    mainCategories.insert(mainCat)
                    subcategoriesDict[mainCat, default: []].insert(category)
                    allSubs.insert(category)
                    break
                }
            }
        }
        
        self.availableMainCategories = Array(mainCategories).sorted()
        self.availableSubcategories = subcategoriesDict.mapValues { Array($0).sorted() }
        self.allAvailableSubcategories = Array(allSubs).sorted()
        
        self.availableColors = Array(Set(clothingItems.compactMap { $0.color }))
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .sorted()
    }
    
    private func analyzeSmartGeneration() {
        smartAnalysis = SmartOutfitGenerator.analyzeWithClothingItems(
            favoriteOutfits: favoriteOutfits,
            clothingItems: clothingItems
        )
    }
    
    private func generateOutfit() {
        guard !clothingItems.isEmpty else {
            errorMessage = "لا توجد قطع في الخزانة"
            showError = true
            return
        }
        
        if selectedMode == .manual {
            guard selectedSubcategories.count >= 2 else {
                errorMessage = "يجب اختيار فئتين على الأقل لإنشاء التنسيق"
                showError = true
                return
            }
        } else {
            guard !favoriteOutfits.isEmpty else {
                errorMessage = "لا توجد إطلالات مفضلة. جرب الوضع اليدوي أو أضف إطلالات مفضلة أولاً"
                showError = true
                return
            }
        }
        
        isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            var selectedItems: [ClothingItem]?
            
            if selectedMode == .smart, let analysis = smartAnalysis {
                selectedItems = SmartOutfitGenerator.generateSmartOutfit(
                    from: clothingItems,
                    analysis: analysis,
                    favoriteOutfits: favoriteOutfits,
                    minItems: 2
                )
            } else {
                selectedItems = OutfitGenerator.generateOutfitWithCategories(
                    from: clothingItems,
                    categories: Array(selectedSubcategories),
                    preferredColor: selectedColor
                )
            }
            
            isLoading = false
            
            if let items = selectedItems, items.count >= 2 {
                let outfitItems = items.enumerated().map { index, item in
                    OutfitItem(
                        id: UUID().uuidString,
                        clothingItemId: item.id,
                        name: item.name,
                        category: item.category,
                        color: item.color,
                        localImageURLString: item.localImageURLString,
                        position: CGPoint(x: 175, y: 100 + CGFloat(index * 60)),
                        size: CGSize(width: 100, height: 100),
                        scale: 1.0
                    )
                }
                
                generatedItems = outfitItems
                
                // ممكن لاحقًا نضيف وصف للإطلالة هنا إذا حبيتي
                // DitharVoiceAssistant.shared.speakOutfit(
                //     name: "إطلالة جديدة",
                //     itemsCount: outfitItems.count,
                //     occasion: nil
                // )
                
                presentationMode.wrappedValue.dismiss()
            } else {
                if selectedMode == .smart {
                    errorMessage = "عذراً، لم نتمكن من إنشاء تنسيق مشابه لمفضلاتك. جرّب الوضع اليدوي."
                } else if selectedColor != nil {
                    errorMessage = "عذراً، لم نتمكن من إنشاء تنسيق باللون المختار. تأكد من وجود قطع كافية من كل فئة بنفس اللون."
                } else {
                    errorMessage = "عذراً، لم نتمكن من إنشاء تنسيق مناسب من الفئات المختارة. تأكد من وجود قطع كافية في كل فئة."
                }
                showError = true
            }
        }
    }
}

// MARK: - SubCategory Chip Component

struct SubCategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    private let mainGreen = Color(red: 0.47, green: 0.58, blue: 0.44)

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? mainGreen : Color.white)
                .foregroundColor(isSelected ? .white : .black)
                .cornerRadius(20)
                // ✅ ظل فقط (بدون حدود)
                .shadow(
                    color: isSelected
                        ? mainGreen.opacity(0.30)
                        : Color.black.opacity(0.10),
                    radius: isSelected ? 10 : 8,
                    x: 0,
                    y: isSelected ? 6 : 4
                )
        }
        .buttonStyle(.plain)
        .buttonAccessibility(
            label: "فئة \(title)",
            hint: "اضغط لتحديد أو إلغاء تحديد هذه الفئة"
        )
        .accessibilityValue(isSelected ? "محددة" : "غير محددة")
    }
}

extension View {
    @ViewBuilder
    func scrollClipDisabledIfAvailable() -> some View {
        if #available(iOS 17.0, *) {
            self.scrollClipDisabled()
        } else {
            self
        }
    }
}
