import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

// MARK: - صفحة الإطلالات الرئيسية
struct OutfitsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var notificationService = NotificationService() //
    
    @State private var userPhotoURL: String? = nil
    @State private var userData: [String: Any]?
    @State private var isLoading = true
    @State private var outfits: [Outfit] = []
    @State private var lists: [OutfitList] = []
    @State private var showFavoritesOnly = false
    @State private var selectedListId: String? = nil // nil = "الكل"
    @State private var showManageLists = false
    @State private var showCalendar = false

    @State private var showNotifications = false //
    private let lightGreenBackground = Color(red: 0.91, green: 0.93, blue: 0.88)
    private let darkGreenIcon = Color(red: 0.35, green: 0.45, blue: 0.32)
    private let lightGreenButton = Color(red: 0.91, green: 0.93, blue: 0.88)

    private var displayFullName: String {
        (userData?["fullName"] as? String) ??
        (userData?["name"] as? String) ?? ""
    }
    
    private var displayUsername: String {
        (userData?["username"] as? String) ?? ""
    }
    
    private var currentUserId: String? {            //
        Auth.auth().currentUser?.uid
    }
    
    // فلترة الإطلالات
    var filteredOutfits: [Outfit] {
        outfits.filter { outfit in
            let matchesFavorite = !showFavoritesOnly || outfit.isFavorite
            let matchesList = selectedListId == nil || outfit.listId == selectedListId
            return matchesFavorite && matchesList
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                VStack {
                    lightGreenBackground
                        .frame(height: 130)
                    Spacer()
                }
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: - الشريط العلوي
                    topBar
                    
                    Spacer().frame(height: 12)   // جرّبي 12 أو 16 أو 20

                    // MARK: - التقويم والمفضلة
                  //  calendarAndFav
                    
                    // MARK: - فلتر القوائم
                    listFilterSection
                    
                    // MARK: - عرض الإطلالات
                    outfitsContent
                }
                
                // MARK: - زر الإضافة العائم
                addButton
            }
            .navigationTitle("إطلاتي")
            .navigationBarHidden(true)
            .sheet(isPresented: $showManageLists) {
                ManageListsView(lists: $lists)
                    .environmentObject(authManager)
            }
            .fullScreenCover(isPresented: $showCalendar) {
                CalendarPageView()
                    .environmentObject(authManager)
            }
            .sheet(isPresented: $showNotifications, onDismiss: {                    //
                // تحديث العداد بعد إغلاق الإشعارات
                if let userId = currentUserId {
                    notificationService.fetchUnreadCount(userId: userId) { count in
                        // العداد يتحدث تلقائياً من خلال Listener
                    }
                }
            }) {
                NotificationsView()
            }
            .onAppear {
                loadUserData()
                loadOutfits()
                loadLists()
                
                // إعلان دخول صفحة الإطلالات
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let count = outfits.count
                    let message = "صفحة الإطلالات،  "
                    DitharVoiceAssistant.shared.announceScreenChange(message)
                }
                // بدء الاستماع للإشعارات
                if let userId = currentUserId {
                    notificationService.startListeningToNotifications(userId: userId)
                }
            }
            .onDisappear {
                // إيقاف الاستماع عند الخروج من الشاشة
                notificationService.stopListeningToNotifications()
            } 
        }
    }
    
    // MARK: - Top Bar
    private var topBar: some View {
        HStack(spacing: 12) {
            
            // الصورة الشخصية
            NavigationLink { ProfileView() } label: {
                AvatarView(
                    displayName: displayFullName.isEmpty ? (displayUsername.isEmpty ? " " : displayUsername) : displayFullName,
                    urlString: userPhotoURL,
                    size: 44
                )
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("الملف الشخصي")
          
            
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
        

    }
    
   
    
    // MARK: - List Filter Section
    private var listFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {

                // زر التقويم
                Button {
                    showCalendar = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 22))
                        .foregroundColor(darkGreenIcon)
                        .frame(width: 40, height: 40)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("التقويم")

                // زر المفضلة
                Button(action: {
                    showFavoritesOnly.toggle()
                }) {
                    Image(systemName: showFavoritesOnly ? "heart.fill" : "heart")
                        .font(.system(size: 18))
                        .foregroundColor(showFavoritesOnly ? .red : darkGreenIcon)
                        .frame(width: 40, height: 40)
                        .background(showFavoritesOnly ? lightGreenButton : Color.white)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(showFavoritesOnly ? "إلغاء فلتر الإطلالات المفضلة" : "المفضلة")
                .accessibilityAddTraits(.isButton)

                // خط فاصل خفيف بعد المفضلة
                Divider()
                    .frame(height: 28)
                    .overlay(Color.gray.opacity(0.5))
                    .accessibilityHidden(true)

                // فلتر "الكل"
                ListFilterButton(title: "الكل", isSelected: selectedListId == nil) {
                    selectedListId = nil
                    if AccessibilityManager.shared.isAVSpeechEnabled {
                        DitharVoiceAssistant.shared.speak("تم اختيار الكل")
                    }
                }

                // باقي القوائم (المضافة من المستخدم)
                ForEach(lists) { list in
                    ListFilterButton(title: list.name, isSelected: selectedListId == list.id) {
                        selectedListId = list.id
                        if AccessibilityManager.shared.isAVSpeechEnabled {
                            DitharVoiceAssistant.shared.speak("تم اختيار قائمة \(list.name)")
                        }
                    }
                }

                // ✅ زر + (آخر شيء بعد القوائم)
                Button(action: {
                    if AccessibilityManager.shared.isAVSpeechEnabled {
                        DitharVoiceAssistant.shared.speak("إضافة قائمة جديدة")
                    }
                    showManageLists = true   // أو لو عندك شاشة منفصلة للإضافة: showAddList = true
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
        .clipped(antialiased: false)
        .padding(.top, 15)
    }

    
    // MARK: - Outfits Content
    @ViewBuilder
    private var outfitsContent: some View {
        if isLoading {
            Spacer()
            ProgressView()
            Spacer()
        } else if filteredOutfits.isEmpty {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "tshirt.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.gray.opacity(0.5))
                Text("لا توجد إطلالات")
                    .foregroundColor(.gray)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("لا توجد إطلالات محفوظة حالياً")
            Spacer()
        } else {
            outfitsGrid
        }
    }
    
    // MARK: - Outfits Grid
    private var outfitsGrid: some View {
        GeometryReader { geo in
            let horizontalPadding: CGFloat = 20
            let interItem: CGFloat = 15
            let cardWidth = (geo.size.width - (horizontalPadding * 2) - interItem) / 2
            let cardHeight = cardWidth * 1.3
            
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.fixed(cardWidth), spacing: interItem),
                    GridItem(.fixed(cardWidth), spacing: interItem)
                ], spacing: interItem) {

                    ForEach(filteredOutfits) { outfit in
                        NavigationLink {
                            OutfitDetailsView(outfit: outfit)
                                .environmentObject(authManager)
                        } label: {
                            OutfitCard(
                                outfit: outfit,
                                width: cardWidth,
                                height: cardHeight,
                                onFavoriteToggle: {
                                    toggleFavorite(outfitId: outfit.id)
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 10)        // 👈 هذا المهم
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 100)
            }        }
    }
    
    // MARK: - Add Button
    private var addButton: some View {
        VStack {
            Spacer()
            HStack {
                NavigationLink {
                    AddOutfitView()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 65, height: 65)
                        .background(Color(red: 0.47, green: 0.58, blue: 0.44))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .accessibilityLabel("إضافة إطلالة ")
                .padding(.leading, 30)
                .padding(.bottom, 100)
                
                Spacer()
            }
        }
    }
    
    // MARK: - Functions
    
    private func loadUserData() {
        guard let userId = authManager.user?.uid else { return }
        let db = Firestore.firestore()
        
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let data = snapshot?.data() {
                self.userData = data
                self.userPhotoURL = data["photoURL"] as? String
            }
        }
    }
    
    private func loadOutfits() {
        guard let userId = authManager.user?.uid else { return }
        let db = Firestore.firestore()
        
        db.collection("outfits")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Error loading outfits: \(error.localizedDescription)")
                    isLoading = false
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    isLoading = false
                    return
                }
                
                self.outfits = documents.compactMap { doc -> Outfit? in
                    try? doc.data(as: Outfit.self)
                }
                
                deleteOutfitsWithMissingItems()
                
                isLoading = false
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
    
    private func toggleFavorite(outfitId: String) {
        guard let index = outfits.firstIndex(where: { $0.id == outfitId }) else { return }
        
        let db = Firestore.firestore()
        let newFavoriteStatus = !outfits[index].isFavorite
        
        db.collection("outfits").document(outfitId).updateData([
            "isFavorite": newFavoriteStatus
        ]) { error in
            if let error = error {
                print("❌ Error updating favorite: \(error.localizedDescription)")
            } else {
                outfits[index].isFavorite = newFavoriteStatus
            }
        }
    }
    
    // MARK: - حذف الإطلالات التي تحتوي على قطع محذوفة
    private func deleteOutfitsWithMissingItems() {
        guard let userId = authManager.user?.uid else { return }
        let db = Firestore.firestore()
        
        for outfit in outfits {
            let itemIds = outfit.items
                .map { $0.clothingItemId }
                .filter { !$0.isEmpty }
            
            guard !itemIds.isEmpty else { continue }
            
            db.collection("Clothes")
                .whereField("userId", isEqualTo: userId)
                .whereField(FieldPath.documentID(), in: itemIds)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("❌ Error checking items for outfit \(outfit.id): \(error.localizedDescription)")
                        return
                    }
                    
                    let existingIds = snapshot?.documents.map { $0.documentID } ?? []
                    
                    guard !existingIds.isEmpty else {
                        print("⚠️ No matching Clothes found for outfit \(outfit.id). Skipping delete.")
                        return
                    }
                    
                    let missing = Set(itemIds).subtracting(existingIds)
                    
                    if !missing.isEmpty {
                        db.collection("outfits").document(outfit.id).delete { error in
                            if let error = error {
                                print("❌ Error deleting outfit \(outfit.id): \(error.localizedDescription)")
                            } else {
                                print("🗑️ Outfit \(outfit.id) deleted because some linked items were removed.")
                            }
                        }
                    }
                }
        }
    }
}


// MARK: - زر فلتر القائمة
struct ListFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected
                    ? Color(red: 0.47, green: 0.58, blue: 0.44) // الأخضر
                    : Color.white
                )
                .cornerRadius(20)
                .shadow(
                    color: isSelected
                        ? Color.black.opacity(0.15)
                        : Color.black.opacity(0.06),
                    radius: 4,
                    x: 0,
                    y: 2
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityHint(
            isSelected ? "هذا هو التصفية الحالي" : "تصفية الإطلالات حسب هذه القائمة"
        )
        .accessibilityAddTraits(.isButton)
    }
}
// MARK: - نموذج بيانات القائمة
struct OutfitList: Identifiable {
    let id: String
    let name: String
}

// MARK: - Accessibility Helper
extension OutfitsView {
    private func outfitAccessibilityLabel(_ outfit: Outfit) -> String {
        // نأخذ الفئات فقط وننظفها
        let categories = outfit.items.compactMap { item -> String? in
            let trimmed = item.category.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        
        // لو ما فيه أي فئة
        if categories.isEmpty {
            return "إطلالة بدون قطع محددة"
        }
        
        // نزيل التكرار مع الحفاظ على الترتيب
        var unique: [String] = []
        for cat in categories where !unique.contains(cat) {
            unique.append(cat)
        }
        
        // 👇 هنا السحر: نجمع كل الفئات مع بعض باستخدام " و"
        let categoriesText = unique.joined(separator: " و")
        
        return "إطلالة \(categoriesText)"
    }
}


// MARK: - بطاقة الإطلالة
struct OutfitCard: View {
    let outfit: Outfit
    let width: CGFloat
    let height: CGFloat
    let onFavoriteToggle: () -> Void
    
    @State private var isFavorite: Bool
    
    init(outfit: Outfit, width: CGFloat, height: CGFloat, onFavoriteToggle: @escaping () -> Void) {
        self.outfit = outfit
        self.width = width
        self.height = height
        self.onFavoriteToggle = onFavoriteToggle
        _isFavorite = State(initialValue: outfit.isFavorite)
    }
    
    var body: some View {
        ZStack {
            // خلفية بيضاء
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
            
            // عرض القطع كـ Collage
            GeometryReader { geo in
                let scaleX = geo.size.width / 350
                let scaleY = geo.size.height / 400
                
                ForEach(outfit.items) { item in
                    if let urlString = item.localImageURLString, let url = URL(string: urlString) {
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
            
            // زر القلب
            VStack {
                HStack {
                    Spacer()
                    Button {
                        isFavorite.toggle()
                        onFavoriteToggle()
                    } label: {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 20))
                            .foregroundColor(isFavorite ? .red : .gray)
                            .padding(10)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isFavorite ? "إزالة الإطلالة من المفضلة" : "إضافة الإطلالة إلى المفضلة")
                    .padding(8)
                }
                Spacer()
            }
        }
        .frame(width: width, height: height)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(
                    color: Color.black.opacity(0.08), // كان 0.12
                    radius: 8,                         // كان 10
                    x: 0,
                    y: 4                               // كان 6
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private var placeholderImage: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .accessibilityHidden(true)
    }
}

// MARK: - صفحة إدارة القوائم
struct ManageListsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthenticationManager
    @Binding var lists: [OutfitList]
    
    @State private var newListName = ""
    @State private var showAddList = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Header
                headerSection
                
                // MARK: - قائمة القوائم
                listsScrollView
            }
            .navigationBarHidden(true)
            .alert("أدخل اسم القائمة الجديدة", isPresented: $showAddList) {
                TextField("اسم القائمة", text: $newListName)
                Button("إلغاء", role: .cancel) {
                    newListName = ""
                }
                Button("إضافة") {
                    addNewList()
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .accessibilityLabel("إغلاق القوائم")
            }
            .padding()
            
            Text("اضافة قائمة")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 20)
                .accessibilityAddTraits(.isHeader)
            
          
                Text("أنشئ قائمة تُسهّل اختيار إطلالاتك اليومية")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .padding(.bottom, 20)
               
            
        }
    }
    
    // MARK: - Lists Scroll View
    private var listsScrollView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(lists) { list in
                    listRow(list)
                }
                
                addNewListButton
            }
            .padding(.horizontal)
        }
    }
    
    @State private var showDeleteConfirmation = false
    @State private var selectedList: OutfitList? = nil

    // MARK: - List Row
    private func listRow(_ list: OutfitList) -> some View {
        Button(action: {
            selectedList = list
            showDeleteConfirmation = true
        }) {
            HStack {
                Spacer()
                
                Text(list.name)
                    .font(.system(size: 16))
                    .foregroundColor(.black)
                
                Spacer()
                
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .padding()
            .background(Color(red: 0.95, green: 0.95, blue: 0.95))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(list.name) // 👈 زي "إضافة قائمة جديدة" بالضبط
        .accessibilityHint("اضغط لحذف هذه القائمة")
        .confirmationDialog(
            "هل أنت متأكد من حذف القائمة بشكل نهائي؟",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("تأكيد الحذف", role: .destructive) {
                if let listToDelete = selectedList {
                    deleteList(listId: listToDelete.id)
                }
            }
            Button("إلغاء", role: .cancel) {}
        } message: {
            Text("إذا تم حذف القائمة، الإطلالات المرتبطة ستبقى بلا قائمة")
                .font(.footnote)
                .foregroundColor(.gray)
        }
    }


    // MARK: - Add New List Button
    private var addNewListButton: some View {
        Button(action: {
            showAddList = true
        }) {
            HStack {
                Spacer()
                Text("اضافة قائمة جديدة")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding()
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
            )
            .cornerRadius(10)
        }
        .accessibilityLabel("إضافة قائمة جديدة")
        .accessibilityHint("إنشاء قائمة لحفظ مجموعة من الإطلالات")
    }
    
    // MARK: - Functions
    
    private func addNewList() {
        guard !newListName.isEmpty else { return }
        guard let userId = authManager.user?.uid else { return }
        
        let db = Firestore.firestore()
        let listId = UUID().uuidString
        
        db.collection("users").document(userId).collection("lists").document(listId).setData([
            "name": newListName
        ]) { error in
            if let error = error {
                print("❌ Error adding list: \(error.localizedDescription)")
            } else {
                print("✅ List added successfully")
                newListName = ""
            }
        }
    }
    
    private func deleteList(listId: String) {
        guard let userId = authManager.user?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).collection("lists").document(listId).delete { error in
            if let error = error {
                print("❌ Error deleting list: \(error.localizedDescription)")
            } else {
                print("✅ List deleted successfully")
            }
        }
    }
}

// MARK: - Preview
struct OutfitsView_Previews: PreviewProvider {
    static var previews: some View {
        OutfitsView()
            .environmentObject(AuthenticationManager())
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "ar"))
    }
}
