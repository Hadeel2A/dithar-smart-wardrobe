import SwiftUI
import Firebase
import FirebaseFirestore

// MARK: - Models
struct OutfitItem: Identifiable, Codable , Hashable {
    let id: String
    let clothingItemId: String
    let name: String
    let category: String
    let color: String?
    let localImageURLString: String?
    var position: CGPoint // موقع القطعة في المربع
    var size: CGSize // حجم القطعة
    var scale: CGFloat = 1.0 // مقياس التكبير/التصغير
}

struct Outfit: Identifiable, Codable, Hashable {
    let id: String
    let userId: String
    var items: [OutfitItem]
    var listName: String?
    let createdAt: Date
    var isFavorite: Bool = false
    var listId: String? = nil
}

// MARK: - AddOutfitView
struct AddOutfitView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthenticationManager

    @State private var selectedItems: [OutfitItem] = []
    @State private var showingAddItemSheet = false
    @State private var selectedListName: String = ""
    @State private var selectedListId: String? = nil
    @State private var showListPicker = false
    @State private var selectedItemId: String? = nil // القطعة المحددة للحذف
    @State private var lists: [OutfitList] = []
    @State private var showManageLists = false
    @State private var showAutoGenerateSheet = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    // ألوان (مطابقة لفكرة OutfitsView)
    private let lightGreenButton = Color(red: 0.91, green: 0.93, blue: 0.88) // ✅ أخضر فاتح
    private let darkGreenIcon = Color(red: 0.35, green: 0.45, blue: 0.32)
    private let mainGreen = Color(red: 0.47, green: 0.58, blue: 0.44)

    private func arabicListWithDetails(from items: [OutfitItem]) -> String {
        let descriptions = items.map { item in
            if let color = item.color, !color.isEmpty {
                return "\(item.category) \(color)"
            } else {
                return item.category
            }
        }

        switch descriptions.count {
        case 0:
            return ""
        case 1:
            return descriptions[0]
        case 2:
            return "\(descriptions[0]) و\(descriptions[1])"
        default:
            let allButLast = descriptions.dropLast().joined(separator: "، ")
            if let last = descriptions.last {
                return "\(allButLast)، و\(last)"
            } else {
                return descriptions.joined(separator: "، ")
            }
        }
    }

    let canvasSize: CGSize = CGSize(width: 350, height: 400)

    private var canvasAccessibilitySummary: String {
        if selectedItems.isEmpty {
            return "إطار تنسيق الإطلالة، لا توجد قطع مضافة حتى الآن. اضغطي على زر إضافة القطع أسفل الإطار لبدء تنسيق إطلالة جديدة."
        } else {
            let listText = arabicListWithDetails(from: selectedItems)

            var label = "تم تنسيق إطلالة تحتوي على \(listText). يمكنك حفظ الإطلالة الآن أو تعديل ترتيب القطع داخل الإطار."

            if let selectedId = selectedItemId,
               let selected = selectedItems.first(where: { $0.id == selectedId }) {
                if let color = selected.color, !color.isEmpty {
                    label += " القطعة المحددة حاليًا هي \(selected.category) \(color)."
                } else {
                    label += " القطعة المحددة حاليًا هي \(selected.category)."
                }
            }

            return label
        }
    }

    // ✅ القوائم بالطريقة الجديدة (مثل OutfitsView)
    private var listsFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {

                // فلتر "الكل"
                ListFilterButton(title: "الكل", isSelected: selectedListId == nil) {
                    selectedListId = nil
                    selectedListName = ""
                    if AccessibilityManager.shared.isAVSpeechEnabled {
                        DitharVoiceAssistant.shared.speak("تم اختيار الكل")
                    }
                }

                // القوائم المحفوظة
                ForEach(lists) { list in
                    ListFilterButton(title: list.name, isSelected: selectedListId == list.id) {
                        selectedListId = list.id
                        selectedListName = list.name
                        if AccessibilityManager.shared.isAVSpeechEnabled {
                            DitharVoiceAssistant.shared.speak("تم اختيار قائمة \(list.name)")
                        }
                    }
                }

                // زر + (آخر شيء)
                Button(action: {
                    if AccessibilityManager.shared.isAVSpeechEnabled {
                        DitharVoiceAssistant.shared.speak("إضافة قائمة جديدة")
                    }
                    showManageLists = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(darkGreenIcon)
                        .frame(width: 40, height: 40)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("إضافة قائمة")
                .accessibilityHint("إنشاء قائمة جديدة لحفظ الإطلالات وتنظيمها")
                .accessibilityAddTraits(.isButton)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .padding(.bottom, 10)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.edgesIgnoringSafeArea(.all)

                VStack(spacing: 20) {
                    header

                    listsFilterBar

                    canvasSection

                    actionButtons

                    saveButton

                    Spacer()
                }
                .padding(.bottom, 80)
            }
            .navigationBarHidden(true)
            .alert("تنبيه", isPresented: $showAlert) {
                Button("موافق") { }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showingAddItemSheet) {
                SelectItemsSheetView(
                    selectedItems: $selectedItems,
                    canvasSize: canvasSize
                )
                .environmentObject(authManager)
            }
            .sheet(isPresented: $showManageLists) {
                ManageListsView(lists: $lists)
                    .environmentObject(authManager)
            }
            .sheet(isPresented: $showAutoGenerateSheet) {
                AutoGenerateOutfitView(generatedItems: Binding(
                    get: { nil },
                    set: { newItems in
                        if let items = newItems {
                            selectedItems = items

                            let listText = arabicListWithDetails(from: selectedItems)
                            let message = "تم تنسيق إطلالة تحتوي على \(listText). يمكنك حفظ الإطلالة الآن أو تعديل ترتيب القطع داخل الإطار."
                            DitharVoiceAssistant.shared.speak(message)
                        }
                    }
                ))
                .environmentObject(authManager)
            }
            .onAppear {
                loadLists()
                DitharVoiceAssistant.shared.announceScreenChange(
                    "شاشة تنسيق إطلالة جديدة. أضيفي قطعًا من خزانة ملابسك ورتبيها داخل الإطار."
                )
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            Button(action: {
                DitharVoiceAssistant.shared.speak("الرجوع إلى صفحة الإطلالات.")
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "arrow.right")
                    .font(.title2)
                    .foregroundColor(.black)
            }
            .accessibilityLabel("رجوع")
            .accessibilityHint("العودة إلى صفحة الإطلالات دون حفظ الإطلالة.")

            Spacer()
            Text("تنسيق اطلالة")
                .font(.headline)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Color.clear.frame(width: 30)
                .accessibilityHidden(true)
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }

    @ViewBuilder
    private var canvasSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                .accessibilityHidden(true)

            if selectedItems.isEmpty {
                VStack {
                    Image(systemName: "tshirt")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.3))
                        .accessibilityHidden(true)

                    Text("اضغط على زر إضافة لإضافة قطع")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .accessibilityHidden(true)
                }
            } else {
                ForEach(selectedItems) { item in
                    DraggableItemView(
                        item: item,
                        canvasSize: canvasSize,
                        isSelected: selectedItemId == item.id,
                        onTap: {
                            selectedItemId = item.id
                            DitharVoiceAssistant.shared.speak(
                                "تم تحديد قطعة من فئة \(item.category) في الإطلالة."
                            )
                        },
                        onPositionChange: { newPosition in
                            updateItemPosition(itemId: item.id, newPosition: newPosition)
                        },
                        onScaleChange: { newScale in
                            updateItemScale(itemId: item.id, newScale: newScale)
                        }
                    )
                }
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 20) {
            Spacer()

            Button(action: {
                DitharVoiceAssistant.shared.speak("تنسيق تلقائي للإطلالة. سيتم اقتراح إطلالة مناسبة بناءً على قطع خزانتك.")
                showAutoGenerateSheet = true
            }) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(mainGreen)
                    .clipShape(Circle())
            }
            .accessibilityLabel("تنسيق تلقائي للإطلالة")
            .accessibilityHint("اقتراح تنسيق تلقائي للقطع المناسبة.")

            Button(action: {
                DitharVoiceAssistant.shared.speak("إضافة قطع من الخزانة إلى هذه الإطلالة.")
                showingAddItemSheet = true
            }) {
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(mainGreen)
                    .clipShape(Circle())
            }
            .accessibilityLabel("إضافة قطع من الخزانة")
            .accessibilityHint("فتح قائمة خزانة الملابس لاختيار قطع للإطلالة.")

            Button(action: {
                deleteSelectedItem()
                DitharVoiceAssistant.shared.speak("تم حذف القطعة المحددة من الإطلالة.")
            }) {
                Image(systemName: "trash")
                    .font(.title2)
                    .foregroundColor(selectedItemId != nil ? .white : .gray)
                    .frame(width: 50, height: 50)
                    .background(selectedItemId != nil ? Color(red: 0.8, green: 0.5, blue: 0.4) : lightGreenButton)
                    .clipShape(Circle())
            }
            .disabled(selectedItemId == nil)
            .accessibilityLabel("حذف القطعة المحددة")
            .accessibilityHint("حذف القطعة المحددة من الإطلالة.")

            Spacer()
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var saveButton: some View {
        Button(action: {
            saveOutfit()
        }) {
            Text("حفظ الاطلالة")
                .font(.headline)
                .foregroundColor(selectedItems.isEmpty ? .gray : .white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedItems.isEmpty ? lightGreenButton : mainGreen)
                .cornerRadius(15)
        }
        .disabled(selectedItems.isEmpty)
        .padding(.horizontal)
        .accessibilityLabel("حفظ الإطلالة")
        .accessibilityHint("حفظ الإطلالة الحالية في قائمة الإطلالات.")
    }

    // MARK: - Functions
    private func updateItemPosition(itemId: String, newPosition: CGPoint) {
        if let index = selectedItems.firstIndex(where: { $0.id == itemId }) {
            selectedItems[index].position = newPosition
        }
    }

    private func updateItemScale(itemId: String, newScale: CGFloat) {
        if let index = selectedItems.firstIndex(where: { $0.id == itemId }) {
            selectedItems[index].scale = newScale
        }
    }

    private func deleteSelectedItem() {
        guard let itemId = selectedItemId else { return }
        selectedItems.removeAll { $0.id == itemId }
        selectedItemId = nil
    }

    private func autoArrangeItems() {
        let itemWidth: CGFloat = 100
        let itemHeight: CGFloat = 100
        let spacing: CGFloat = 20

        for (index, _) in selectedItems.enumerated() {
            let row = CGFloat(index / 3)
            let col = CGFloat(index % 3)

            let x = spacing + col * (itemWidth + spacing) + itemWidth / 2
            let y = spacing + row * (itemHeight + spacing) + itemHeight / 2

            selectedItems[index].position = CGPoint(x: x, y: y)
        }
    }

    private func loadLists() {
        guard let userId = authManager.user?.uid else { return }
        let db = Firestore.firestore()

        db.collection("users").document(userId).collection("lists")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Error loading lists: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                self.lists = documents.compactMap { doc in
                    let data = doc.data()
                    return OutfitList(
                        id: doc.documentID,
                        name: data["name"] as? String ?? ""
                    )
                }
            }
    }

    private func saveOutfit() {
        guard let userId = authManager.user?.uid else {
            print("❌ User not logged in")
            return
        }

        guard selectedItems.count >= 2 else {
            alertMessage = "يجب أن تحتوي الإطلالة على قطعتين على الأقل."
            showAlert = true
            DitharVoiceAssistant.shared.speak(alertMessage)
            return
        }

        let db = Firestore.firestore()
        let outfitId = UUID().uuidString

        var outfit = Outfit(
            id: outfitId,
            userId: userId,
            items: selectedItems,
            listName: selectedListName.isEmpty ? nil : selectedListName,
            createdAt: Date()
        )
        outfit.listId = selectedListId

        do {
            let encoder = Firestore.Encoder()
            let outfitData = try encoder.encode(outfit)

            db.collection("outfits").document(outfitId).setData(outfitData) { error in
                if let error = error {
                    print("❌ Error saving outfit: \(error.localizedDescription)")
                    DitharVoiceAssistant.shared.speak("حدث خطأ أثناء حفظ الإطلالة.")
                } else {
                    print("✅ Outfit saved successfully!")
                    DitharVoiceAssistant.shared.announceScreenChange("تم حفظ الإطلالة بنجاح.")
                    presentationMode.wrappedValue.dismiss()
                }
            }
        } catch {
            print("❌ Error encoding outfit: \(error.localizedDescription)")
            DitharVoiceAssistant.shared.speak("تعذر حفظ الإطلالة بسبب خطأ غير متوقع.")
        }
    }
}

// MARK: - DraggableItemView
struct DraggableItemView: View {
    let item: OutfitItem
    let canvasSize: CGSize
    let isSelected: Bool
    let onTap: () -> Void
    let onPositionChange: (CGPoint) -> Void
    let onScaleChange: (CGFloat) -> Void

    @State private var currentPosition: CGPoint
    @State private var currentScale: CGFloat
    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var magnificationAmount: CGFloat = 1.0

    init(
        item: OutfitItem,
        canvasSize: CGSize,
        isSelected: Bool,
        onTap: @escaping () -> Void,
        onPositionChange: @escaping (CGPoint) -> Void,
        onScaleChange: @escaping (CGFloat) -> Void
    ) {
        self.item = item
        self.canvasSize = canvasSize
        self.isSelected = isSelected
        self.onTap = onTap
        self.onPositionChange = onPositionChange
        self.onScaleChange = onScaleChange

        _currentPosition = State(initialValue: item.position)
        _currentScale = State(initialValue: item.scale)
    }

    private var accessibilityLabelText: String {
        let category = item.category.trimmingCharacters(in: .whitespacesAndNewlines)
        let color = (item.color ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if !category.isEmpty && !color.isEmpty {
            return "\(category) \(color)"
        } else if !category.isEmpty {
            return category
        } else if !color.isEmpty {
            return color
        } else {
            return "قطعة ملابس"
        }
    }

    private var accessibilityValueText: String {
        isSelected ? "محدد" : "غير محدد"
    }

    var body: some View {
        VStack {
            if let urlString = item.localImageURLString {
                AsyncImage(url: URL(string: urlString)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .background(Color.clear)
                    case .failure(_):
                        placeholderImage
                    case .empty:
                        ProgressView()
                    @unknown default:
                        placeholderImage
                    }
                }
                .accessibilityHidden(true)
            } else {
                placeholderImage
            }
        }
        .frame(
            width: item.size.width * currentScale * magnificationAmount,
            height: item.size.height * currentScale * magnificationAmount
        )
        .background(Color.clear)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isSelected
                    ? Color(red: 0.47, green: 0.58, blue: 0.44)
                    : Color.gray.opacity(0.3),
                    lineWidth: isSelected ? 3 : 1
                )
        )
        .shadow(radius: isSelected ? 5 : 3)
        .position(
            x: currentPosition.x + dragOffset.width,
            y: currentPosition.y + dragOffset.height
        )
        .onTapGesture {
            onTap()
        }
        .gesture(
            SimultaneousGesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = CGSize(
                            width: -value.translation.width,
                            height: value.translation.height
                        )
                    }
                    .onEnded { value in
                        let translationX = -value.translation.width
                        let translationY = value.translation.height

                        let currentItemWidth = item.size.width * currentScale
                        let currentItemHeight = item.size.height * currentScale

                        let newX = max(
                            currentItemWidth / 2,
                            min(
                                canvasSize.width - currentItemWidth / 2,
                                currentPosition.x + translationX
                            )
                        )
                        let newY = max(
                            currentItemHeight / 2,
                            min(
                                canvasSize.height - currentItemHeight / 2,
                                currentPosition.y + translationY
                            )
                        )

                        currentPosition = CGPoint(x: newX, y: newY)
                        onPositionChange(currentPosition)
                    },

                MagnificationGesture()
                    .updating($magnificationAmount) { value, state, _ in
                        state = value
                    }
                    .onEnded { value in
                        let newScale = max(0.5, min(3.0, currentScale * value))

                        let newEffectiveWidth = item.size.width * newScale
                        let newEffectiveHeight = item.size.height * newScale

                        var adjustedX = currentPosition.x
                        var adjustedY = currentPosition.y

                        if newEffectiveWidth > canvasSize.width {
                            adjustedX = canvasSize.width / 2
                        } else {
                            adjustedX = max(
                                newEffectiveWidth / 2,
                                min(
                                    canvasSize.width - newEffectiveWidth / 2,
                                    currentPosition.x
                                )
                            )
                        }

                        if newEffectiveHeight > canvasSize.height {
                            adjustedY = canvasSize.height / 2
                        } else {
                            adjustedY = max(
                                newEffectiveHeight / 2,
                                min(
                                    canvasSize.height - newEffectiveHeight / 2,
                                    currentPosition.y
                                )
                            )
                        }

                        currentScale = newScale
                        currentPosition = CGPoint(x: adjustedX, y: adjustedY)

                        onScaleChange(newScale)
                        onPositionChange(currentPosition)
                    }
            )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityValue(accessibilityValueText)
        .accessibilityHint("عنصر يمكن سحبه وتكبيره داخل الإطار.")
        .accessibilityAddTraits(.isButton)
    }

    private var placeholderImage: some View {
        Image(systemName: "tshirt")
            .resizable()
            .scaledToFit()
            .foregroundColor(.gray)
            .accessibilityHidden(true)
    }
}

// MARK: - SelectItemsSheetView
struct SelectItemsSheetView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthenticationManager

    @Binding var selectedItems: [OutfitItem]
    let canvasSize: CGSize

    @State private var clothingItems: [ClothingItem] = []
    @State private var tempSelectedIds: Set<String> = []
    @State private var selectedCategory = "الكل"
    @State private var selectedColor: String? = nil
    @State private var isLoading = true

    // ✅ ألوان موحّدة
    private let lightGreenButton = Color(red: 0.91, green: 0.93, blue: 0.88)
    private let darkGreenIcon = Color(red: 0.35, green: 0.45, blue: 0.32)
    private let mainGreen = Color(red: 0.47, green: 0.58, blue: 0.44)

    private var addButtonAccessibilityLabel: String {
        let count = tempSelectedIds.count
        switch count {
        case 0: return "إضافة صفر قطع"
        case 1: return "إضافة قطعة واحدة"
        case 2: return "إضافة قطعتين"
        default:
            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: "ar")
            formatter.numberStyle = .spellOut
            let countWord = formatter.string(from: NSNumber(value: count)) ?? "\(count)"
            return "إضافة \(countWord) قطع"
        }
    }

    // قائمة الألوان الكاملة
    let basicColors: [(String, Color)] = [
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

    let categoryMapping: [String: [String]] = [
        "قطع علوية": ["قميص", "بلوزة", "كنزة", "معطف", "تيشيرت"],
        "قطع سفلية": ["بنطال", "تنورة", "شورت", "شيال"],
        "قطع كاملة": ["فستان", "شيال", "ثوب", "عباية"],
        "أحذية": ["حذاء رياضي", "حذاء رسمي", "صندل", "كعب", "بوت"],
        "إكسسوارات": ["سلسال", "اسورة", "حلق", "خاتم", "ساعة", "نظارة", "حقيبة", "حزام", "قبعة", "وشاح"]
    ]

    var filteredItems: [ClothingItem] {
        clothingItems.filter { item in
            var matchesCategory = false
            if selectedCategory == "الكل" {
                matchesCategory = true
            } else if let subcategories = categoryMapping[selectedCategory] {
                matchesCategory = subcategories.contains(item.category)
            }

            let matchesColor = selectedColor == nil || item.color == selectedColor
            return matchesCategory && matchesColor
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // MARK: - Header
                HStack {
                    Spacer()

                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(darkGreenIcon)
                            .frame(width: 34, height: 34)
                            .background(lightGreenButton)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.10), radius: 5, x: 0, y: 2)
                    }
                    .accessibilityLabel("إغلاق شاشة اختيار القطع")
                }
                .padding()

                Text("إختر القطع")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 18)
                    .accessibilityAddTraits(.isHeader)

                // MARK: - ✅ فلتر الفئات (أيقونات مثل صفحة الواردروب)
                // MARK: - Filters Container (Categories + Colors) ✅ نفس الخلفية بدون فاصل
                VStack(spacing: 10) {

                    // ✅ فلتر الفئات (أيقونات)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 18) {
                            SmallCategoryIconButton(
                                icon: "square.grid.2x2",
                                imageName: nil,
                                label: "الكل",
                                isSelected: selectedCategory == "الكل",
                                lightGreen: lightGreenButton,
                                darkGreen: darkGreenIcon
                            ) {
                                selectedCategory = "الكل"
                                DitharVoiceAssistant.shared.speak("عرض جميع الفئات.")
                            }

                            SmallCategoryIconButton(icon: nil, imageName: "icons8-clothes-64",
                                                    label: "قطع علوية",
                                                    isSelected: selectedCategory == "قطع علوية",
                                                    lightGreen: lightGreenButton, darkGreen: darkGreenIcon) {
                                selectedCategory = "قطع علوية"
                                DitharVoiceAssistant.shared.speak("عرض قطع علوية فقط.")
                            }

                            SmallCategoryIconButton(icon: nil, imageName: "icons8-trousers-64",
                                                    label: "قطع سفلية",
                                                    isSelected: selectedCategory == "قطع سفلية",
                                                    lightGreen: lightGreenButton, darkGreen: darkGreenIcon) {
                                selectedCategory = "قطع سفلية"
                                DitharVoiceAssistant.shared.speak("عرض قطع سفلية فقط.")
                            }

                            SmallCategoryIconButton(icon: nil, imageName: "icons8-slip-dress-64",
                                                    label: "قطع كاملة",
                                                    isSelected: selectedCategory == "قطع كاملة",
                                                    lightGreen: lightGreenButton, darkGreen: darkGreenIcon) {
                                selectedCategory = "قطع كاملة"
                                DitharVoiceAssistant.shared.speak("عرض القطع الكاملة فقط.")
                            }

                            SmallCategoryIconButton(icon: nil, imageName: "icons8-trainers-64",
                                                    label: "أحذية",
                                                    isSelected: selectedCategory == "أحذية",
                                                    lightGreen: lightGreenButton, darkGreen: darkGreenIcon) {
                                selectedCategory = "أحذية"
                                DitharVoiceAssistant.shared.speak("عرض الأحذية فقط.")
                            }

                            SmallCategoryIconButton(icon: nil, imageName: "icons8-bag-64",
                                                    label: "إكسسوارات",
                                                    isSelected: selectedCategory == "إكسسوارات",
                                                    lightGreen: lightGreenButton, darkGreen: darkGreenIcon) {
                                selectedCategory = "إكسسوارات"
                                DitharVoiceAssistant.shared.speak("عرض الإكسسوارات فقط.")
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 6)
                    }

                    // ✅ فلتر الألوان (بدون ظل)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {

                            Button(action: {
                                selectedColor = nil
                                DitharVoiceAssistant.shared.speak("تم اختيار كل الألوان.")
                            }) {
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
                                Button(action: {
                                    selectedColor = colorName
                                    DitharVoiceAssistant.shared.speak("تم اختيار لون \(colorName).")
                                }) {
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
                .padding(.bottom, 10) // بدل 18 عشان ما يعطي فراغ أبيض كبير
                .background(Color.white) // أو لو تبين نفس خلفية الصفحة حطيها هنا

                // MARK: - عرض القطع
                if isLoading {
                    ProgressView().padding()
                } else if filteredItems.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "tshirt.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray.opacity(0.5))
                            .accessibilityHidden(true)
                        Text("لا توجد قطع")
                            .foregroundColor(.gray)
                    }
                    .frame(maxHeight: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("لا توجد قطع مطابقة للفلاتر الحالية.")
                } else {
                    GeometryReader { geo in
                        let horizontalPadding: CGFloat = 20
                        let interItem: CGFloat = 12
                        let side = (geo.size.width - (horizontalPadding * 2) - interItem) / 2

                        ScrollView {
                            LazyVGrid(columns: [
                                GridItem(.fixed(side), spacing: interItem),
                                GridItem(.fixed(side), spacing: interItem)
                            ], spacing: interItem) {
                                ForEach(filteredItems) { item in
                                    ItemSelectionCardWardrobe(
                                        item: item,
                                        side: side,
                                        isSelected: tempSelectedIds.contains(item.id)
                                    ) {
                                        toggleSelection(item: item)
                                    }
                                }
                            }
                            .padding(.horizontal, horizontalPadding)
                        }
                    }
                }

                // MARK: - زر الإضافة
                Button(action: {
                    addSelectedItems()
                }) {
                    Text("إضافة (\(tempSelectedIds.count))")
                        .font(.headline)
                        .foregroundColor(tempSelectedIds.isEmpty ? .gray : .white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(tempSelectedIds.isEmpty ? lightGreenButton : mainGreen)
                        .cornerRadius(15)
                }
                .disabled(tempSelectedIds.isEmpty)
                .padding()
                .accessibilityLabel(addButtonAccessibilityLabel)
                .accessibilityHint("إضافة القطع المحددة إلى الإطار في شاشة تنسيق الإطلالة.")
            }
            .navigationBarHidden(true)
            .onAppear {
                loadClothingItems()
                DitharVoiceAssistant.shared.announceScreenChange(
                    "شاشة اختيار قطع الإطلالة. استخدمي فلاتر الفئة واللون، ثم حددي القطع التي ترغبين بإضافتها."
                )
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: - Functions
    private func toggleSelection(item: ClothingItem) {
        let mainDesc: String = {
            if let color = item.color, !color.isEmpty { return "\(item.category) \(color)" }
            return item.category
        }()

        if tempSelectedIds.contains(item.id) {
            tempSelectedIds.remove(item.id)
            DitharVoiceAssistant.shared.speak("تم إلغاء اختيار \(mainDesc).")
        } else {
            tempSelectedIds.insert(item.id)
            DitharVoiceAssistant.shared.speak("تم اختيار \(mainDesc) للإطلالة.")
        }
    }

    private func arabicListWithDetails(from items: [OutfitItem]) -> String {
        let descriptions = items.map { item in
            if let color = item.color, !color.isEmpty {
                return "\(item.category) \(color)"
            } else {
                return item.category
            }
        }

        switch descriptions.count {
        case 0: return ""
        case 1: return descriptions[0]
        case 2: return "\(descriptions[0]) و\(descriptions[1])"
        default:
            let allButLast = descriptions.dropLast().joined(separator: "، ")
            if let last = descriptions.last { return "\(allButLast)، و\(last)" }
            return descriptions.joined(separator: "، ")
        }
    }

    private func addSelectedItems() {
        let newItems = clothingItems
            .filter { tempSelectedIds.contains($0.id) }
            .map { item -> OutfitItem in
                let randomX = CGFloat.random(in: 50...(canvasSize.width - 50))
                let randomY = CGFloat.random(in: 50...(canvasSize.height - 50))

                return OutfitItem(
                    id: UUID().uuidString,
                    clothingItemId: item.id,
                    name: item.name,
                    category: item.category,
                    color: item.color,
                    localImageURLString: item.localImageURLString,
                    position: CGPoint(x: randomX, y: randomY),
                    size: CGSize(width: 80, height: 80)
                )
            }

        let existingItems = selectedItems
        selectedItems.append(contentsOf: newItems)

        let allItems = existingItems + newItems
        let listText = arabicListWithDetails(from: allItems)
        let message = "تم تنسيق إطلالة تحتوي على \(listText). يمكنك حفظ الإطلالة الآن أو تعديل ترتيب القطع داخل الإطار."
        DitharVoiceAssistant.shared.speak(message)

        presentationMode.wrappedValue.dismiss()
    }

    private func loadClothingItems() {
        guard let userId = authManager.user?.uid else {
            print("❌ User not logged in")
            isLoading = false
            return
        }

        let db = Firestore.firestore()
        db.collection("Clothes")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error loading items: \(error.localizedDescription)")
                    isLoading = false
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("⚠️ No documents found")
                    isLoading = false
                    return
                }

                clothingItems = documents.compactMap { doc -> ClothingItem? in
                    let data = doc.data()

                    let name = (data["attrs"] as? [String: Any])?["description"] as? String ?? "بدون اسم"
                    let category = (data["analysis"] as? [String: Any])?["category"] as? String ?? "غير محدد"
                    let color = (data["analysis"] as? [String: Any])?["color"] as? String
                    let isFavorite = (data["meta"] as? [String: Any])?["isFavorite"] as? Bool ?? false
                    let isOutside = (data["meta"] as? [String: Any])?["isOutside"] as? Bool ?? false
                    let imageUrl = (data["image"] as? [String: Any])?["originalUrl"] as? String

                    let occasion = (data["attrs"] as? [String: Any])?["occasion"] as? String
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

                print("✅ Loaded \(clothingItems.count) items")
                isLoading = false
            }
    }
}


// MARK: - ✅ زر فئة بالأيقونات (نفس فكرة SmallCategoryButton في الواردروب)
struct SmallCategoryIconButton: View {
    let icon: String?
    let imageName: String?
    let label: String
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
                Circle()
                    .fill(Color.white)
                    .frame(width: 56, height: 56)
                    .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)

                if let imageName = imageName {
                    Image(isSelected ? "\(imageName)-shadow" : imageName)
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(darkGreen)
                }
            }
            .scaleEffect(isBouncing ? 1.08 : 1.0)
            .offset(y: isBouncing ? -3 : 0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
// MARK: - زر فلتر الفئة
struct CategoryFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .black)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color(red: 0.47, green: 0.58, blue: 0.44) : Color.gray.opacity(0.2))
                .cornerRadius(20)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "محددة حاليًا" : "غير محددة")
        .accessibilityHint("تصفية القطع المعروضة حسب هذه الفئة.")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - كارد اختيار القطعة (نفس تصميم الدولاب) — ✅ بدون حدود + ظل + ظل أخضر عند التحديد
struct ItemSelectionCardWardrobe: View {
    let item: ClothingItem
    let side: CGFloat
    let isSelected: Bool
    let onTap: () -> Void

    private var mainDescription: String {
        if let color = item.color, !color.isEmpty {
            return "\(item.category) \(color)"
        } else {
            return item.category
        }
    }

    private var stateDescription: String {
        var parts: [String] = []

        if item.isOutside { parts.append("خارج الخزانة") }
        if item.isFavorite { parts.append("مفضلة") }

        parts.append(isSelected ? "محددة للإطلالة" : "غير محددة للإطلالة")
        return parts.joined(separator: "، ")
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {

                // ✅ هذا هو “الكارد الأبيض” الحقيقي
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(
                        color: isSelected
                        ? Color(red: 0.47, green: 0.58, blue: 0.44).opacity(0.55)  // (بنعدله تحت ليصير أغمق)
                        : Color.black.opacity(0.14),
                        radius: isSelected ? 16 : 10,
                        x: 0,
                        y: isSelected ? 9 : 6
                    )

                // ✅ الصورة فوق الكارد
                Group {
                    if let urlString = item.localImageURLString,
                       let url = URL(string: urlString) {

                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .scaledToFill()
                            } else if phase.error != nil {
                                Image(systemName: "tshirt")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundColor(.gray.opacity(0.5))
                                    .padding(22)
                            } else {
                                ProgressView()
                            }
                        }
                    } else {
                        Image(systemName: "tshirt")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(22)
                    }
                }
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: 20)) // ✅ قص نفس شكل الكارد

                // ✅ علامة الاختيار
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? Color(red: 0.47, green: 0.58, blue: 0.44) : .gray)
                    .padding(8)
                    .background(Color.white.opacity(0.85))
                    .clipShape(Circle())
                    .accessibilityHidden(true)
            }
            .frame(width: side, height: side)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mainDescription)
        .accessibilityValue(stateDescription)
        .accessibilityHint("اضغطي مرتين لاختيار هذه القطعة أو إلغاء اختيارها للإطلالة.")
        .accessibilityAddTraits(.isButton)
    }

    private var placeholderSquare: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.white)
            .frame(width: side, height: side)
            .overlay(
                Image(systemName: "tshirt")
                    .font(.system(size: 40))
                    .foregroundColor(.gray.opacity(0.5))
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Preview
struct AddOutfitView_Previews: PreviewProvider {
    static var previews: some View {
        AddOutfitView()
            .environmentObject(AuthenticationManager())
            .environment(\.locale, Locale(identifier: "ar"))
            .environment(\.layoutDirection, .rightToLeft)
    }
}
