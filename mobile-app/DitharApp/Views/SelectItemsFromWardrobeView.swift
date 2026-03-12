import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SelectItemsFromWardrobeView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedItems: [LinkedClothingItem]

    @State private var wardrobeItems: [WardrobeClothingItem] = []
    @State private var isLoading = true
    @State private var tempSelectedIds: Set<String> = []

    // ✅ فلتر جديد (مثل صفحة اختيار قطع الإطلالة)
    @State private var selectedCategory: String = "الكل"
    @State private var selectedColor: String? = nil

    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    // ✅ ألوان موحّدة
    private let lightGreenButton = Color(red: 0.91, green: 0.93, blue: 0.88)
    private let darkGreenIcon = Color(red: 0.35, green: 0.45, blue: 0.32)
    private let mainGreen = Color(red: 0.47, green: 0.58, blue: 0.44)

    // ✅ نفس قائمة الألوان
    private let basicColors: [(String, Color)] = [
        ("أبيض", .white),
        ("أسود", .black),
        ("رمادي", .gray),
        ("بني", .brown),
        ("بيج", Color(red: 0.96, green: 0.96, blue: 0.86)),
        ("أحمر", .red),
        ("وردي", .pink),
        ("بنفسجي", .purple),
        ("برتقالي", .orange),
        ("أصفر", .yellow),
        ("أخضر", .green),
        ("سماوي", .cyan),
        ("أزرق", .blue),
        ("ذهبي", Color(red: 1.0, green: 0.84, blue: 0.0)),
        ("فضي", Color(red: 0.75, green: 0.75, blue: 0.75))
    ]

    // ✅ نفس تقسيم الفئات
    private let categoryMapping: [String: [String]] = [
        "قطع علوية": ["قميص", "بلوزة", "كنزة", "معطف", "تيشيرت"],
        "قطع سفلية": ["بنطلون", "بنطال", "تنورة", "شورت", "شيال"],
        "قطع كاملة": ["فستان", "شيال", "ثوب", "عباية"],
        "أحذية": ["حذاء", "حذاء رياضي", "حذاء رسمي", "صندل", "كعب", "بوت"],
        "إكسسوارات": ["إكسسوارت", "إكسسوارات", "سلسال", "اسورة", "حلق", "خاتم", "ساعة", "نظارة", "حقيبة", "حزام", "قبعة", "وشاح"]
    ]

    // ✅ فلترة القطع
    private var filteredItems: [WardrobeClothingItem] {
        wardrobeItems.filter { item in
            let matchesCategory: Bool = {
                if selectedCategory == "الكل" { return true }
                if let subs = categoryMapping[selectedCategory] {
                    return subs.contains(item.category)
                }
                return item.category == selectedCategory
            }()

            let matchesColor = (selectedColor == nil) || (item.color == selectedColor)
            return matchesCategory && matchesColor
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                // ✅ Header ثابت (إضافة يسار - إلغاء يمين)
                headerBar

                // ✅ الفلاتر الجديدة
                filtersBar

                Divider()

                if isLoading {
                    Spacer()
                    ProgressView()
                        .accessibilityLabel("جاري تحميل قطع الخزانة")
                    Spacer()

                } else if filteredItems.isEmpty && selectedItemsNotInWardrobe.isEmpty {
                    emptyState

                } else {
                    itemsGrid
                }
            }
            .navigationBarHidden(true) // ✅ مهم جدًا عشان ما ينقلب
            .onAppear {
                loadWardrobeItems()
                tempSelectedIds = Set(selectedItems.map { $0.id })
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: - ✅ Header ثابت (LTR فقط)
    private var headerBar: some View {
        HStack {
            // ✅ إضافة يسار
            Button("إضافة (\(tempSelectedIds.count))") {
                applySelection()
                presentationMode.wrappedValue.dismiss()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(tempSelectedIds.isEmpty ? .gray : mainGreen)
            .disabled(tempSelectedIds.isEmpty)

            Spacer()

            Text("اختر القطع")
                .font(.headline)
                .fontWeight(.bold)

            Spacer()

            // ✅ إلغاء يمين
            Button("إلغاء") {
                presentationMode.wrappedValue.dismiss()
            }
            .font(.system(size: 16))
            .foregroundColor(.gray)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(Color.white)
        .environment(\.layoutDirection, .leftToRight) // ✅ هذا يمنع الانعكاس
    }

    // MARK: - ✅ Filters Bar (Icons + Colors)
    private var filtersBar: some View {
        VStack(spacing: 10) {

            // ✅ فلتر الفئات بالأيقونات
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {

                    SmallCategoryIconButton(
                        icon: "square.grid.2x2",
                        imageName: nil,
                        label: "الكل",
                        isSelected: selectedCategory == "الكل",
                        lightGreen: lightGreenButton,
                        darkGreen: darkGreenIcon
                    ) { selectedCategory = "الكل" }

                    SmallCategoryIconButton(
                        icon: nil,
                        imageName: "icons8-clothes-64",
                        label: "قطع علوية",
                        isSelected: selectedCategory == "قطع علوية",
                        lightGreen: lightGreenButton,
                        darkGreen: darkGreenIcon
                    ) { selectedCategory = "قطع علوية" }

                    SmallCategoryIconButton(
                        icon: nil,
                        imageName: "icons8-trousers-64",
                        label: "قطع سفلية",
                        isSelected: selectedCategory == "قطع سفلية",
                        lightGreen: lightGreenButton,
                        darkGreen: darkGreenIcon
                    ) { selectedCategory = "قطع سفلية" }

                    SmallCategoryIconButton(
                        icon: nil,
                        imageName: "icons8-slip-dress-64",
                        label: "قطع كاملة",
                        isSelected: selectedCategory == "قطع كاملة",
                        lightGreen: lightGreenButton,
                        darkGreen: darkGreenIcon
                    ) { selectedCategory = "قطع كاملة" }

                    SmallCategoryIconButton(
                        icon: nil,
                        imageName: "icons8-trainers-64",
                        label: "أحذية",
                        isSelected: selectedCategory == "أحذية",
                        lightGreen: lightGreenButton,
                        darkGreen: darkGreenIcon
                    ) { selectedCategory = "أحذية" }

                    SmallCategoryIconButton(
                        icon: nil,
                        imageName: "icons8-bag-64",
                        label: "إكسسوارات",
                        isSelected: selectedCategory == "إكسسوارات",
                        lightGreen: lightGreenButton,
                        darkGreen: darkGreenIcon
                    ) { selectedCategory = "إكسسوارات" }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }

            // ✅ فلتر الألوان
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {

                    Button(action: { selectedColor = nil }) {
                        Circle()
                            .strokeBorder(selectedColor == nil ? Color.black : Color.gray.opacity(0.3), lineWidth: 2)
                            .background(
                                Circle().fill(
                                    LinearGradient(
                                        colors: [.red, .orange, .yellow, .green, .blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            )
                            .frame(width: 40, height: 40)
                    }

                    ForEach(basicColors, id: \.0) { colorName, color in
                        Button(action: { selectedColor = colorName }) {
                            Circle()
                                .fill(color)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle().strokeBorder(
                                        selectedColor == colorName ? Color.black : Color.gray.opacity(0.2),
                                        lineWidth: 2
                                    )
                                )
                                .overlay(
                                    selectedColor == colorName
                                    ? Image(systemName: "checkmark")
                                        .foregroundColor(.white)
                                        .font(.system(size: 16, weight: .bold))
                                    : nil
                                )
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 6)
            }
        }
        .padding(.bottom, 10)
        .background(Color.white)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tshirt")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
                .accessibilityHidden(true)

            Text("لا توجد قطع")
                .font(.system(size: 15))
                .foregroundColor(.gray)
                .accessibilityHidden(true)
            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("لا توجد قطع مطابقة للفلاتر الحالية.")
    }

    // MARK: - Items Grid
    private var itemsGrid: some View {
        ScrollView {
            VStack(spacing: 16) {

                if !selectedItemsNotInWardrobe.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("القطع المحددة من الإطلالة")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)

                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                            spacing: 16
                        ) {
                            ForEach(selectedItemsNotInWardrobe, id: \.id) { item in
                                OutfitItemCard(item: item) {
                                    tempSelectedIds.remove(item.id)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 8)
                }

                if !filteredItems.isEmpty {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 16
                    ) {
                        ForEach(filteredItems, id: \.id) { item in
                            let isSelected = tempSelectedIds.contains(item.id)

                            ItemSelectionCard(
                                item: item,
                                isSelected: isSelected,
                                onTap: {
                                    if isSelected {
                                        tempSelectedIds.remove(item.id)
                                    } else {
                                        tempSelectedIds.insert(item.id)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .accessibilityLabel("قائمة قطع الخزانة")
        .accessibilityHint("اسحبي للتنقل بين القطع، واضغطي مرتين على أي قطعة لإضافتها أو إزالتها.")
    }

    private var selectedItemsNotInWardrobe: [LinkedClothingItem] {
        let wardrobeIds = Set(wardrobeItems.map { $0.id })
        return selectedItems.filter { !wardrobeIds.contains($0.id) }
    }

    // MARK: - Load Wardrobe Items
    private func loadWardrobeItems() {
        isLoading = true
        guard let userId = currentUserId else { return }

        let db = Firestore.firestore()
        db.collection("Clothes")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ خطأ في جلب القطع: \(error.localizedDescription)")
                    self.isLoading = false
                    return
                }

                self.wardrobeItems = snapshot?.documents.compactMap { doc in
                    WardrobeClothingItem.fromDocument(doc)
                } ?? []

                self.isLoading = false
            }
    }

    // MARK: - Apply Selection
    private func applySelection() {
        let selected = wardrobeItems.filter { tempSelectedIds.contains($0.id) }

        let newItems = selected.map { item -> LinkedClothingItem in
            let existingLink = selectedItems.first(where: { $0.id == item.id })?.purchaseLink

            return LinkedClothingItem(
                id: item.id,
                category: item.category,
                color: item.color,
                imageURL: item.imageURL,
                purchaseLink: existingLink ?? item.purchaseLink
            )
        }

        var mergedItems: [LinkedClothingItem] = []
        var processedIds = Set<String>()

        for item in newItems {
            if !processedIds.contains(item.id) {
                mergedItems.append(item)
                processedIds.insert(item.id)
            }
        }

        for item in selectedItems {
            if !processedIds.contains(item.id) && tempSelectedIds.contains(item.id) {
                mergedItems.append(item)
                processedIds.insert(item.id)
            }
        }

        selectedItems = mergedItems
    }
}

// MARK: - بطاقة قطعة من الإطلالة
struct OutfitItemCard: View {
    let item: LinkedClothingItem
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: item.imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(red: 0.91, green: 0.93, blue: 0.88)) // أخضر فاتح
                }
                .frame(height: 120)
                .clipped()
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 0.47, green: 0.58, blue: 0.44), lineWidth: 3)
                )

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(red: 0.47, green: 0.58, blue: 0.44))
                    .background(Circle().fill(Color.white))
                    .padding(8)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - بطاقة اختيار القطعة
struct ItemSelectionCard: View {
    let item: WardrobeClothingItem
    let isSelected: Bool
    let onTap: () -> Void

    private var accessibilityLabelText: String {
        var parts: [String] = []
        parts.append("قطعة")
        parts.append("الفئة \(item.category)")
        if let color = item.color, !color.isEmpty { parts.append("باللون \(color)") }
        parts.append(isSelected ? "مضافة حاليًا" : "غير مضافة")
        return parts.joined(separator: "، ")
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: item.imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(red: 0.91, green: 0.93, blue: 0.88)) // أخضر فاتح
                }
                .frame(height: 120)
                .clipped()
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color(red: 0.47, green: 0.58, blue: 0.44) : Color.clear, lineWidth: 3)
                )

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(red: 0.47, green: 0.58, blue: 0.44))
                        .background(Circle().fill(Color.white))
                        .padding(8)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint("اضغطي مرتين لإضافة أو إزالة هذه القطعة.")
    }
}

struct WardrobeClothingItem {
    let id: String
    let category: String
    let color: String?
    let imageURL: String
    let purchaseLink: String?

    static func fromDocument(_ doc: DocumentSnapshot) -> WardrobeClothingItem? {
        guard let data = doc.data() else { return nil }

        let category = (data["analysis"] as? [String: Any])?["category"] as? String ?? "غير محدد"
        let color = (data["analysis"] as? [String: Any])?["color"] as? String
        let imageURL = (data["image"] as? [String: Any])?["originalUrl"] as? String ?? ""
        let purchaseLink = (data["attrs"] as? [String: Any])?["purchaseLink"] as? String

        return WardrobeClothingItem(
            id: doc.documentID,
            category: category,
            color: color,
            imageURL: imageURL,
            purchaseLink: purchaseLink
        )
    }
}

// MARK: - Preview
struct SelectItemsFromWardrobeView_Previews: PreviewProvider {
    static var previews: some View {
        SelectItemsFromWardrobeView(selectedItems: .constant([]))
            .environment(\.layoutDirection, .rightToLeft)
    }
}
