//
//  LinkedItemCardHorizontal.swift
//  DitharApp
//
//  مكون عرض القطع المستخدمة بشكل أفقي في صفحة تفاصيل المنشور
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct LinkedItemCardHorizontal: View {
    let item: LinkedClothingItem
    var showBookmark: Bool = true // إظهار زر البوكمارك (افتراضياً true)
    @State private var isInWishlist = false
    @State private var isLoading = false
    
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // صورة القطعة مع أيقونات
            ZStack(alignment: .topTrailing) {
                // صورة القطعة
                AsyncImage(url: URL(string: item.imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // أيقونة الرابط (أعلى يمين)
                if let link = item.purchaseLink, !link.isEmpty, let url = URL(string: link) {
                    Link(destination: url) {
                        Image(systemName: "link")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(4)
                }
                
                // زر Bookmark (أسفل يمين)
                if showBookmark {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: toggleWishlist) {
                                Image(systemName: isInWishlist ? "bookmark.fill" : "bookmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(isInWishlist ? Color(red: 0.47, green: 0.58, blue: 0.44) : .white)
                                    .frame(width: 24, height: 24)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                            .disabled(isLoading)
                            .padding(4)
                        }
                    }
                    .frame(width: 80, height: 80)
                }
            }
            
            // اسم الفئة
            Text(item.category)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(maxWidth: 80)
            
            // اللون (إذا كان موجوداً)
            if let color = item.color, !color.isEmpty {
                Text(color)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .frame(maxWidth: 80)
            }
        }
        .frame(width: 100)
        .padding(12)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(12)
        .onAppear {
            checkIfInWishlist()
        }
    }
    
    // MARK: - وظائف Wishlist
    
    private func toggleWishlist() {
        guard let userId = currentUserId else { return }
        isLoading = true
        
        let db = Firestore.firestore()
        let wishlistRef = db.collection("users").document(userId).collection("wishlist")
        
        if isInWishlist {
            // حذف من الـ wishlist
            wishlistRef.document(item.id).delete { error in
                isLoading = false
                if error == nil {
                    isInWishlist = false
                    print("✅ تم حذف من قائمة الرغبات")
                }
            }
        } else {
            // إضافة إلى الـ wishlist
            let wishlistItem: [String: Any] = [
                "id": item.id,
                "itemId": item.id,
                "name": item.category,
                "category": item.category,
                "color": item.color ?? "",
                "imageURL": item.imageURL,
                "purchaseLink": item.purchaseLink ?? "",
                "addedAt": Date()
            ]
            
            wishlistRef.document(item.id).setData(wishlistItem) { error in
                isLoading = false
                if error == nil {
                    isInWishlist = true
                    print("✅ تم إضافة إلى قائمة الرغبات")
                }
            }
        }
    }
    
    private func checkIfInWishlist() {
        guard let userId = currentUserId else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).collection("wishlist").document(item.id).getDocument { document, error in
            isInWishlist = document?.exists ?? false
        }
    }
}

// MARK: - Preview
struct LinkedItemCardHorizontal_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 16) {
            LinkedItemCardHorizontal(
                item: LinkedClothingItem(
                    id: "1",
                    category: "فستان",
                    color: "وردي",
                    imageURL: "",
                    purchaseLink: "https://example.com"
                )
            )
            
            LinkedItemCardHorizontal(
                item: LinkedClothingItem(
                    id: "2",
                    category: "حقيبة",
                    color: "أسود",
                    imageURL: "",
                    purchaseLink: nil
                )
            )
            
            LinkedItemCardHorizontal(
                item: LinkedClothingItem(
                    id: "3",
                    category: "حذاء",
                    color: "بيج",
                    imageURL: "",
                    purchaseLink: "https://example.com"
                )
            )
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}
