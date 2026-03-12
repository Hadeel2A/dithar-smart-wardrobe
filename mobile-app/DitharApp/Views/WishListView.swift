//
//  WishListView.swift
//  DitharApp
//
//  صفحة الـ Wish List - قائمة القطع المرغوبة
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - نموذج عنصر الـ Wish List
struct WishListItem: Identifiable, Codable {
    let id: String
    let itemId: String
    let name: String
    let category: String
    let color: String?
    let imageURL: String
    let purchaseLink: String?
    let addedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, itemId, name, category, color, imageURL, purchaseLink, addedAt
    }
}

struct WishListView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var wishListItems: [WishListItem] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedCategory = "الكل"
    
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    // الفئات المتاحة
    let categories = ["الكل", "قطع علوية", "قطع سفلية", "أحذية", "إكسسوارات", "قطع كاملة"]
    
    var filteredItems: [WishListItem] {
        wishListItems.filter { item in
            let matchesSearch = searchText.isEmpty || item.name.contains(searchText) || item.category.contains(searchText)
            let matchesCategory = selectedCategory == "الكل" || item.category == selectedCategory
            return matchesSearch && matchesCategory
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                } else if wishListItems.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bookmark.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("قائمة الأمنيات فارغة")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.gray)
                        
                        Text("ابدأ بإضافة القطع المرغوبة من البوستات")
                            .font(.system(size: 14))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        // MARK: - البحث والفلاتر
                        VStack(spacing: 12) {
                            // حقل البحث
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray.opacity(0.6))
                                    .font(.system(size: 16))
                                
                                TextField("ابحث عن قطعة...", text: $searchText)
                                    .font(.system(size: 14))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.08))
                            .cornerRadius(24)
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(24)
                        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        
                        // MARK: - قائمة العناصر
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredItems) { item in
                                    WishListItemCard(item: item, onRemove: {
                                        removeFromWishList(itemId: item.id)
                                    })
                                }
                            }
                            .padding(12)
                        }
                    }
                }
            }

            .navigationTitle("قائمة الأمنيات")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Image(systemName: "chevron.right") // سهم رجوع مناسب للـ RTL
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color(red: 0.47, green: 0.58, blue: 0.44))
                    }
                }
            }
            .onAppear { loadWishList() }
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "ar"))
        }
    }
    
    // MARK: - وظائف البيانات
    
    private func loadWishList() {
        guard let userId = currentUserId else {
            isLoading = false
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).collection("wishlist")
            .order(by: "addedAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ خطأ في جلب قائمة الرغبات: \(error.localizedDescription)")
                    isLoading = false
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    isLoading = false
                    return
                }
                
                self.wishListItems = documents.compactMap { doc in
                    let data = doc.data()
                    
                    guard let id = data["id"] as? String,
                          let itemId = data["itemId"] as? String,
                          let name = data["name"] as? String,
                          let category = data["category"] as? String,
                          let imageURL = data["imageURL"] as? String else {
                        return nil
                    }
                    
                    let color = data["color"] as? String
                    let purchaseLink = data["purchaseLink"] as? String
                    
                    // تحويل Timestamp إلى Date
                    var addedAt = Date()
                    if let timestamp = data["addedAt"] as? Timestamp {
                        addedAt = timestamp.dateValue()
                    } else if let date = data["addedAt"] as? Date {
                        addedAt = date
                    }
                    
                    return WishListItem(
                        id: id,
                        itemId: itemId,
                        name: name,
                        category: category,
                        color: color,
                        imageURL: imageURL,
                        purchaseLink: purchaseLink,
                        addedAt: addedAt
                    )
                }
                
                isLoading = false
            }
    }
    
    private func removeFromWishList(itemId: String) {
        guard let userId = currentUserId else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).collection("wishlist").document(itemId).delete { error in
            if let error = error {
                print("❌ خطأ في حذف من قائمة الرغبات: \(error.localizedDescription)")
            } else {
                print("✅ تم حذف من قائمة الرغبات")
            }
        }
    }
}

// MARK: - بطاقة عنصر الـ Wish List
struct WishListItemCard: View {
    let item: WishListItem
    let onRemove: () -> Void
    
    @State private var isSaved: Bool = true
    
    private let darkGreen = Color(red: 0.35, green: 0.45, blue: 0.32)
    private let lightGreen = Color(red: 0.91, green: 0.93, blue: 0.88)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // الصورة
                AsyncImage(url: URL(string: item.imageURL)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.2))
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // المعلومات
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    // ✅ شلنا سطر الاسم/التصنيف الرمادي عشان ما يتكرر

                    if let color = item.color, !color.isEmpty {
                        Text("اللون: \(color)")
                            .font(.system(size: 12))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    
                    Text(formatDate(item.addedAt))
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // زر الحفظ بدل X
                Button {
                    // يصير غير محفوظ
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isSaved = false
                    }

                    // ينحذف من قائمة الرغبات
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        onRemove()
                    }
                } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(
                            Color(red: 0.47, green: 0.58, blue: 0.44) // أخضر فقط
                        )
                }              }
            
            // رابط الشراء
            if let link = item.purchaseLink, !link.isEmpty, let url = URL(string: link) {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "link")
                            .font(.system(size: 14))
                        Text("رابط الشراء")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(Color(red: 0.47, green: 0.58, blue: 0.44))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.47, green: 0.58, blue: 0.44).opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding(12)
        // ✅ الكرت يكون “مظلل” أخضر غامق وهو محفوظ
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .onAppear {
            isSaved = true
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar")
        formatter.dateFormat = "d MMMM"
        return "أضيفت في \(formatter.string(from: date))"
    }
}
struct WishListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            WishListView()
        }
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
    }
}
