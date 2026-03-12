import SwiftUI
import PhotosUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - نموذج بيانات المنشور الجديد
struct NewCommunityPost {
    var image: UIImage?
    var description: String = ""
    var linkedItems: [LinkedClothingItem] = []
    var selectedOutfitId: String? = nil
}

// MARK: - نوع مصدر الصورة
enum PostImageSource {
    case gallery
    case outfit
}

// MARK: - شاشة إضافة منشور
struct AddCommunityPostView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var communityService = CommunityService()

    @FocusState private var isDescriptionFocused: Bool
    @State private var postData = NewCommunityPost()
    @State private var selectedImage: PhotosPickerItem?
    @State private var showImagePicker = false
    @State private var showSelectOutfit = false
    @State private var showSelectItems = false
    @State private var isPosting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var imageSource: PostImageSource = .gallery

    // ✅ نخزن نص الرابط لكل قطعة بشكل مستقل
    @State private var purchaseLinkDrafts: [String: String] = [:]

    // ✅ حالة الحفظ لكل قطعة
    @State private var savedLinkIds: Set<String> = []
    @State private var savingLinkIds: Set<String> = []

    // ✅ آخر رابط محفوظ فعليًا لكل قطعة
    @State private var lastSavedLinks: [String: String] = [:]

    // ✅ تحكم بفتح/إغلاق قائمة القطع
    @State private var isLinkedItemsExpanded: Bool = true

    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    // للتحقق من اكتمال البيانات
    private var canPost: Bool {
        let hasImage = postData.image != nil
        let hasMinimumItems = postData.linkedItems.count >= 2
        return hasImage && hasMinimumItems
    }

    // MARK: - Soft Green Card Style
    private let softGreenBox = Color(red: 0.97, green: 0.98, blue: 0.96)
    private let mainGreen = Color(red: 0.47, green: 0.58, blue: 0.44)

    // ✅ أنميشن أبطأ
    private var accordionAnimation: Animation {
        .spring(response: 0.55, dampingFraction: 0.9)
    }

    private struct SoftCardShadow: ViewModifier {
        func body(content: Content) -> some View {
            content
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.white.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        imageSection
                        descriptionSection
                        linkedItemsSection
                    }
                    .padding(20)
                    .padding(.bottom, 30)
                }

                if isPosting {
                    loadingOverlay
                }
            }
            .navigationTitle("إضافة منشور")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إلغاء") { presentationMode.wrappedValue.dismiss() }
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("نشر") { publishPost() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(canPost ? mainGreen : .gray)
                        .disabled(!canPost || isPosting)
                }
            }
            .photosPicker(isPresented: $showImagePicker, selection: $selectedImage, matching: .images)
            .onChange(of: selectedImage) { newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        postData.image = image
                        imageSource = .gallery

                        if postData.selectedOutfitId != nil {
                            postData.linkedItems = []
                            postData.selectedOutfitId = nil
                            purchaseLinkDrafts = [:]
                            lastSavedLinks = [:]
                            savedLinkIds = []
                            savingLinkIds = []
                            isLinkedItemsExpanded = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showSelectOutfit) {
                SelectOutfitView(
                    onOutfitSelected: { outfit, outfitImage in
                        handleOutfitSelection(outfit: outfit, image: outfitImage)
                    }
                )
            }
            .sheet(isPresented: $showSelectItems) {
                SelectItemsFromWardrobeView(selectedItems: $postData.linkedItems)
            }
            .alert(alertMessage, isPresented: $showAlert) {
                Button("حسناً", role: .cancel) {}
            }
            .onAppear {
                for item in postData.linkedItems {
                    purchaseLinkDrafts[item.id] = item.purchaseLink ?? ""
                    lastSavedLinks[item.id] = (item.purchaseLink ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

                    if let link = item.purchaseLink,
                       !link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        savedLinkIds.insert(item.id)
                    }
                }
                if !postData.linkedItems.isEmpty { isLinkedItemsExpanded = true }
            }
            .onChange(of: postData.linkedItems.map(\.id)) { _ in
                for item in postData.linkedItems {
                    if purchaseLinkDrafts[item.id] == nil {
                        purchaseLinkDrafts[item.id] = item.purchaseLink ?? ""
                    }
                    if lastSavedLinks[item.id] == nil {
                        lastSavedLinks[item.id] = (item.purchaseLink ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    if let link = item.purchaseLink,
                       !link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        savedLinkIds.insert(item.id)
                    }
                }

                let ids = Set(postData.linkedItems.map { $0.id })
                purchaseLinkDrafts = purchaseLinkDrafts.filter { ids.contains($0.key) }
                lastSavedLinks = lastSavedLinks.filter { ids.contains($0.key) }
                savedLinkIds = Set(savedLinkIds.filter { ids.contains($0) })
                savingLinkIds = Set(savingLinkIds.filter { ids.contains($0) })

                if !postData.linkedItems.isEmpty {
                    withAnimation(accordionAnimation) {
                        isLinkedItemsExpanded = true
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isDescriptionFocused = false
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: - Image Section
    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("صورة الإطلالة")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)

            if let image = postData.image { imagePreview(image) }
            else { imageSelectionButton }
        }
    }

    private func imagePreview(_ image: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 350)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            HStack(spacing: 12) {
                Menu {
                    Button(action: { showImagePicker = true }) {
                        Label("من المعرض", systemImage: "photo")
                    }
                    Button(action: { showSelectOutfit = true }) {
                        Label("من إطلالاتي", systemImage: "tshirt")
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14))
                        Text("استبدال")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(mainGreen)
                    .cornerRadius(20)
                }

                Button(action: {
                    postData.image = nil
                    postData.selectedOutfitId = nil
                    if imageSource == .outfit {
                        postData.linkedItems = []
                        purchaseLinkDrafts = [:]
                        lastSavedLinks = [:]
                        savedLinkIds = []
                        savingLinkIds = []
                        isLinkedItemsExpanded = true
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                        Text("إزالة")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .cornerRadius(20)
                }
            }
            .padding(12)
        }
    }

    private var imageSelectionButton: some View {
        Menu {
            Button(action: { showImagePicker = true }) {
                Label("من المعرض", systemImage: "photo")
            }
            Button(action: { showSelectOutfit = true }) {
                Label("من إطلالاتي", systemImage: "tshirt")
            }
        } label: {
            VStack(spacing: 16) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 40))
                    .foregroundColor(mainGreen)

                Text("إضافة صورة")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(mainGreen)

                Text("من المعرض أو من إطلالاتي")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .background(softGreenBox)
            .modifier(SoftCardShadow())
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(mainGreen, style: StrokeStyle(lineWidth: 2, dash: [8]))
            )
        }
    }

    // MARK: - Description Section
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("الوصف (اختياري)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)

            ZStack(alignment: .topTrailing) {
                if postData.description.isEmpty {
                    Text("اكتب وصفاً للإطلالة...")
                        .font(.system(size: 15))
                        .foregroundColor(.gray.opacity(0.6))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                TextEditor(text: $postData.description)
                    .font(.system(size: 15))
                    .frame(height: 120)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .multilineTextAlignment(.leading)
                    .scrollContentBackground(.hidden)
                    .focused($isDescriptionFocused)
                    .submitLabel(.done)
            }
            .background(softGreenBox)
            .cornerRadius(12)
            .modifier(SoftCardShadow())
        }
    }

    // MARK: - Linked Items Section
    private var linkedItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("القطع المستخدمة")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {

                // ✅ Header داخل نفس البوكس (التعديلات هنا)
                // Header داخل نفس البوكس (✅ بعد عكس الترتيب)
                // Header داخل نفس البوكس ✅ (مثبّت LTR عشان ما ينقلب بالـ RTL)
                HStack(spacing: 12) {

                    // ✅ زر الإضافة يسار
                    Button(action: { showSelectItems = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(mainGreen)
                    }

                    Spacer()

                    // ✅ السهم يسار "تم إضافة ..." (يعني قبل النص)
                    HStack(spacing: 6) {

                        // النص أولاً


                        // السهم جنب النص مباشرة
                        if postData.linkedItems.count >= 2 {
                            Button {
                                withAnimation(accordionAnimation) {
                                    isLinkedItemsExpanded.toggle()
                                }
                            } label: {
                                Image(systemName: isLinkedItemsExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(mainGreen) // ✅ أخضر
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Text(headerItemsText)
                            .font(.system(size: 15))
                            .foregroundColor(headerItemsColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)                }
                .padding(16)
                .environment(\.layoutDirection, .leftToRight)   // ✅ هذا هو اللي بيخلّي التغيير يبان

                if !postData.linkedItems.isEmpty {
                    Divider().opacity(0.25)
                }

                if !postData.linkedItems.isEmpty && isLinkedItemsExpanded {
                    VStack(spacing: 14) {
                        linkedItemsList
                    }
                    .padding(16)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }
            }
            .background(softGreenBox)
            .cornerRadius(12)
            .modifier(SoftCardShadow())
            .clipped()
        }
    }

    private var headerItemsText: String {
        if postData.linkedItems.isEmpty { return "أضف من خزانتك" }
        else if postData.linkedItems.count == 1 { return "يجب إضافة قطعتين على الأقل" }
        else { return "تم إضافة \(postData.linkedItems.count) قطعة" }
    }

    private var headerItemsColor: Color {
        if postData.linkedItems.isEmpty { return .gray }
        if postData.linkedItems.count == 1 { return .orange }
        return mainGreen
    }

    private var linkedItemsList: some View {
        VStack(spacing: 14) {
            ForEach(postData.linkedItems.indices, id: \.self) { index in
                let item = postData.linkedItems[index]

                VStack(spacing: 12) {

                    HStack(spacing: 12) {
                        Button(action: {
                            let removedId = item.id
                            postData.linkedItems.removeAll { $0.id == removedId }
                            purchaseLinkDrafts[removedId] = nil
                            lastSavedLinks[removedId] = nil
                            savedLinkIds.remove(removedId)
                            savingLinkIds.remove(removedId)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.red)
                        }

                        Spacer(minLength: 8)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.category)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.black)

                            if let color = item.color, !color.isEmpty {
                                Text(color)
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            }
                        }

                        AsyncImage(url: URL(string: item.imageURL)) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(Color.gray.opacity(0.15))
                        }
                        .frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .environment(\.layoutDirection, .leftToRight)

                    HStack(spacing: 10) {
                        TextField("أدخل رابط الشراء", text: Binding(
                            get: { purchaseLinkDrafts[item.id] ?? "" },
                            set: { newValue in
                                purchaseLinkDrafts[item.id] = newValue
                                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                let lastSaved = lastSavedLinks[item.id] ?? ""
                                if trimmed != lastSaved { savedLinkIds.remove(item.id) }
                            }
                        ))
                        .font(.system(size: 14))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                        )
                        .multilineTextAlignment(.leading)

                        let draft = (purchaseLinkDrafts[item.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        let isDraftEmpty = draft.isEmpty

                        Button {
                            guard !isDraftEmpty else { return }

                            postData.linkedItems[index] = LinkedClothingItem(
                                id: item.id,
                                category: item.category,
                                color: item.color,
                                imageURL: item.imageURL,
                                purchaseLink: draft
                            )
                            lastSavedLinks[item.id] = draft

                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                savingLinkIds.insert(item.id)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                    savingLinkIds.remove(item.id)
                                    savedLinkIds.insert(item.id)
                                }
                            }
                        } label: {
                            let isSaved  = savedLinkIds.contains(item.id)
                            let isSaving = savingLinkIds.contains(item.id)

                            ZStack {
                                Text("حفظ")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(mainGreen)
                                    .opacity((isSaved || isSaving) ? 0 : 1)

                                ProgressView()
                                    .scaleEffect(0.9)
                                    .opacity(isSaving ? 1 : 0)

                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(mainGreen)
                                    .opacity(isSaved ? 1 : 0)
                                    .scaleEffect(isSaved ? 1 : 0.6)
                            }
                            .frame(width: 64, height: 40)
                        }
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isDraftEmpty ? Color.gray.opacity(0.25) : mainGreen.opacity(0.35), lineWidth: 1.2)
                        )
                        .disabled(isDraftEmpty)
                        .opacity(isDraftEmpty ? 0.6 : 1.0)
                    }
                    .environment(\.layoutDirection, .rightToLeft)
                }
                .padding(14)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
                .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 2)
            }
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.5).tint(.white)
                Text("جاري النشر...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(Color.black.opacity(0.8))
            .cornerRadius(16)
        }
    }

    private func handleOutfitSelection(outfit: Outfit, image: UIImage) {
        postData.image = image
        imageSource = .outfit
        postData.selectedOutfitId = outfit.id

        let tempItems = outfit.items.compactMap { item -> LinkedClothingItem? in
            guard let imageURL = item.localImageURLString else { return nil }
            return LinkedClothingItem(
                id: item.clothingItemId,
                category: "غير محدد",
                color: nil,
                imageURL: imageURL,
                purchaseLink: nil
            )
        }

        postData.linkedItems = tempItems

        purchaseLinkDrafts = Dictionary(uniqueKeysWithValues: tempItems.map { ($0.id, $0.purchaseLink ?? "") })
        lastSavedLinks = Dictionary(uniqueKeysWithValues: tempItems.map { ($0.id, ($0.purchaseLink ?? "").trimmingCharacters(in: .whitespacesAndNewlines)) })

        withAnimation(accordionAnimation) { isLinkedItemsExpanded = true }

        fetchItemsDetailsForOutfit()
    }

    private func fetchItemsDetailsForOutfit() {
        guard let userId = currentUserId else { return }
        let db = Firestore.firestore()

        let itemIds = postData.linkedItems.map { $0.id }
        guard !itemIds.isEmpty else { return }

        db.collection("Clothes")
            .whereField("userId", isEqualTo: userId)
            .whereField(FieldPath.documentID(), in: itemIds)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching items: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                var updatedItems: [LinkedClothingItem] = []

                for item in self.postData.linkedItems {
                    if let doc = documents.first(where: { $0.documentID == item.id }) {
                        let data = doc.data()
                        let category = (data["analysis"] as? [String: Any])?["category"] as? String ?? "غير محدد"
                        let color = (data["analysis"] as? [String: Any])?["color"] as? String
                        let purchaseLink = (data["attrs"] as? [String: Any])?["purchaseLink"] as? String

                        updatedItems.append(LinkedClothingItem(
                            id: item.id,
                            category: category,
                            color: color,
                            imageURL: item.imageURL,
                            purchaseLink: purchaseLink
                        ))
                    } else {
                        updatedItems.append(item)
                    }
                }

                DispatchQueue.main.async {
                    self.postData.linkedItems = updatedItems
                    for it in updatedItems {
                        if self.purchaseLinkDrafts[it.id] == nil { self.purchaseLinkDrafts[it.id] = it.purchaseLink ?? "" }
                        if self.lastSavedLinks[it.id] == nil { self.lastSavedLinks[it.id] = (it.purchaseLink ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
                        if let link = it.purchaseLink, !link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            self.savedLinkIds.insert(it.id)
                        }
                    }
                }
            }
    }

    private func publishPost() {
        guard let userId = currentUserId,
              let image = postData.image,
              postData.linkedItems.count >= 2 else {
            alertMessage = "يرجى التأكد من إضافة صورة وقطعتين على الأقل"
            showAlert = true
            return
        }

        isPosting = true

        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { document, error in
            let userData = document?.data()
            let username = (userData?["username"] as? String) ?? "مستخدم"
            let fullName = userData?["fullName"] as? String
            let photoURL = userData?["photoURL"] as? String

            self.communityService.createPost(
                userId: userId,
                username: username,
                userFullName: fullName,
                userPhotoURL: photoURL,
                image: image,
                description: self.postData.description,
                linkedItems: self.postData.linkedItems
            ) { result in
                self.isPosting = false
                switch result {
                case .success:
                    self.presentationMode.wrappedValue.dismiss()
                case .failure(let error):
                    self.alertMessage = "حدث خطأ أثناء النشر: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }
}

// MARK: - Preview
struct AddCommunityPostView_Previews: PreviewProvider {
    static var previews: some View {
        AddCommunityPostView()
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "ar"))
    }
}
