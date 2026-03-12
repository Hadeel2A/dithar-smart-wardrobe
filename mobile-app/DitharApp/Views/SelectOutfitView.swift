import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - شاشة اختيار الإطلالة
struct SelectOutfitView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var outfits: [Outfit] = []
    @State private var isLoading = true
    @State private var isProcessingOutfit = false
    
    let onOutfitSelected: (Outfit, UIImage) -> Void
    
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.white.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                } else if outfits.isEmpty {
                    emptyState
                } else {
                    outfitsList
                }
                
                // Loading overlay when processing outfit
                if isProcessingOutfit {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        
                        Text("جاري تحميل الإطلالة...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(32)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(16)
                }
            }
            .navigationTitle("اختر إطلالة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("إلغاء") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .accessibilityLabel("إلغاء")
                    .disabled(isProcessingOutfit)
                }
            }
            .onAppear {
                loadOutfits()
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tshirt")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
                .accessibilityHidden(true)
            
            Text("لا توجد إطلالات")
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            Text("قم بإنشاء إطلالة أولاً من صفحة الإطلالات")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Outfits List
    private var outfitsList: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(outfits) { outfit in
                    Button(action: {
                        selectOutfit(outfit)
                    }) {
                        OutfitSelectionCard(outfit: outfit)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isProcessingOutfit)
                    .opacity(isProcessingOutfit ? 0.5 : 1.0)
                    .accessibilityLabel(outfitLabel(outfit))
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Accessibility Helper
    private func outfitLabel(_ outfit: Outfit) -> String {
        var label = "إطلالة"
        
        if let listName = outfit.listName, !listName.isEmpty {
            label += " من قائمة \(listName)"
        }
        
        let count = outfit.items.count
        label += "، \(count) "
        label += count == 1 ? "قطعة" : count == 2 ? "قطعتين" : "قطع"
        
        if !outfit.items.isEmpty {
            let names = outfit.items.prefix(2).map { $0.name }.joined(separator: "، ")
            label += ": \(names)"
        }
        
        return label
    }
    
    // MARK: - Load Outfits
    private func loadOutfits() {
        guard let userId = currentUserId else { return }
        let db = Firestore.firestore()
        
        db.collection("outfits")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error loading outfits: \(error.localizedDescription)")
                    self.isLoading = false
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.isLoading = false
                    return
                }
                
                self.outfits = documents.compactMap { doc -> Outfit? in
                    try? doc.data(as: Outfit.self)
                }
                
                self.isLoading = false
            }
    }
    
    // MARK: - Select Outfit
    private func selectOutfit(_ outfit: Outfit) {
        isProcessingOutfit = true
        
        // تأخير صغير لإظهار المؤشر
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // تحويل الـ outfit إلى صورة
            let canvasSize = CGSize(width: 350, height: 400)
            let renderer = UIGraphicsImageRenderer(size: canvasSize)
            
            let image = renderer.image { context in
                // خلفية بيضاء
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: canvasSize))
                
                // رسم كل قطعة
                for item in outfit.items {
                    if let urlString = item.localImageURLString,
                       let url = URL(string: urlString),
                       let imageData = try? Data(contentsOf: url),
                       let itemImage = UIImage(data: imageData) {
                        
                        let itemSize = CGSize(
                            width: item.size.width * item.scale,
                            height: item.size.height * item.scale
                        )
                        
                        let itemRect = CGRect(
                            x: item.position.x - itemSize.width / 2,
                            y: item.position.y - itemSize.height / 2,
                            width: itemSize.width,
                            height: itemSize.height
                        )
                        
                        itemImage.draw(in: itemRect)
                    }
                }
            }
            
            self.onOutfitSelected(outfit, image)
            self.isProcessingOutfit = false
            self.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - بطاقة اختيار الإطلالة
struct OutfitSelectionCard: View {
    let outfit: Outfit
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
            
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
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                            case .empty:
                                ProgressView()
                            @unknown default:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
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
                    }
                }
            }
        }
        .frame(height: 220)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Preview
struct SelectOutfitView_Previews: PreviewProvider {
    static var previews: some View {
        SelectOutfitView(onOutfitSelected: { _, _ in })
            .environment(\.layoutDirection, .rightToLeft)
    }
}
