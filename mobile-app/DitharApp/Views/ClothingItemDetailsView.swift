import SwiftUI
import Firebase
import FirebaseFirestore

// ==== مجموعات الفئات (رئيسية ← عناصر فرعية) ====
struct CategoryGroup: Identifiable {
    let id = UUID()
    let name: String       // اسم الفئة الرئيسية (مثلاً: قطع علوية)
    let items: [String]    // العناصر داخلها (مثلاً: قميص، بلوزة...)
}

let CATEGORY_GROUPS: [CategoryGroup] = [
    CategoryGroup(name: "قطع علوية", items: [
        "قميص", "بلوزة", "كنزة", "معطف", "تيشيرت"
    ]),
    CategoryGroup(name: "قطع سفلية", items: [
        "بنطال", "تنورة", "شورت"
    ]),
    CategoryGroup(name: "قطع كاملة", items: [
        "فستان", "شيال", "ثوب", "عباية"
    ]),
    CategoryGroup(name: "أحذية", items: [
        "حذاء رياضي", "حذاء رسمي", "صندل", "كعب", "بوت"
    ]),
    CategoryGroup(name: "إكسسوارات", items: [
        "سلسال", "اسورة", "حلق", "خاتم", "ساعة",
        "نظارة", "حقيبة", "حزام", "قبعة", "وشاح"
    ])
]

// MARK: - صفحة تفاصيل القطعة
struct ClothingItemDetailsView: View {

    let clothingItemId: String
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.accessibilityManager) private var accessibilityManager

    @State private var name: String = ""
    @State private var category: String = ""
    @State private var color: String = ""
    @State private var pattern: String = ""
    @State private var season: String = ""
    @State private var brand: String = ""
    @State private var size: String = ""
    @State private var itemDescription: String = ""
    @State private var rfidLinked: Bool = false
    @State private var rfidId: String = ""
    @State private var createdAt: Date = Date()
    @State private var itemImage: UIImage? = nil
    @State private var isFavorite: Bool = false
    @State private var isOutside: Bool = false

    @State private var isEditing: Bool = false
    @State private var showDeleteAlert: Bool = false
    @State private var isLoading: Bool = true
    @State private var showRFIDLinking = false

    @State private var editedCategory: String = ""
    @State private var editedColor: String = ""
    @State private var editedPattern: String = ""
    @State private var editedSeason: String = ""
    @State private var editedBrand: String = ""
    @State private var editedSize: String = ""
    @State private var editedDescription: String = ""
    @State private var wearingCount: Int = 0
    @State private var lastWearingDate: Date? = nil

    // تنبيه إلغاء ربط المعرّف
    @State private var showUnlinkRFIDDialog: Bool = false

    // MARK: - BODY
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("جاري التحميل...")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("جاري تحميل تفاصيل القطعة")
            } else if name.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                        .accessibilityHidden(true)
                    Text("لم يتم العثور على القطعة")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("لم يتم العثور على القطعة")
            } else {
                ScrollView {
                    VStack(spacing: 0) {

                        // MARK: - صورة القطعة
                        if let image = itemImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 220)
                                .clipped()
                                .accessibilityLabel("صورة القطعة من نوع \(category.isEmpty ? "غير محدد" : category)")
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    speakElement("صورة القطعة")
                                }
                        } else {
                            Rectangle()
                                .fill(Color(red: 0.95, green: 0.95, blue: 0.95))
                                .frame(height: 220)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 50))
                                        .foregroundColor(.gray.opacity(0.5))
                                        .accessibilityHidden(true)
                                )
                                .accessibilityLabel("لا توجد صورة لهذه القطعة")
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    speakElement("لا توجد صورة لهذه القطعة")
                                }
                        }

                        // MARK: - بطاقة التفاصيل
                        VStack(alignment: .trailing, spacing: 16) {
                            Text("تفاصيل القطعة")
                                .font(.system(size: 18, weight: .bold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityAddTraits(.isHeader)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    speakElement("تفاصيل القطعة")
                                }

                            // حالة وربط/إلغاء ربط RFID
                            if !rfidLinked {
                                VStack(alignment: .trailing, spacing: 6) {
                                    Text("")
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            speakElement("القطعة غير مرتبطة بأي معرّف")
                                        }

                                    Button(action: {
                                        speakElement("ربط القطعة بالمعرّف")
                                        showRFIDLinking = true
                                    }) {
                                        HStack(spacing: 6) {
                                            Text("اربطها بالمعرف")
                                            Image(systemName: "tag")
                                                .accessibilityHidden(true)
                                        }
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color(red: 0.47, green: 0.58, blue: 0.44))
                                        .cornerRadius(16)
                                    }
                                    .accessibilityLabel(" ربط القطعة بمعرّف ")
                                    .accessibilityHint("فتح صفحة ربط المعرف لهذه القطعة")
                                }
                            } else {
                                Button(action: {
                                    showUnlinkRFIDDialog = true
                                    speakElement("إلغاء ربط المعرّف")
                                }) {
                                    HStack(spacing: 6) {
                                        Text("إلغاء ربط المعرّف")
                                        Image(systemName: "tag.slash")
                                            .accessibilityHidden(true)
                                    }
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color(red: 1.0, green: 0.93, blue: 0.93))
                                    .cornerRadius(16)
                                }
                                .accessibilityLabel("إلغاء ربط المعرّف")
                                .accessibilityHint("سيتم إزالة ربط المعرّف عن هذه القطعة بعد التأكيد")
                            }

                            // حقول التفاصيل
                            VStack(spacing: 12) {
                                if isEditing {
                                    ClothingItemEditingFieldRow(
                                        title: "النوع",
                                        value: $editedCategory,
                                        options: [],
                                        groups: CATEGORY_GROUPS
                                    )
                                    ClothingItemEditingFieldRow(
                                        title: "اللون",
                                        value: $editedColor,
                                        options: [
                                            "أبيض", "أسود", "رمادي", "بني", "بيج",
                                            "أحمر", "وردي", "بنفسجي", "برتقالي", "أصفر",
                                            "أخضر", "سماوي", "أزرق", "ذهبي", "فضي"
                                        ]
                                    )
                                    ClothingItemEditingFieldRow(
                                        title: "النقش",
                                        value: $editedPattern,
                                        options: [
                                            "سادة", "مخطط", "مورد", "مربعات", "كاروهات",
                                            "منقط", "اشكال هندسية", "دانتيل"
                                        ]
                                    )
                                    ClothingItemEditingFieldRow(
                                        title: "الموسم",
                                        value: $editedSeason,
                                        options: ["شتاء", "صيف", "ربيع", "خريف", "كل المواسم"]
                                    )

                                    HStack {
                                        Text("الماركة")
                                            .font(.system(size: 14, weight: .medium))
                                        Spacer()
                                        TextField("أدخل اسم الماركة", text: $editedBrand)
                                            .multilineTextAlignment(.leading)
                                            .textFieldStyle(.plain)
                                    }
                                    .padding(.vertical, 4)

                                    ClothingItemEditingFieldRow(
                                        title: "المقاس",
                                        value: $editedSize,
                                        options: ["XS", "S", "M", "L", "XL", "XXL"]
                                    )

                                    VStack(alignment: .trailing, spacing: 8) {
                                        Text("وصف القطعة")
                                            .font(.system(size: 14, weight: .medium))
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        TextEditor(text: $editedDescription)
                                            .frame(height: 80)
                                            .padding(8)
                                            .background(Color(red: 0.96, green: 0.96, blue: 0.96))
                                            .cornerRadius(8)
                                            .accessibilityLabel("وصف القطعة")
                                    }
                                } else {
                                    ClothingItemDetailRow(title: "النوع",   value: category)
                                    ClothingItemDetailRow(title: "اللون",   value: color)
                                    ClothingItemDetailRow(title: "النقش",  value: pattern)
                                    ClothingItemDetailRow(title: "الموسم",  value: season)
                                    ClothingItemDetailRow(title: "الماركة", value: brand)
                                    ClothingItemDetailRow(title: "المقاس",  value: size)

                                    if !itemDescription.isEmpty {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("وصف القطعة")
                                                .font(.system(size: 14, weight: .medium))
                                            Text(itemDescription)
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                                .multilineTextAlignment(.leading)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .accessibilityElement(children: .combine)
                                        .accessibilityLabel("وصف القطعة: \(itemDescription)")
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            speakElement("وصف القطعة: \(itemDescription)")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(red: 0.91, green: 0.90, blue: 0.89), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                        // MARK: - سجل الاستخدام
                        VStack(alignment: .trailing, spacing: 16) {
                            Text("سجل الاستخدام")
                                .font(.system(size: 18, weight: .bold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityAddTraits(.isHeader)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    speakElement("سجل الاستخدام")
                                }

                            VStack(spacing: 16) {
                                // تاريخ الإضافة
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(Color(red: 0.47, green: 0.58, blue: 0.44))
                                        .accessibilityHidden(true)
                                    Text("تاريخ الإضافة")
                                        .font(.system(size: 14, weight: .medium))
                                    Spacer()
                                    Text(createdAt.formatted(date: .abbreviated, time: .omitted))
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("تاريخ الإضافة")
                                .accessibilityValue(createdAt.formatted(date: .abbreviated, time: .omitted))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    let fullDate = createdAt.formatted(date: .complete, time: .omitted)
                                    speakElement("تاريخ الإضافة: \(fullDate)")
                                }

                                // تاريخ آخر لبس
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundColor(Color(red: 0.47, green: 0.58, blue: 0.44))
                                        .accessibilityHidden(true)
                                    Text("تاريخ آخر لبس")
                                        .font(.system(size: 14, weight: .medium))
                                    Spacer()
                                    Text(lastWearingText)
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("تاريخ آخر لبس")
                                .accessibilityValue(lastWearingAccessibilityText)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    speakElement("تاريخ آخر لبس: \(lastWearingAccessibilityText)")
                                }

                                // عدد مرات اللبس
                                HStack {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .foregroundColor(Color(red: 0.47, green: 0.58, blue: 0.44))
                                        .accessibilityHidden(true)
                                    Text("عدد مرات اللبس")
                                        .font(.system(size: 14, weight: .medium))
                                    Spacer()
                                    Text(wearingCountText)
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("عدد مرات اللبس")
                                .accessibilityValue(wearingCountAccessibilityText)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    speakElement("عدد مرات اللبس: \(wearingCountAccessibilityText)")
                                }

                            }
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(red: 0.91, green: 0.90, blue: 0.89), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 30)

                        Spacer().frame(height: 50)
                    }
                }
            }
        }
        // ==== هنا كل الموديفايرز الخارجية لـ body ====
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {

            // زر الرجوع (يمين دائمًا)
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                    speakElement("رجوع")
                }) {
                    Image(systemName: "arrow.right")
                        .foregroundColor(.black)
                }
                .accessibilityLabel("رجوع")
                .accessibilityHint("العودة إلى الشاشة السابقة")
            }

            // كل الأزرار في Trailing Group واحد
            ToolbarItemGroup(placement: .navigationBarTrailing) {

                // 1) زر الحذف ← أول واحد عشان يطيح أقصى اليسار
                Button {
                    showDeleteAlert = true
                    speakElement("زر حذف القطعة")
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                        .frame(width: 36, height: 36)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .accessibilityLabel("حذف القطعة")
                .accessibilityHint("سيتم حذف القطعة وجميع الإطلالات المرتبطة بها")

                // 2) أزرار التعديل أو الحفظ/الإلغاء
                if isEditing {

                    Button {
                        isEditing = false
                        speakElement("تم إلغاء التعديلات")
                    } label: {
                        Text("إلغاء")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.96, green: 0.96, blue: 0.96))
                            .cornerRadius(8)
                    }
                    .accessibilityLabel("إلغاء التعديلات")

                    Button {
                        category = editedCategory
                        color = editedColor
                        pattern = editedPattern
                        season = editedSeason
                        brand = editedBrand
                        size = editedSize
                        itemDescription = editedDescription
                        saveChanges()
                        isEditing = false
                        speakElement("تم حفظ التعديلات")
                    } label: {
                        HStack(spacing: 6) {
                            Text("حفظ").font(.system(size: 14, weight: .semibold))
                            Image(systemName: "checkmark")
                                .accessibilityHidden(true)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.47, green: 0.58, blue: 0.44))
                        .cornerRadius(8)
                    }
                    .accessibilityLabel("حفظ التعديلات")

                } else {

                    Button {
                        editedCategory = category
                        editedColor = color
                        editedPattern = pattern
                        editedSeason = season
                        editedBrand = brand
                        editedSize = size
                        editedDescription = itemDescription
                        isEditing = true
                        speakElement("تعديل بيانات القطعة")
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "pencil")
                                .font(.system(size: 18))
                            Text("تعديل")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(Color(red: 0.47, green: 0.58, blue: 0.44))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.47, green: 0.58, blue: 0.44).opacity(0.1))
                        .cornerRadius(10)
                    }
                    .accessibilityLabel("تعديل بيانات القطعة")
                }
            }
        }
        // تنبيه حذف القطعة
        .alert("حذف القطعة", isPresented: $showDeleteAlert) {
            Button("إلغاء", role: .cancel) { }
            Button("حذف", role: .destructive) {
                deleteItem()
            }
        } message: {
            Text("سيتم حذف جميع الإطلالات المرتبطة بهذه القطعة. هل ترغب بمتابعة الحذف؟")
        }
        // تنبيه تأكيد إلغاء ربط المعرّف
        .confirmationDialog(
            "إلغاء ربط المعرف",
            isPresented: $showUnlinkRFIDDialog,
            titleVisibility: .visible
        ) {
            Button("إلغاء ربط المعرّف", role: .destructive) {
                unlinkRFID()
            }
            Button("تراجع", role: .cancel) { }
        } message: {
            Text("هل أنت متأكد من إلغاء ربط المعرف بهذه القطعة؟")
        }
        // تحميل بيانات القطعة في أول فتح
        .onAppear {
            loadItemData()
        }
    }

    // MARK: - تنسيقات سجل الاستخدام
    private var lastWearingText: String {
        guard let date = lastWearingDate else {
            return "لم تُلبس بعد"
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private var lastWearingAccessibilityText: String {
        guard let date = lastWearingDate else {
            return "لم تُلبس بعد"
        }
        return date.formatted(date: .complete, time: .omitted)
    }

    private var wearingCountText: String {
        String(wearingCount)
    }

    private var wearingCountAccessibilityText: String {
        let c = wearingCount
        switch c {
        case 0:
            return "صفر مرة"
        case 1:
            return "مرة واحدة"
        case 2:
            return "مرتين"
        default:
            return "\(c) مرات"
        }
    }

    // MARK: - نطق عنصر واحد (يعتمد على الإعدادات)
    private func speakElement(_ text: String) {
        let assistant = DitharVoiceAssistant.shared
        guard assistant.canUseAVSpeech else { return }
        assistant.speak(text)
    }

    // MARK: - إلغاء ربط المعرّف
    private func unlinkRFID() {
        let db = Firestore.firestore()
        db.collection("Clothes").document(clothingItemId)
            .updateData(["meta.epc": NSNull()]) { error in
                if let error = error {
                    print("❌ فشل إلغاء ربط المعرف:", error.localizedDescription)
                } else {
                    print("✅ تم إلغاء ربط المعرف بنجاح.")
                    rfidLinked = false
                    rfidId = ""
                    speakElement("تم إلغاء ربط المعرف بهذه القطعة")
                }
            }
    }

    // MARK: - تحميل بيانات القطعة من Firebase
    private func loadItemData() {
        guard let userId = authManager.user?.uid else {
            print("❌ User not logged in")
            isLoading = false
            return
        }

        let db = Firestore.firestore()
        db.collection("Clothes").document(clothingItemId).getDocument { snapshot, error in
            if let error = error {
                print("❌ خطأ في تحميل القطعة:", error.localizedDescription)
                isLoading = false
                return
            }

            guard let data = snapshot?.data() else {
                print("❌ القطعة غير موجودة")
                isLoading = false
                return
            }

            let itemUserId = data["userId"] as? String ?? ""
            if itemUserId != userId {
                print("❌ القطعة لا تخص المستخدم الحالي")
                isLoading = false
                return
            }

            let analysisData = data["analysis"] as? [String: Any] ?? [:]
            let attrsData = data["attrs"] as? [String: Any] ?? [:]
            let metaData = data["meta"] as? [String: Any] ?? [:]
            let imageData = data["image"] as? [String: Any] ?? [:]

            name = attrsData["description"] as? String ?? "بدون اسم"
            category = analysisData["category"] as? String ?? "غير محدد"
            color = analysisData["color"] as? String ?? ""
            pattern = analysisData["pattern"] as? String ?? ""
            season = attrsData["season"] as? String ?? ""
            brand = attrsData["brand"] as? String ?? ""
            size = attrsData["size"] as? String ?? ""
            itemDescription = attrsData["description"] as? String ?? ""

            isFavorite = metaData["isFavorite"] as? Bool ?? false
            isOutside = metaData["isOutside"] as? Bool ?? false
            rfidLinked = (metaData["epc"] as? String) != nil
            rfidId = metaData["epc"] as? String ?? ""
            createdAt = (metaData["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            wearingCount = metaData["wearingCount"] as? Int ?? 0
            if let ts = metaData["lastWearingDate"] as? Timestamp {
                lastWearingDate = ts.dateValue()
            } else {
                lastWearingDate = nil
            }

            let imageUrl = imageData["originalUrl"] as? String

            if let urlString = imageUrl, let url = URL(string: urlString) {
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            itemImage = image
                        }
                    }
                }.resume()
            }

            isLoading = false
        }
    }

    // MARK: - حفظ التعديلات
    private func saveChanges() {
        let db = Firestore.firestore()
        db.collection("Clothes").document(clothingItemId).setData([
            "analysis": [
                "category": category,
                "color": color,
                "pattern": pattern
            ],
            "attrs": [
                "season": season,
                "brand": brand,
                "size": size,
                "description": itemDescription
            ]
        ], merge: true) { error in
            if let error = error {
                print("❌ خطأ في التحديث:", error.localizedDescription)
            } else {
                print("✅ تم التحديث بنجاح")
            }
        }
    }

    // MARK: - حذف القطعة
    private func deleteItem() {
        let db = Firestore.firestore()
        db.collection("Clothes").document(clothingItemId).delete { error in
            if let error = error {
                print("❌ خطأ في الحذف:", error.localizedDescription)
            } else {
                print("✅ تم الحذف بنجاح")
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

// MARK: - صف التفاصيل
struct ClothingItemDetailRow: View {
    let title: String
    let value: String

    var body: some View {
        let displayText = value.isEmpty ? "-" : value
        let accessibilityValueText = value.isEmpty ? "غير محدد" : value
        let assistant = DitharVoiceAssistant.shared

        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.trailing)
            Spacer(minLength: 0)
            Text(displayText)
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValueText)
        .contentShape(Rectangle())
        .onTapGesture {
            guard assistant.canUseAVSpeech else { return }
            let phrase = "\(title): \(accessibilityValueText)"
            assistant.speak(phrase)
        }
    }
}

// MARK: - صف التعديل
struct ClothingItemEditingFieldRow: View {
    let title: String
    @Binding var value: String
    let options: [String]
    var groups: [CategoryGroup]? = nil

    private let assistant = DitharVoiceAssistant.shared

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))

            Spacer()

            Menu {
                if !value.isEmpty {
                    Button(role: .destructive) {
                        value = ""
                        if assistant.canUseAVSpeech {
                            assistant.speak("تم مسح \(title)")
                        }
                    } label: {
                        Label("مسح \(title)", systemImage: "xmark.circle")
                    }
                }

                if let groups = groups, !groups.isEmpty {
                    ForEach(groups) { group in
                        Menu(group.name) {
                            ForEach(group.items, id: \.self) { item in
                                Button(item) {
                                    value = item
                                    if assistant.canUseAVSpeech {
                                        assistant.speak("\(title): \(item)")
                                    }
                                }
                            }
                        }
                    }
                } else {
                    ForEach(options, id: \.self) { option in
                        Button(option) {
                            value = option
                            if assistant.canUseAVSpeech {
                                assistant.speak("\(title): \(option)")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(value.isEmpty ? "اختر \(title)" : value)
                        .foregroundColor(value.isEmpty ? .gray : .black)
                        .font(.system(size: 14))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
