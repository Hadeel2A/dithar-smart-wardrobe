import SwiftUI
import Firebase
import FirebaseFirestore
import AVFoundation
import UIKit
import FirebaseAuth

// MARK: - نموذج بيانات القطعة
struct ClothingItem: Identifiable {
    let id: String
    let name: String
    let category: String
    let color: String?
    let occasion: String?
    let brand: String?
    let pattern: String?
    var isFavorite: Bool
    var isOutside: Bool
    var localImageURLString: String?
}

// MARK: - Helpers للنصوص العربية
private func normalizeArabic(_ s: String) -> String {
    var t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let tashkeel = CharacterSet(charactersIn: "\u{0617}\u{0618}\u{0619}\u{061A}\u{064B}\u{064C}\u{064D}\u{064E}\u{064F}\u{0650}\u{0651}\u{0652}\u{0653}\u{0654}\u{0655}")
    t.unicodeScalars.removeAll(where: { tashkeel.contains($0) })
    t = t.replacingOccurrences(of: "أ", with: "ا")
        .replacingOccurrences(of: "إ", with: "ا")
        .replacingOccurrences(of: "آ", with: "ا")
        .replacingOccurrences(of: "ى", with: "ي")
        .replacingOccurrences(of: "ة", with: "ه")
    t = t.replacingOccurrences(of: "[^\\p{L}\\p{Nd}]+", with: " ", options: .regularExpression)
    return t
}

private func tokens(from s: String) -> [String] {
    normalizeArabic(s)
        .split(whereSeparator: { $0.isWhitespace })
        .map { String($0) }
}

func arabicSpelledNumber(_ number: Int) -> String {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "ar")
    formatter.numberStyle = .spellOut
    return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
}

// MARK: - البحث
private func matchesSearch(_ item: ClothingItem, search: String) -> Bool {
    let qs = tokens(from: search)
    if qs.isEmpty { return true }

    let haystack = [
        item.name,
        item.category,
        item.color ?? "",
        item.occasion ?? "",
        item.brand ?? ""
    ]
    .map { normalizeArabic($0) }
    .joined(separator: " ")

    return qs.allSatisfy { haystack.contains($0) }
}

// MARK: - تحديث حالة المفضلة
func updateFavoriteStatus(itemId: String, isFavorite: Bool) {
    let db = Firestore.firestore()
    db.collection("Clothes").document(itemId).updateData([
        "meta.isFavorite": isFavorite
    ]) { error in
        if let error = error {
            print("❌ فشل تحديث المفضلة: \(error.localizedDescription)")
        } else {
            print("✅ تم تحديث المفضلة بنجاح")
        }
    }
}

// 🔹 حطي هذا برا أي struct
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 6
    var shakesPerUnit: CGFloat = 2
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(animatableData * .pi * shakesPerUnit),
                y: 0
            )
        )
    }
}

// MARK: - صفحة الخزانة الرئيسية (التصميم الثاني)
struct WardrobeView: View {
    @State private var userPhotoURL: String? = nil
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var notificationService = NotificationService()
    @State private var showNotifications = false
    @State private var previousClothingItems: [ClothingItem] = []
    @State private var isFirstLoad = true
    @State private var lastNotificationTimes: [String: Date] = [:]
    
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    @State private var userData: [String: Any]?
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedCategory = "الكل"
    @State private var showFavoritesOnly = false
    @State private var showAdvancedFilter = false
    @State private var selectedAdvancedCategory: String = "الكل"
    @State private var selectedAdvancedColor: String? = nil
    @State private var selectedAdvancedPattern: String? = nil

    @State private var showStatistics = false          // ✅ للإحصائيات (WardrobeStatisticsView)
    @State private var showTagIdentifier = false       // ✅ للتعرّف (StatisticsView)

    @State private var showAddItem = false
    @State private var clothingItems: [ClothingItem] = []
    @State private var selectedAdvancedSubcategory: String? = nil

    private var isAdvancedFilterActive: Bool {
        selectedAdvancedCategory != "الكل" || selectedAdvancedColor != nil || selectedAdvancedPattern != nil
    }

    private var displayFullName: String {
        (userData?["fullName"] as? String) ??
        (userData?["name"] as? String) ?? ""
    }

    private var displayUsername: String {
        (userData?["username"] as? String) ?? ""
    }

    // ربط الفئات الرئيسية بالفئات الفرعية
    let categoryMapping: [String: [String]] = [
        "قطع علوية": ["قميص", "بلوزة", "كنزة", "معطف", "تيشيرت"],
        "قطع سفلية": ["بنطال", "تنورة", "شورت"],
        "قطع كاملة": ["فستان", "شيال", "ثوب", "عباية"],
        "أحذية": ["حذاء رياضي", "حذاء رسمي", "صندل", "كعب", "بوت"],
        "إكسسوارات": ["سلسال", "اسورة", "حلق", "خاتم", "ساعة", "نظارة", "حقيبة", "حزام", "قبعة", "وشاح"]
    ]

    var filteredItems: [ClothingItem] {
        clothingItems.filter { item in
            let matchesFavorite = !showFavoritesOnly || item.isFavorite
            let matchesSearch = searchText.isEmpty || matchesSearch(item, search: searchText)
            guard matchesFavorite && matchesSearch else { return false }

            if let sub = selectedAdvancedSubcategory, !sub.isEmpty {
                let matchesColor   = (selectedAdvancedColor == nil)   || (item.color == selectedAdvancedColor)
                let matchesPattern = (selectedAdvancedPattern == nil) || (item.pattern == selectedAdvancedPattern)
                return (item.category == sub) && matchesColor && matchesPattern
            }

            let effectiveMainCategory: String = {
                if isAdvancedFilterActive {
                    return selectedAdvancedCategory
                } else {
                    return selectedCategory
                }
            }()

            var matchesMainCategory = true
            if effectiveMainCategory != "الكل",
               let subs = categoryMapping[effectiveMainCategory] {
                matchesMainCategory = subs.contains(item.category)
            }

            let matchesAdvancedColor   = selectedAdvancedColor == nil   || item.color == selectedAdvancedColor
            let matchesAdvancedPattern = selectedAdvancedPattern == nil || item.pattern == selectedAdvancedPattern

            return matchesMainCategory && matchesAdvancedColor && matchesAdvancedPattern
        }
    }
    struct CategoryIconButton: View {
        let normalImage: String?
        let shadowImage: String?
        let systemIcon: String?
        let label: String
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            Button {
                action()
            } label: {

                if let systemIcon = systemIcon {
                    // زر "الكل"
                    Image(systemName: systemIcon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 40, height: 40)
                        .shadow(
                            color: isSelected ? .black.opacity(0.25) : .clear,
                            radius: 6, x: 0, y: 4
                        )

                } else if let normalImage = normalImage,
                          let shadowImage = shadowImage {

                    Image(isSelected ? shadowImage : normalImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30) // 👈 مقاس الأيقونة فقط
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }



    // الألوان
    private let lightGreenBackground = Color(red: 0.91, green: 0.93, blue: 0.88)
    private let mainGreenColor = Color(red: 0.47, green: 0.58, blue: 0.44)
    private let lightGreenButton = Color(red: 0.91, green: 0.93, blue: 0.88)
    private let darkGreenIcon = Color(red: 0.35, green: 0.45, blue: 0.32)

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: - الخلفية الخضراء العلوية مع المحتوى
                    ZStack(alignment: .top) {
                        VStack {
                            lightGreenBackground
                                .frame(height: 160)
                            Spacer()
                        }
                        .ignoresSafeArea()

                        VStack(spacing: 0) {
                            // MARK: - الشريط العلوي
                            HStack(spacing: 12) {
                                Spacer()

                                Button(action: {
                                    showNotifications = true
                                    DitharVoiceAssistant.shared.speak("الإشعارات")
                                }) {
                                    ZStack(alignment: .topTrailing) {
                                        Image(systemName: "bell")
                                            .font(.system(size: 22))
                                            .foregroundColor(darkGreenIcon)
                                            .frame(width: 40, height: 40)
                                            .background(Color.white)
                                            .cornerRadius(20)
                                            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)

                                        if notificationService.unreadCount > 0 {
                                            Circle()
                                                .fill(Color.red)
                                                .frame(width: 16, height: 16)
                                                .overlay(
                                                    Text("\(notificationService.unreadCount)")
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundColor(.white)
                                                )
                                                .offset(x: 4, y: -4)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("الإشعارات")
                                .accessibilityAddTraits(.isButton)

                                NavigationLink {
                                    SettingsView()
                                } label: {
                                    Image(systemName: "gearshape")
                                        .font(.system(size: 22))
                                        .foregroundColor(darkGreenIcon)
                                        .frame(width: 40, height: 40)
                                        .background(Color.white)
                                        .cornerRadius(20)
                                        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                                }
                                .buttonStyle(.plain)
                                .simultaneousGesture(TapGesture().onEnded {
                                    DitharVoiceAssistant.shared.speak("الإعدادات")
                                })
                                .accessibilityLabel("الإعدادات")
                                .accessibilityAddTraits(.isButton)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 10)

                            // MARK: - المربع الأبيض مع معلومات المستخدم
                            ZStack(alignment: .topLeading) {
                                VStack(spacing: 16) {
                                    Spacer().frame(height: 35)

                                    let totalCount = clothingItems.count
                                    let outsideCount = clothingItems.filter { $0.isOutside }.count
                                    let insideCount = totalCount - outsideCount

                                    HStack(spacing: 20) {
                                        VStack(spacing: 4) {
                                            Text("\(insideCount)")
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundColor(.black)
                                            Text("داخل الخزانة")
                                                .font(.system(size: 11))
                                                .foregroundColor(darkGreenIcon)
                                        }

                                        VStack(spacing: 4) {
                                            Text("\(outsideCount)")
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundColor(.black)
                                            Text("خارج الخزانة")
                                                .font(.system(size: 11))
                                                .foregroundColor(darkGreenIcon)
                                        }

                                        Spacer()

                                        // ✅ زر الإحصائيات (يودّي لصفحة الإحصائيات مثل الكود الأول)
                                        Button(action: {
                                            showStatistics = true
                                            DitharVoiceAssistant.shared.speak("الإحصائيات")
                                        }) {
                                            Image(showStatistics ? "icons8-statistics-64-shadow" : "icons8-statistics-64")
                                                .renderingMode(.original)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 40, height: 40)
                                                .frame(width: 56, height: 56)
                                                .background(Color.white)
                                                .cornerRadius(14)
                                                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                                        }
                                        .accessibilityLabel("الإحصائيات")
                                        .accessibilityAddTraits(.isButton)


                                        // زر التعرف على التاق
                                        Button(action: {
                                            showTagIdentifier = true
                                            DitharVoiceAssistant.shared.speak("التعرف على القطعة")
                                        }) {
                                            Image(showTagIdentifier ? "icons8-update-tag-64-shadow" : "icons8-update-tag-64")
                                                .renderingMode(.original)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 40, height: 40)
                                                .frame(width: 56, height: 56)
                                                .background(Color.white)
                                                .cornerRadius(14)
                                                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                                        }
                                        .accessibilityLabel("التعرف على القطعة")
                                        .accessibilityAddTraits(.isButton)


                                    }
                                    .padding(.horizontal, 16)
                                }
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity)
                                .background(Color.white)
                                .cornerRadius(20)
                                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 5)
                                .padding(.horizontal, 20)
                                .padding(.top, 30)

                                HStack(spacing: 12) {
                                    NavigationLink {
                                        ProfileView()
                                    } label: {
                                        AvatarView(
                                            displayName: displayFullName.isEmpty
                                                ? (displayUsername.isEmpty ? " " : displayUsername)
                                                : displayFullName,
                                            urlString: userPhotoURL,
                                            size: 60
                                        )
                                        .overlay(
                                            Circle().stroke(Color.white, lineWidth: 3)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .simultaneousGesture(TapGesture().onEnded {
                                        let nameText = !displayFullName.isEmpty ? displayFullName :
                                        (!displayUsername.isEmpty ? displayUsername : "الملف الشخصي")
                                        DitharVoiceAssistant.shared.speak("الملف الشخصي: \(nameText)")
                                    })
                                    .accessibilityLabel("الملف الشخصي")
                                    .accessibilityAddTraits(.isButton)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(displayFullName.isEmpty ? " " : displayFullName)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.black)

                                        Text(displayUsername.isEmpty ? " " : "@\(displayUsername)")
                                            .font(.system(size: 12))
                                            .foregroundColor(darkGreenIcon)
                                    }
                                }
                                .padding(.leading, 35)
                                .padding(.top, 5)
                            }
                        }
                    }
                    .frame(height: 210)

                    // MARK: - البحث + المفضلة + الفلترة
                    HStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(darkGreenIcon)
                                .font(.system(size: 14))

                            TextField("البحث عن قطعة...", text: $searchText)
                                .font(.system(size: 13))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                        .accessibilityLabel("البحث عن قطعة في الخزانة")

                        Button(action: {
                            showFavoritesOnly.toggle()
                            let msg = showFavoritesOnly ? "تم تفعيل عرض المفضلة فقط" : "تم إلغاء عرض المفضلة"
                            DitharVoiceAssistant.shared.speak(msg)
                        }) {
                            Image(systemName: showFavoritesOnly ? "heart.fill" : "heart")
                                .font(.system(size: 18))
                                .foregroundColor(showFavoritesOnly ? .red : darkGreenIcon)
                                .frame(width: 40, height: 40)
                                .background(showFavoritesOnly ? lightGreenButton : Color.white)
                                .cornerRadius(20)
                                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                        }
                        .accessibilityLabel("المفضلة")
                        .accessibilityValue(showFavoritesOnly ? "مفعل" : "غير مفعل")

                        Button(action: {
                            if !UIAccessibility.isVoiceOverRunning {
                                DitharVoiceAssistant.shared.speak("فتح التصفية المتقدمة")
                            }
                            showAdvancedFilter = true
                        }) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 18))
                                .foregroundColor(darkGreenIcon)
                                .frame(width: 40, height: 40)
                                .background(Color.white)
                                .cornerRadius(20)
                                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                        }
                        .accessibilityLabel("التصفية المتقدمة")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                   
                    // MARK: - أيقونات الفئات
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 18) {                     // ✅ مسافة ثابتة ومتساوية
                            SmallCategoryButton(icon: "square.grid.2x2", imageName: nil,
                                                isSelected: selectedCategory == "الكل",
                                                lightGreen: lightGreenButton, darkGreen: darkGreenIcon) {
                                selectedCategory = "الكل"
                                DitharVoiceAssistant.shared.speak("جميع القطع")
                            }

                            SmallCategoryButton(icon: nil, imageName: "icons8-clothes-64",
                                                isSelected: selectedCategory == "قطع علوية",
                                                lightGreen: lightGreenButton, darkGreen: darkGreenIcon) {
                                selectedCategory = "قطع علوية"
                                DitharVoiceAssistant.shared.speak("القطع العلوية")
                            }

                            SmallCategoryButton(icon: nil, imageName: "icons8-trousers-64",
                                                isSelected: selectedCategory == "قطع سفلية",
                                                lightGreen: lightGreenButton, darkGreen: darkGreenIcon) {
                                selectedCategory = "قطع سفلية"
                                DitharVoiceAssistant.shared.speak("القطع السفلية")
                            }

                            SmallCategoryButton(icon: nil, imageName: "icons8-trainers-64",
                                                isSelected: selectedCategory == "أحذية",
                                                lightGreen: lightGreenButton, darkGreen: darkGreenIcon) {
                                selectedCategory = "أحذية"
                                DitharVoiceAssistant.shared.speak("الأحذية")
                            }

                            SmallCategoryButton(icon: nil, imageName: "icons8-slip-dress-64",
                                                isSelected: selectedCategory == "قطع كاملة",
                                                lightGreen: lightGreenButton, darkGreen: darkGreenIcon) {
                                selectedCategory = "قطع كاملة"
                                DitharVoiceAssistant.shared.speak("القطع الكاملة")
                            }

                            SmallCategoryButton(icon: nil, imageName: "icons8-bag-64",
                                                isSelected: selectedCategory == "إكسسوارات",
                                                lightGreen: lightGreenButton, darkGreen: darkGreenIcon) {
                                selectedCategory = "إكسسوارات"
                                DitharVoiceAssistant.shared.speak("الإكسسوارات")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)   // ✅ هذا اللي يمنع “التجمع بجهة”
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)

                    }
                    .padding(.bottom, 16)


                    // MARK: - شرائح الفلاتر المتقدمة
                    if selectedAdvancedSubcategory != nil
                        || (selectedAdvancedCategory != "الكل")
                        || selectedAdvancedColor != nil
                        || selectedAdvancedPattern != nil {

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                if let sub = selectedAdvancedSubcategory, !sub.isEmpty {
                                    RemovableChip(title: sub, mainGreen: mainGreenColor) {
                                        selectedAdvancedSubcategory = nil
                                        selectedAdvancedCategory = "الكل"
                                        DitharVoiceAssistant.shared.speak("تم مسح الفئة")
                                    }
                                } else if selectedAdvancedCategory != "الكل" {
                                    RemovableChip(title: selectedAdvancedCategory, mainGreen: mainGreenColor) {
                                        selectedAdvancedCategory = "الكل"
                                        DitharVoiceAssistant.shared.speak("مسح الفئة")
                                    }
                                }

                                if let c = selectedAdvancedColor, !c.isEmpty {
                                    RemovableChip(title: c, mainGreen: mainGreenColor) {
                                        selectedAdvancedColor = nil
                                        DitharVoiceAssistant.shared.speak("تم مسح اللون")
                                    }
                                }

                                if let p = selectedAdvancedPattern, !p.isEmpty {
                                    RemovableChip(title: p, mainGreen: mainGreenColor) {
                                        selectedAdvancedPattern = nil
                                        DitharVoiceAssistant.shared.speak("تم مسح النقشة")
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 10)
                    }

                    // MARK: - عرض القطع
                    if filteredItems.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "tshirt")
                                .font(.system(size: 50))
                                .foregroundColor(lightGreenButton)
                            Text("لا توجد قطع مطابقة")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(darkGreenIcon)
                            Text("جرب البحث بكلمات أخرى")
                                .font(.system(size: 14))
                                .foregroundColor(darkGreenIcon.opacity(0.7))
                            Spacer()
                        }
                        .onAppear {
                            DitharVoiceAssistant.shared.speak("لا توجد نتائج مطابقة لخيارات البحث أو الفلاتر الحالية.")
                        }
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVGrid(
                                columns: [GridItem(.flexible(), spacing: 12),
                                          GridItem(.flexible(), spacing: 12)],
                                spacing: 12
                            ) {
                                ForEach(filteredItems) { item in
                                    GeometryReader { geo in
                                        ClothingItemCard(
                                            item: item,
                                            onFavoriteToggle: { updatedItem in
                                                if let index = clothingItems.firstIndex(where: { $0.id == updatedItem.id }) {
                                                    clothingItems[index].isFavorite = updatedItem.isFavorite
                                                }
                                            },
                                            side: geo.size.width
                                        )
                                    }
                                    .aspectRatio(1, contentMode: .fit)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 120)
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("قائمة القطع في خزانة ملابسك")
                        .accessibilitySortPriority(0)
                    }
                }

                // MARK: - زر الإضافة
                VStack {
                    Spacer()
                    HStack {
                        Button(action: {
                            if !UIAccessibility.isVoiceOverRunning {
                                DitharVoiceAssistant.shared.speak("إضافة قطعة جديدة إلى الخزانة")
                            }
                            showAddItem = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(mainGreenColor)
                                .cornerRadius(28)
                                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .padding(.leading, 20)
                        .padding(.bottom, 100)
                        .accessibilityLabel("إضافة قطعة جديدة إلى الخزانة")
                        .accessibilityAddTraits(.isButton)
                        .accessibilitySortPriority(40)

                        Spacer()
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)

            // ✅✅ التعديل المطلوب هنا
            .sheet(isPresented: $showStatistics) {
                WardrobeStatisticsView()
                    .environmentObject(authManager)
            }

            // ✅ صفحة التعرّف على القطعة
            .sheet(isPresented: $showTagIdentifier) {
                StatisticsView()
                    .environmentObject(authManager)
            }

            .sheet(isPresented: $showAddItem) { AddItemFlowView() }
            .sheet(isPresented: $showAdvancedFilter) {
                AdvancedFilterView(
                    selectedCategory: $selectedAdvancedCategory,
                    selectedSubcategory: $selectedAdvancedSubcategory,
                    selectedColor: $selectedAdvancedColor,
                    selectedPattern: $selectedAdvancedPattern,
                    onApply: { selectedCategory = "الكل" }
                )
            }
            .sheet(isPresented: $showNotifications, onDismiss: {
                if let userId = currentUserId {
                    notificationService.fetchUnreadCount(userId: userId) { _ in }
                }
            }) {
                NotificationsView()
            }
            .onAppear {
                loadUserData()
                fetchClothingItems()

                if let userId = currentUserId {
                    notificationService.startListeningToNotifications(userId: userId)
                }

                DitharVoiceAssistant.shared.announceScreenChange("صفحة الخزانة، لديك \(clothingItems.count) قطعة")
            }
            .onDisappear {
                notificationService.stopListeningToNotifications()
            }
        }
    }

    private func loadUserData() {
        Task {
            userData = await authManager.getUserData()
            userPhotoURL = userData?["photoURL"] as? String
            isLoading = false
        }
    }

    // MARK: - جلب القطع من Firestore
    private func fetchClothingItems() {
        guard let userId = authManager.user?.uid else {
            print("❌ لم يتم تسجيل الدخول")
            return
        }

        let db = Firestore.firestore()
        db.collection("Clothes")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ خطأ في جلب القطع:", error.localizedDescription)
                    return
                }
                guard let documents = snapshot?.documents else {
                    print("⚠️ لا توجد مستندات")
                    return
                }

                // ✅ احفظ الحالة السابقة قبل التحديث
                let previous = self.clothingItems

                self.clothingItems = documents.compactMap { doc in
                    let data = doc.data()

                    let name = (data["attrs"] as? [String: Any])?["description"] as? String ?? "بدون اسم"
                    let category = (data["analysis"] as? [String: Any])?["category"] as? String ?? "غير محدد"
                    let color = (data["analysis"] as? [String: Any])?["color"] as? String
                    let pattern = (data["analysis"] as? [String: Any])?["pattern"] as? String
                    let isFavorite = (data["meta"] as? [String: Any])?["isFavorite"] as? Bool ?? false
                    let isOutside = (data["meta"] as? [String: Any])?["isOutside"] as? Bool ?? false
                    let imageUrl = (data["image"] as? [String: Any])?["originalUrl"] as? String

                    let occasion = (data["attrs"] as? [String: Any])?["occasion"] as? String
                    let brand = (data["attrs"] as? [String: Any])?["brand"] as? String

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
                
                // ✅ اكتشف التغييرات وأرسل الإشعارات
                self.detectStatusChanges(previous: previous, current: self.clothingItems)
                
                print("✅ تم جلب \(self.clothingItems.count) قطعة")
            }
    }
    
    

    private func detectStatusChanges(previous: [ClothingItem], current: [ClothingItem]) {
        guard let userId = authManager.user?.uid else { return }
        
        // ✅ Don't send notifications on first load
        if isFirstLoad {
            isFirstLoad = false
            return
        }
        
        // ✅ Don't send notifications if previous is empty (first data load)
        guard !previous.isEmpty else { return }
        
        let now = Date()
        let notificationCooldown: TimeInterval = 2.0 // 2 seconds cooldown
        
        for currentItem in current {
            if let previousItem = previous.first(where: { $0.id == currentItem.id }) {
                
                // تحقق إذا تغيرت حالة isOutside
                if previousItem.isOutside != currentItem.isOutside {
                    
                    // ✅ Check if we recently sent a notification for this item
                    if let lastTime = lastNotificationTimes[currentItem.id],
                       now.timeIntervalSince(lastTime) < notificationCooldown {
                        print("⏭️ تخطي الإشعار - تم إرساله مؤخراً للقطعة: \(currentItem.id)")
                        continue
                    }
                    
                    print("🔔 تغيرت حالة القطعة: \(currentItem.category) \(currentItem.color ?? "")")
                    print("   من: \(previousItem.isOutside ? "خارج" : "داخل") → إلى: \(currentItem.isOutside ? "خارج" : "داخل")")
                    
                    // ✅ Record the notification time
                    lastNotificationTimes[currentItem.id] = now
                    
                    // أرسل الإشعار
                    notificationService.sendClothingStatusChangeNotification(
                        userId: userId,
                        clothingItemId: currentItem.id,
                        clothingItemName: currentItem.name.isEmpty ? nil : currentItem.name,
                        clothingItemCategory: currentItem.category.isEmpty ? nil : currentItem.category,
                        clothingItemColor: currentItem.color,
                        clothingItemImageURL: currentItem.localImageURLString,
                        isOutside: currentItem.isOutside
                    ) { success in
                        if success {
                            print("✅ تم إرسال إشعار تغيير حالة القطعة")
                        }
                    }
                }
            }
        }
        
        // ✅ Clean up old notification times (older than 1 minute)
        let oneMinuteAgo = now.addingTimeInterval(-60)
        lastNotificationTimes = lastNotificationTimes.filter { $0.value > oneMinuteAgo }
    }}

// MARK: - زر الفئة الصغير (دائرة بأيقونة فقط)
struct SmallCategoryButton: View {
    let icon: String?
    let imageName: String?
    let isSelected: Bool
    let lightGreen: Color
    let darkGreen: Color
    let action: () -> Void
    
    @State private var isBouncing = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isBouncing = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    isBouncing = false
                }
            }
            action()
        }) {

            ZStack {
                // ✅ (1) دائرة بيضاء مع ظل
                Circle()
                    .fill(Color.white)
                    .frame(width: 56, height: 56)          // حجم الدائرة
                    .shadow(color: .black.opacity(0.12),
                            radius: 6, x: 0, y: 3)

                // ✅ (2) الأيقونة أصغر ومتمركزة
                if let imageName = imageName {
                    Image(isSelected ? "\(imageName)-shadow" : imageName)
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)      // حجم الأيقونة
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(darkGreen)
                }
            }
            // ✅ (3) حركة النطة تبقى
            .scaleEffect(isBouncing ? 1.08 : 1.0)
            .offset(y: isBouncing ? -3 : 0)
        }
        .buttonStyle(.plain)
        // ❌ لا تحطين frame 40x40 هنا لأنه يكدّسها
    }
}


// MARK: - زر الفئة القديم (للتوافق)
struct CategoryButton: View {
    let icon: String?
    let imageName: String?
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            DitharVoiceAssistant.shared.speak("فئة \(title)")
            action()
        }) {
            VStack(spacing: 8) {
                Group {
                    if let imageName = imageName {
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                            .padding(16)
                    } else if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 24))
                            .padding(18)
                    }
                }
                .foregroundColor(isSelected ? Color(red: 0.47, green: 0.58, blue: 0.44) : Color(red: 0.35, green: 0.45, blue: 0.32))
                .background(Color(red: 0.91, green: 0.93, blue: 0.88))
                .clipShape(Circle())

                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? Color(red: 0.47, green: 0.58, blue: 0.44) : Color(red: 0.35, green: 0.45, blue: 0.32))
            }
        }
    }
}

// MARK: - بطاقة القطعة مع وصف صوتي
struct ClothingItemCard: View {
    let item: ClothingItem
    let onFavoriteToggle: (ClothingItem) -> Void
    let side: CGFloat

    @State private var isFavorite: Bool
    @State private var navigateToDetails = false

    init(item: ClothingItem, onFavoriteToggle: @escaping (ClothingItem) -> Void, side: CGFloat) {
        self.item = item
        self.onFavoriteToggle = onFavoriteToggle
        self.side = side
        _isFavorite = State(initialValue: item.isFavorite)
    }

    var body: some View {
        NavigationLink(
            destination: ClothingItemDetailsView(clothingItemId: item.id),
            isActive: $navigateToDetails
        ) { EmptyView() }
            .hidden()

        Button(action: {
            DitharVoiceAssistant.shared.speak(itemAccessibilityLabel)
            navigateToDetails = true
        }) {
            ZStack {
                imageSquare

                VStack {
                    HStack {
                        Spacer()
                        Button {
                            isFavorite.toggle()
                            var updated = item
                            updated.isFavorite = isFavorite
                            onFavoriteToggle(updated)
                            updateFavoriteStatus(itemId: item.id, isFavorite: isFavorite)

                            let msg = isFavorite ? "تمت إضافة القطعة إلى المفضلة" : "تمت إزالة القطعة من المفضلة"
                            DitharVoiceAssistant.shared.speak(msg)
                        } label: {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 20))
                                .foregroundColor(isFavorite ? .red : Color(red: 0.35, green: 0.45, blue: 0.32))
                                .padding(10)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }

                if item.isOutside {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("خارج")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.red)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white)
                                .cornerRadius(15)
                                .padding(10)
                        }
                    }
                }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color(red: 0.91, green: 0.93, blue: 0.88), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(itemAccessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var imageSquare: some View {
        if let urlString = item.localImageURLString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: side, height: side)
                        .clipped()
                } else if phase.error != nil {
                    placeholderSquare
                } else {
                    placeholderSquare.overlay(ProgressView())
                }
            }
        } else {
            placeholderSquare
        }
    }

    private var placeholderSquare: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color(red: 0.91, green: 0.93, blue: 0.88))
            .frame(width: side, height: side)
    }

    private var itemAccessibilityLabel: String {
        var parts: [String] = []

        let baseCategory: String
        if !item.category.isEmpty, item.category != "غير محدد" {
            baseCategory = item.category
        } else {
            baseCategory = "قطعة ملابس"
        }
        parts.append(baseCategory)

        if let color = item.color, !color.isEmpty { parts.append(color) }
        if let pattern = item.pattern, !pattern.isEmpty { parts.append(pattern) }
        if item.isOutside { parts.append("خارج الخزانة الآن") }

        let text = parts.joined(separator: " ")
        return text.isEmpty ? "قطعة ملابس" : text
    }
}

// MARK: - Chip قابل للإزالة
private struct RemovableChip: View {
    let title: String
    let mainGreen: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(mainGreen)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(mainGreen)
                    .padding(6)
                    .background(Color.white.opacity(0.7))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(mainGreen.opacity(0.15))
        .cornerRadius(18)
    }
}

// =====================================================
// =============== صفحة التعرّف (StatisticsView) =========
// =====================================================

// MARK: - حالة مسح التعرّف
enum IdentifyScanState {
    case idle
    case waiting
    case capturing
    case done
    case timeout

    var label: String {
        switch self {
        case .idle: return "جاهز للتعرّف"
        case .waiting: return "بانتظار تمرير القطعة..."
        case .capturing: return "جاري التعرّف على القطعة..."
        case .done: return "تم التعرّف بنجاح"
        case .timeout: return "تعذّر التعرّف. حاول مرة أخرى."
        }
    }

    var dotColor: Color {
        switch self {
        case .idle: return Color(red: 0.35, green: 0.45, blue: 0.32)
        case .waiting: return .yellow
        case .capturing: return .orange
        case .done: return Color(red: 0.47, green: 0.58, blue: 0.44)
        case .timeout: return .red
        }
    }
}

// MARK: - نسخة محلية من startEnrollmentRequest
fileprivate func startEnrollmentRequest(
    clotheId: String,
    userName: String,
    speechService: CustomSpeechService,
    onUpdate: @escaping (_ status: String, _ epc: String?) -> Void
) -> ListenerRegistration {
    let db = Firestore.firestore()
    let requestsRef = db.collection("EnrollRequests")

    let docRef = requestsRef.document()
    docRef.setData([
        "clotheId": clotheId,
        "userName": userName,
        "status": "waiting",
        "createdAt": FieldValue.serverTimestamp()
    ], merge: true)

    let listener = docRef.addSnapshotListener { snapshot, error in
        guard let data = snapshot?.data(), error == nil else {
            onUpdate("timeout", nil)
            return
        }

        let status = data["status"] as? String ?? "waiting"
        let epc = data["epc"] as? String
        onUpdate(status, epc)
    }

    return listener
}

// MARK: - جلب قطعة واحدة بالاعتماد على الـ EPC
fileprivate func fetchClothingItem(byEPC epc: String, completion: @escaping (ClothingItem?) -> Void) {
    guard !epc.isEmpty else {
        completion(nil)
        return
    }

    let db = Firestore.firestore()

    db.collection("Clothes")
        .whereField("meta.epc", isEqualTo: epc)
        .limit(to: 1)
        .getDocuments { snapshot, error in
            if let error = error {
                print("❌ خطأ في جلب القطعة حسب EPC:", error.localizedDescription)
                completion(nil)
                return
            }

            guard let doc = snapshot?.documents.first else {
                completion(nil)
                return
            }

            let data = doc.data()

            let name = (data["attrs"] as? [String: Any])?["description"] as? String ?? "بدون اسم"
            let category = (data["analysis"] as? [String: Any])?["category"] as? String ?? "غير محدد"
            let color = (data["analysis"] as? [String: Any])?["color"] as? String
            let pattern = (data["analysis"] as? [String: Any])?["pattern"] as? String
            let isFavorite = (data["meta"] as? [String: Any])?["isFavorite"] as? Bool ?? false
            let isOutside = (data["meta"] as? [String: Any])?["isOutside"] as? Bool ?? false
            let imageUrl = (data["image"] as? [String: Any])?["originalUrl"] as? String

            let occasion = (data["attrs"] as? [String: Any])?["occasion"] as? String
            let brand = (data["attrs"] as? [String: Any])?["brand"] as? String

            let item = ClothingItem(
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

            completion(item)
        }
}

// MARK: - صفحة التعرّف على قطعة
struct StatisticsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthenticationManager

    @State private var scanState: IdentifyScanState = .idle
    @State private var isScanning = false
    @State private var listener: ListenerRegistration? = nil

    @State private var detectedItem: ClothingItem? = nil
    @State private var isLoadingItem = false
    @State private var lastEPC: String = ""

    @State private var showDetails = false

    private let speechService = CustomSpeechService()
    private let mainGreenColor = Color(red: 0.47, green: 0.58, blue: 0.44)
    private let darkGreenIcon = Color(red: 0.35, green: 0.45, blue: 0.32)

    var body: some View {
        NavigationView {
            ZStack {
                Color.white.ignoresSafeArea()

                VStack(spacing: 20) {

                    ZStack {
                        HStack {
                            Spacer()
                            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.black)
                            }
                        }
                        .padding(.horizontal, 20)

                        Text("التعرّف على قطعة")
                            .font(.system(size: 20, weight: .semibold))
                    }
                    .padding(.top, 16)

                    HStack {
                        Spacer()
                        Text(scanState.label)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)
                            .accessibilityHidden(true)

                        Circle()
                            .fill(scanState.dotColor)
                            .frame(width: 10, height: 10)
                            .accessibilityHidden(true)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .background(Color(red: 0.91, green: 0.93, blue: 0.88))
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(scanState.label)

                    VStack(spacing: 12) {
                        if isLoadingItem {
                            ProgressView("جاري التعرّف على القطعة...")
                        } else if let item = detectedItem {

                            if let urlString = item.localImageURLString,
                               let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(height: 180)
                                            .frame(maxWidth: .infinity)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                    case .failure(_):
                                        placeholderImageCard
                                    case .empty:
                                        ProgressView().frame(height: 180)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            } else {
                                placeholderImageCard
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.category.isEmpty ? "فئة غير محددة" : item.category)
                                    .font(.system(size: 16, weight: .semibold))

                                if let color = item.color, !color.isEmpty {
                                    Text("اللون: \(color)").font(.system(size: 14))
                                }
                                if let pattern = item.pattern, !pattern.isEmpty {
                                    Text("النقشة: \(pattern)").font(.system(size: 14))
                                }
                                if item.isOutside {
                                    Text("القطعة حالياً خارج الخزانة")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.red)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                        } else {
                            VStack(spacing: 8) {
                                placeholderImageCard
                                    .overlay(
                                        Image(systemName: "hourglass.start")
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(darkGreenIcon.opacity(0.7))
                                    )

                                Text("قرب معرف القطعة الى القارئ")
                                    .font(.system(size: 14))
                                    .foregroundColor(darkGreenIcon)
                                Text("اضغط على بدء التعرف لاكتشاف القطعة المربوطة")
                                    .font(.system(size: 14))
                                    .foregroundColor(darkGreenIcon)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0.91, green: 0.93, blue: 0.88).opacity(0.5))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)

                    Spacer()

                    VStack(spacing: 10) {
                        Button(action: {
                            if detectedItem != nil {
                                resetScan()
                                startIdentifyScan()
                            } else {
                                startIdentifyScan()
                            }
                        }) {
                            Text(isScanning ? "جاري التعرّف..." : (detectedItem == nil ? "بدء التعرّف" : "إعادة المسح"))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(mainGreenColor)
                                .cornerRadius(12)
                        }
                        .disabled(isScanning)

                        Button(action: {
                            if detectedItem != nil { showDetails = true }
                        }) {
                            Text("استعراض تفاصيل أكثر")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(detectedItem == nil ? darkGreenIcon.opacity(0.4) : darkGreenIcon)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                        }
                        .disabled(detectedItem == nil)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                if !UIAccessibility.isVoiceOverRunning {
                    let msg = "صفحة التعرّف على قطعة. اضغط على زر بدء التعرّف، ثم قرّب القطعة من قارئ آر إف آي دي."
                    DitharVoiceAssistant.shared.announceScreenChange(msg)
                }
            }
            .onDisappear {
                listener?.remove()
                listener = nil
            }
            .background(
                NavigationLink(
                    destination: Group {
                        if let item = detectedItem {
                            ClothingItemDetailsView(clothingItemId: item.id)
                        } else {
                            EmptyView()
                        }
                    },
                    isActive: $showDetails
                ) { EmptyView() }
                .hidden()
            )
        }
    }

    private var placeholderImageCard: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.white)
            .frame(height: 180)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func startIdentifyScan() {
        guard !isScanning else { return }
        isScanning = true
        scanState = .waiting
        detectedItem = nil
        lastEPC = ""
        isLoadingItem = false

        listener?.remove()

        let userName = authManager.user?.displayName ?? "user"

        listener = startEnrollmentRequest(
            clotheId: "identify-session",
            userName: userName,
            speechService: speechService
        ) { status, epc in
            switch status {
            case "capturing":
                scanState = .capturing

            case "done":
                isScanning = false
                listener?.remove()
                listener = nil

                guard let epc = epc, !epc.isEmpty else {
                    scanState = .timeout
                    speechService.speak(text: "فشل التعرّف. لم يتم استلام المعرّف.")
                    return
                }

                lastEPC = epc
                isLoadingItem = true
                fetchClothingItem(byEPC: epc) { item in
                    DispatchQueue.main.async {
                        isLoadingItem = false
                        if let item = item {
                            detectedItem = item
                            scanState = .done
                            speechService.speak(text: summaryText(for: item))
                        } else {
                            scanState = .timeout
                            speechService.speak(text: "لم يتم العثور على قطعة مرتبطة بهذا المعرّف.")
                        }
                    }
                }

            case "timeout":
                isScanning = false
                scanState = .timeout
                listener?.remove()
                listener = nil
                speechService.speak(text: "انتهت مهلة التعرّف دون استلام أي معرّف.")

            default:
                break
            }
        }

        if !UIAccessibility.isVoiceOverRunning {
            DitharVoiceAssistant.shared.speak("تم بدء عملية التعرّف. قرّب القطعة من قارئ آر إف آي دي.")
        }
    }

    private func resetScan() {
        listener?.remove()
        listener = nil
        isScanning = false
        detectedItem = nil
        lastEPC = ""
        scanState = .idle
        isLoadingItem = false
    }

    private func summaryText(for item: ClothingItem) -> String {
        var parts: [String] = []

        let baseCategory = item.category.isEmpty || item.category == "غير محدد" ? "قطعة ملابس" : item.category
        parts.append(baseCategory)

        if let color = item.color, !color.isEmpty { parts.append("لونها \(color)") }
        if let pattern = item.pattern, !pattern.isEmpty { parts.append("بنقشة \(pattern)") }
        if let occasion = item.occasion, !occasion.isEmpty { parts.append("مناسبة لـ \(occasion)") }
        if item.isOutside { parts.append("وهي الآن خارج الخزانة") }

        let text = parts.joined(separator: "، ")
        return text.isEmpty ? "قطعة ملابس" : text
    }
}

