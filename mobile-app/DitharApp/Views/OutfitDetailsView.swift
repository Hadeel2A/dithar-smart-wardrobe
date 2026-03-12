import SwiftUI
import Firebase
import FirebaseFirestore

// MARK: - صفحة تفاصيل الإطلالة
struct OutfitDetailsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthenticationManager
    
    let outfit: Outfit
    
    @State private var showDeleteAlert = false
    @State private var navigateToEdit = false
    
    // ✅ مرجع للمساعد الصوتي
    private let voiceAssistant = DitharVoiceAssistant.shared
    
    // وصف الإطلالة للفويس أوفر
    private var outfitAccessibilitySummary: String {
        guard !outfit.items.isEmpty else {
            return "إطلالة لا تحتوي على أي قطع"
        }
        
        // نجمع القطع حسب الفئة
        let grouped = Dictionary(grouping: outfit.items, by: { $0.category })
        
        let parts: [String] = grouped.map { (category, items) in
            switch items.count {
            case 1:
                return "قطعة واحدة من فئة \(category)"
            case 2:
                return "قطعتان من فئة \(category)"
            default:
                return "\(items.count) قطع من فئة \(category)"
            }
        }
        
        let details = parts.joined(separator: "، ")
        return "إطلالة تحتوي على \(outfit.items.count) قطعة: \(details)"
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection
                outfitDisplay
                itemsScrollView
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .alert("حذف الإطلالة", isPresented: $showDeleteAlert) {
            Button("إلغاء", role: .cancel) {}
            Button("حذف", role: .destructive) { deleteOutfit() }
        } message: {
            Text("هل أنت متأكد من حذف هذه الإطلالة؟")
        }
        .navigationDestination(isPresented: $navigateToEdit) {
            EditOutfitView(outfit: outfit)
                .environmentObject(authManager)
        }
        .onAppear { announceScreenContent() }
        .environment(\.layoutDirection, .rightToLeft)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack(spacing: 15) {
            // زر الرجوع
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "arrow.right")
                    .font(.title2)
                    .foregroundColor(.black)
            }
            .accessibilityLabel(" الرجوع")
            
            Spacer()
            
            // زر التعديل
            Button(action: {
                navigateToEdit = true
                voiceAssistant.speak("فتح صفحة تعديل الإطلالة")
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .font(.system(size: 18))
                    Text("تعديل")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(Color(red: 0.47, green: 0.58, blue: 0.44))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(red: 0.47, green: 0.58, blue: 0.44).opacity(0.1))
                .cornerRadius(10)
            }
            .accessibilityLabel(" تعديل الإطلالة")
            
            // زر الحذف
            Button(action: {
                showDeleteAlert = true
                voiceAssistant.speak("فتح تأكيد حذف الإطلالة")
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
                    .frame(width: 40, height: 40)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel(" حذف الإطلالة")
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 20)
    }
    
    // MARK: - Outfit Display
    private var outfitDisplay: some View {
        GeometryReader { geo in
            let displayWidth = geo.size.width - 40
            let displayHeight = displayWidth * 1.3
            
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                
                GeometryReader { canvasGeo in
                    let scaleX = canvasGeo.size.width / 350
                    let scaleY = canvasGeo.size.height / 400
                    
                    ForEach(outfit.items) { item in
                        if let urlString = item.localImageURLString,
                           let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                case .failure(_):
                                    placeholderImage
                                case .empty:
                                    ProgressView()
                                @unknown default:
                                    placeholderImage
                                }
                            }
                            .frame(
                                width: item.size.width * item.scale * scaleX,
                                height: item.size.height * item.scale * scaleY
                            )
                            .position(
                                x: item.position.x * scaleX,
                                y: item.position.y * scaleY
                            )
                            .accessibilityHidden(true)
                        }
                    }
                }
            }
            .frame(width: displayWidth, height: displayHeight)
            .frame(maxWidth: .infinity)
        }
        .frame(height: UIScreen.main.bounds.width * 1.1)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .accessibilityHidden(true)   // 👈 يخفي الكانفس عن الفويس أوفر تمامًا
    }
    
    // MARK: - Items Scroll View
    private var itemsScrollView: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Text("القطع المستخدمة")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .accessibilityAddTraits(.isHeader)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(outfit.items) { item in
                        NavigationLink {
                            ClothingItemDetailsView(clothingItemId: item.clothingItemId)
                                .environmentObject(authManager)
                        } label: {
                            itemThumbnail(item)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.category.isEmpty ? "قطعة ملابس" : item.category)
                        .accessibilityHint("اضغطي مرتين لعرض تفاصيل \(item.category.isEmpty ? "هذه القطعة" : "قطعة \(item.category)")")
                    }
                }
                .padding(.horizontal, 20)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("قائمة القطع المستخدمة في الإطلالة")
            .accessibilityHint("مرر لليسار أو اليمين للتنقل بين القطع")
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - Item Thumbnail
    private func itemThumbnail(_ item: OutfitItem) -> some View {
        ZStack {
            if let urlString = item.localImageURLString,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure(_):
                        placeholderImage
                    case .empty:
                        ProgressView()
                    @unknown default:
                        placeholderImage
                    }
                }
            } else {
                placeholderImage
            }
        }
        .frame(width: 100, height: 100)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .accessibilityHidden(true)
    }

    // MARK: - Placeholder Image
    private var placeholderImage: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .accessibilityHidden(true)
    }
    
    // MARK: - Delete Outfit
    private func deleteOutfit() {
        let db = Firestore.firestore()
        
        db.collection("outfits").document(outfit.id).delete { error in
            if let error = error {
                print("❌ Error deleting outfit: \(error.localizedDescription)")
                voiceAssistant.speakError("فشل حذف الإطلالة")
            } else {
                print("✅ Outfit deleted successfully")
                voiceAssistant.speakSuccess("تم حذف الإطلالة")
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    // إعلان محتوى الشاشة
    private func announceScreenContent() {
        let itemCount = outfit.items.count
        let message: String
        
        if itemCount == 1 {
            message = "صفحة تفاصيل الإطلالة، تحتوي على قطعة واحدة"
        } else if itemCount == 2 {
            message = "صفحة تفاصيل الإطلالة، تحتوي على قطعتين"
        } else {
            message = "صفحة تفاصيل الإطلالة، تحتوي على \(itemCount) قطع"
        }
        
        voiceAssistant.announceScreenChange(message)
    }
}

// MARK: - Edit Outfit View
struct EditOutfitView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthenticationManager
    
    let outfit: Outfit
    
    @State private var selectedItems: [OutfitItem] = []
    @State private var showingAddItemSheet = false
    @State private var selectedListName: String = ""
    @State private var selectedListId: String? = nil
    @State private var showListPicker = false   // لو حبيتي تستخدمين dialog لاحقاً
    @State private var selectedItemId: String? = nil
    @State private var lists: [OutfitList] = []
    @State private var showManageLists = false
    
    // مساعد صوتي
    private let voiceAssistant = DitharVoiceAssistant.shared
    
    let canvasSize: CGSize = CGSize(width: 350, height: 400)
    
    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            
            VStack(spacing: 20) {
                header
                listsFilterBar       // 👈 شريط القوائم الجديد
                canvasSection
                actionButtons
                saveButton
                Spacer()
            }
            .padding(.bottom, 80)
        }
        .navigationBarHidden(true)
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
        .onAppear {
            loadOutfitData()
            loadLists()
            announceEditScreen()
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
    
    // MARK: - Header
    private var header: some View {
        HStack {
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "arrow.right")
                    .font(.title2)
                    .foregroundColor(.black)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("رجوع")
            .accessibilityHint("عودة بدون حفظ التعديلات")
            
            Spacer()
            
            Text("تعديل الإطلالة")
                .font(.headline)
                .fontWeight(.bold)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("عنوان الشاشة: تعديل الإطلالة")
                .accessibilityAddTraits(.isHeader)
            
            Spacer()
            
            Color.clear.frame(width: 30)
                .accessibilityHidden(true)
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
    
    // MARK: - شريط القوائم (مثل AddOutfitView)
    private var listsFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // زر إدارة القوائم
                Button(action: {
                    voiceAssistant.speak("إدارة القوائم. يمكنك إنشاء قوائم لحفظ الإطلالات وتنظيمها حسب المناسبات.")
                    showManageLists = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(Color(red: 0.33, green: 0.33, blue: 0.33))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.93, green: 0.93, blue: 0.93))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("إدارة القوائم")
                .accessibilityHint("فتح شاشة إدارة القوائم")
                
                // فاصل
                Divider()
                    .frame(height: 24)
                    .overlay(Color.gray.opacity(0.3))
                    .accessibilityHidden(true)
                
                // زر الكل
                OutfitListFilterPill(title: "الكل", isSelected: selectedListId == nil) {
                    selectedListId = nil
                    selectedListName = ""
                    voiceAssistant.speak("تم اختيار الكل، لن يتم ربط الإطلالة بقائمة معينة.")
                }
                
                // القوائم المحفوظة
                ForEach(lists) { list in
                    OutfitListFilterPill(title: list.name, isSelected: selectedListId == list.id) {
                        selectedListId = list.id
                        selectedListName = list.name
                        voiceAssistant.speak("تم اختيار قائمة \(list.name)")
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 10)
    }
    
    // MARK: - الكانفس
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
                    
                    Text("اضغط على + لإضافة قطع")
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
                            voiceAssistant.speak("تم تحديد قطعة من فئة \(item.category)")
                        },
                        onPositionChange: { newPosition in
                            updateItemPosition(itemId: item.id, newPosition: newPosition)
                        },
                        onScaleChange: { newScale in
                            updateItemScale(itemId: item.id, newScale: newScale)
                        }
                    )
                    .accessibilityHidden(true)
                }
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .padding(.horizontal)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            selectedItems.isEmpty
            ? "منطقة عرض الإطلالة فارغة"
            : "منطقة عرض الإطلالة، تحتوي على \(selectedItems.count) قطعة"
        )
        .accessibilityHint(
            selectedItems.isEmpty
            ? "اضغطي على زر إضافة القطع الموجود أسفل الشاشة لبدء إضافة القطع"
            : "اسحبي لليسار للوصول لأزرار إضافة وحذف القطع"
        )
    }
    
    // MARK: - أزرار الإضافة/الحذف
    private var actionButtons: some View {
        HStack(spacing: 15) {
            Button(action: {
                showingAddItemSheet = true
                voiceAssistant.speak("فتح نافذة اختيار القطع")
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color(red: 0.47, green: 0.58, blue: 0.44))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("زر إضافة قطع")
            .accessibilityHint("اضغط مرتين لفتح نافذة اختيار القطع من الخزانة")
            
            Button(action: {
                deleteSelectedItem()
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 24))
                    .foregroundColor(selectedItemId == nil ? .gray : .red)
                    .frame(width: 50, height: 50)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            }
            .disabled(selectedItemId == nil)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("زر حذف القطعة المحددة")
            .accessibilityHint(
                selectedItemId == nil
                ? "لا توجد قطعة محددة حالياً"
                : "اضغط مرتين لحذف القطعة المحددة من الإطلالة"
            )
        }
        .padding(.horizontal)
    }
    
    // MARK: - زر حفظ التعديلات
    private var saveButton: some View {
        Button(action: {
            saveChanges()
        }) {
            Text("حفظ التعديلات")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedItems.isEmpty ? Color.gray : Color(red: 0.47, green: 0.58, blue: 0.44))
                .cornerRadius(15)
        }
        .disabled(selectedItems.isEmpty)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(" حفظ التعديلات")
        .accessibilityHint(
            selectedItems.isEmpty
            ? "غير متاح، يجب إضافة قطعة واحدة على الأقل"
            : "اضغط مرتين لحفظ التعديلات والعودة"
        )
        .padding(.horizontal)
    }
    
    // MARK: - Functions
    
    private func loadOutfitData() {
        selectedItems = outfit.items
        selectedListName = outfit.listName ?? ""
        selectedListId = outfit.listId
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
        voiceAssistant.speak("تم حذف القطعة")
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
    
    private func saveChanges() {
        let db = Firestore.firestore()
        
        var updatedOutfit = outfit
        updatedOutfit.items = selectedItems
        updatedOutfit.listName = selectedListName.isEmpty ? nil : selectedListName
        updatedOutfit.listId = selectedListId
        
        do {
            let encoder = Firestore.Encoder()
            let outfitData = try encoder.encode(updatedOutfit)
            
            db.collection("outfits").document(outfit.id).setData(outfitData) { error in
                if let error = error {
                    print("❌ Error updating outfit: \(error.localizedDescription)")
                    voiceAssistant.speakError("فشل حفظ التعديلات")
                } else {
                    print("✅ Outfit updated successfully!")
                    voiceAssistant.speakSuccess("تم حفظ التعديلات")
                    presentationMode.wrappedValue.dismiss()
                }
            }
        } catch {
            print("❌ Error encoding outfit: \(error.localizedDescription)")
            voiceAssistant.speakError("فشل حفظ التعديلات")
        }
    }
    
    private func announceEditScreen() {
        let itemCount = selectedItems.count
        let message: String
        
        if itemCount == 0 {
            message = "صفحة تعديل الإطلالة، لا توجد قطع حالياً"
        } else if itemCount == 1 {
            message = "صفحة تعديل الإطلالة، تحتوي على قطعة واحدة"
        } else if itemCount == 2 {
            message = "صفحة تعديل الإطلالة، تحتوي على قطعتين"
        } else {
            message = "صفحة تعديل الإطلالة، تحتوي على \(itemCount) قطع"
        }
        
        voiceAssistant.announceScreenChange(message)
    }
}

// MARK: - كبسولة فلترة خاصة بصفحة تعديل الإطلالة
private struct OutfitListFilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    private var accessibilityLabelText: String {
        if title == "الكل" {
            return "جميع الإطلالات"
        } else {
            return "القائمة \(title)"
        }
    }
    
    private var accessibilityHintText: String {
        "تصفية الإطلالات حسب هذه القائمة."
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color(red: 0.47, green: 0.58, blue: 0.44) : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityValue(isSelected ? "محدد حاليًا" : "غير محدد")
        .accessibilityHint(accessibilityHintText)
    }
}
