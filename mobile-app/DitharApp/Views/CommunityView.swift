//
//  CommunityView.swift
//  DitharApp
//
//  الشاشة الرئيسية للكميونتي - مع نظام الإشعارات
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth



struct CommunityView: View {
    @StateObject private var communityService = CommunityService()
    @StateObject private var notificationService = NotificationService() //
    
    @State private var selectedTab: CommunityTab = .all
    @State private var allPosts: [CommunityPost] = []
    @State private var myPosts: [CommunityPost] = []
    @State private var isLoading = true
    @State private var showAddPost = false
    @State private var userData: [String: Any]?
    @State private var userPhotoURL: String?
    
    @State private var selectedPostId: String?
    @State private var showNotifications = false //
    private let lightGreenBackground = Color(red: 0.91, green: 0.93, blue: 0.88)
    private let darkGreenIcon = Color(red: 0.35, green: 0.45, blue: 0.32)
    private let lightGreenButton = Color(red: 0.91, green: 0.93, blue: 0.88)
    enum CommunityTab: String, CaseIterable {
        case all = "المجتمع"
        case myPosts = "منشوراتي"
    }
    
    private var currentUserId: String? {            //
        Auth.auth().currentUser?.uid
    }
    
    private var displayFullName: String {
        (userData?["fullName"] as? String) ??
        (userData?["name"] as? String) ?? ""
    }
    
    private var displayUsername: String {
        (userData?["username"] as? String) ?? ""
    }
    
    private var displayBio: String {
        (userData?["bio"] as? String) ?? ""
    }
    
    private var currentPosts: [CommunityPost] {
        selectedTab == .all ? allPosts : myPosts
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
                    HStack(spacing: 12) {
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
                        
                        NavigationLink {
                            WishListView()
                        } label: {
                            Image(systemName: "bookmark")
                                .font(.system(size: 22))
                                .foregroundColor(darkGreenIcon)
                                .frame(width: 40, height: 40)
                                .background(Color.white)
                                .cornerRadius(20)
                                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("قائمة الأمنيات")
                        
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
                                        .offset(x: 6, y: -6)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("الإشعارات")
                        
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
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("الإعدادات")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                    
                    // MARK: - تبويبات
                    HStack(spacing: 0) {
                        ForEach(CommunityTab.allCases, id: \.self) { tab in
                            Button(action: { selectedTab = tab }) {
                                VStack(spacing: 4) {
                                    Text(tab.rawValue)
                                        .font(.system(size: 16, weight: selectedTab == tab ? .semibold : .regular))
                                        .foregroundColor(
                                            selectedTab == tab
                                            ? Color(red: 0.47, green: 0.58, blue: 0.44)
                                            : .gray
                                        )

                                    if selectedTab == tab {
                                        Capsule()
                                            .fill(Color(red: 0.47, green: 0.58, blue: 0.44))
                                            .frame(height: 3)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)      // 👈 هذا السطر المهم
                    .padding(.bottom, 12)
                    
                    // MARK: - محتوى التبويبات
                    if isLoading {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if currentPosts.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 48))
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Text(selectedTab == .all ? "لا توجد منشورات" : "لم تنشر أي منشورات بعد")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                ForEach(currentPosts) { post in
                                    Button(action: {
                                        self.selectedPostId = post.id
                                    }) {
                                        PostCardView(
                                            post: post,
                                            onLike: {
                                                toggleLike(post: post)
                                            },
                                            onTap: {}
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .padding(.bottom, 80)
                        }
                        .refreshable {
                            loadPosts()
                        }
                    }
                }
                
                // MARK: - زر الإضافة العائم (محدث)
                VStack {
                    Spacer()
                    HStack {
                        Button(action: { showAddPost = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color(red: 0.47, green: 0.58, blue: 0.44))
                                .cornerRadius(28)
                                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .padding(.leading, 20)
                        .padding(.bottom, 100)
                        
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddPost, onDismiss: {
                loadPosts()
            }) {
                AddCommunityPostView()
            }
            .sheet(item: $selectedPostId) { postId in
                NavigationStack {
                    PostDetailsView(postId: postId)
                }
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
                loadPosts()
                
                // بدء الاستماع للإشعارات
                if let userId = currentUserId {
                    notificationService.startListeningToNotifications(userId: userId)
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "ar"))
        }
    }
    
    private func loadUserData() {
        guard let userId = currentUserId else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { document, error in
            if let document = document, document.exists {
                self.userData = document.data()
                self.userPhotoURL = userData?["photoURL"] as? String
            }
        }
    }
    
    private func loadPosts() {
        guard let userId = currentUserId else { return }
        
        isLoading = true
        
        communityService.fetchAllPosts(currentUserId: userId) { posts in
            self.allPosts = posts
            self.isLoading = false
        }
        
        communityService.fetchUserPosts(userId: userId, currentUserId: userId) { posts in
            self.myPosts = posts
        }
    }
    
    private func toggleLike(post: CommunityPost) {
        guard let userId = currentUserId else { return }
        
        // تحديث محلي فوري
        let wasLiked = post.isLikedByCurrentUser
        
        if let index = allPosts.firstIndex(where: { $0.id == post.id }) {
            allPosts[index].isLikedByCurrentUser.toggle()
            allPosts[index].likesCount += allPosts[index].isLikedByCurrentUser ? 1 : -1
        }
        
        if let index = myPosts.firstIndex(where: { $0.id == post.id }) {
            myPosts[index].isLikedByCurrentUser.toggle()
            myPosts[index].likesCount += myPosts[index].isLikedByCurrentUser ? 1 : -1
        }
        
        // تنفيذ العملية في Firebase مع إرسال إشعار
        communityService.toggleLike(
            postId: post.id,
            userId: userId,
            postOwnerId: post.userId,
            postImageURL: post.imageURL
        ) { isLiked in
            // في حالة الفشل، نعيد القيم
            if isLiked != !wasLiked {
                if let index = allPosts.firstIndex(where: { $0.id == post.id }) {
                    allPosts[index].isLikedByCurrentUser = wasLiked
                    allPosts[index].likesCount += wasLiked ? 1 : -1
                }
                
                if let index = myPosts.firstIndex(where: { $0.id == post.id }) {
                    myPosts[index].isLikedByCurrentUser = wasLiked
                    myPosts[index].likesCount += wasLiked ? 1 : -1
                }
            }
        }
    }
}

// MARK: - Preview
struct CommunityView_Previews: PreviewProvider {
    static var previews: some View {
        CommunityView()
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "ar"))
    }
}

// --- التعديل الوحيد: إضافة هذا السطر لحل المشكلة ---
extension String: Identifiable {
    public var id: String { self }
}
