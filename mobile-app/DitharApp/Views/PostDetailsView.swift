//
//  PostDetailsView.swift
//  DitharApp
//
//  صفحة تفاصيل المنشور - مع عرض أفقي للقطع المستخدمة
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct PostDetailsView: View {
    let postId: String
    
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var communityService = CommunityService()
    @EnvironmentObject var authManager: AuthenticationManager

    @State private var post: CommunityPost?
    @State private var comments: [PostComment] = []
    @State private var newCommentText = ""
    @State private var isLoading = true
    @State private var isPostingComment = false
    @State private var showDeleteAlert = false
    @State private var userData: [String: Any]?
    @State private var userPhotoURL: String?
    @State private var showLikesList = false
    
    @FocusState private var isCommentFieldFocused: Bool
    
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    private var isMyPost: Bool {
        guard let userId = currentUserId, let post = post else { return false }
        return post.userId == userId
    }
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            if let post = post {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        
                        // MARK: - Header
                        HStack(spacing: 12) {
                            AvatarView(displayName: post.userFullName ?? post.username, urlString: post.userPhotoURL, size: 44)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(post.userFullName ?? post.username)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text(formatDate(post.createdAt))
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        
                        Divider().padding(.horizontal, 0)
                        
                        // MARK: - صورة المنشور
                        AsyncImage(url: URL(string: post.imageURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxHeight: 400)
                                .clipped()
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(ProgressView())
                        }
                        .frame(maxWidth: .infinity)
                        
                        // MARK: - الوصف
                        if !post.description.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(post.description)
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        
                        Divider().padding(.horizontal, 20)
                        
                        // MARK: - القطع المرتبطة
                        if !post.linkedItems.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(post.linkedItems, id: \.id) { item in
                                            LinkedItemCardHorizontal(item: item, showBookmark: !isMyPost)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                                .padding(.horizontal, -20)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                        }
                        
                        // MARK: - الأيقونات (لايك + كومنت)
                        HStack(spacing: 20) {
                            Spacer()
                            
                            // ✅ تم إصلاح مشكلة Button داخل Button
                            HStack(spacing: 6) {
                                Button(action: toggleLike) {
                                    Image(systemName: post.isLikedByCurrentUser ? "heart.fill" : "heart")
                                        .font(.system(size: 18))
                                        .foregroundColor(post.isLikedByCurrentUser ? .red : .gray)
                                }
                                
                                Button(action: {
                                    if isMyPost && post.likesCount > 0 {
                                        showLikesList = true
                                    }
                                }) {
                                    Text("\(post.likesCount)")
                                        .font(.system(size: 15))
                                        .foregroundColor(
                                            isMyPost && post.likesCount > 0
                                            ? Color(red: 0.47, green: 0.58, blue: 0.44)
                                            : .gray
                                        )
                                }
                                .disabled(!(isMyPost && post.likesCount > 0))
                            }
                            
                            HStack(spacing: 6) {
                                Image(systemName: "message")
                                    .font(.system(size: 18))
                                    .foregroundColor(.gray)
                                Text("\(post.commentsCount)")
                                    .font(.system(size: 15))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 12)
                        
                        // MARK: - التعليقات
                        VStack(alignment: .leading, spacing: 12) {
                            Text("التعليقات")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            if comments.isEmpty {
                                Text("لا توجد تعليقات بعد")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .padding(.vertical, 20)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                ForEach(comments) { comment in
                                    CommentRow(comment: comment)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                    }
                    // ✅ بدل padding ثابت، نخليه منطقي لأننا بنستخدم safeAreaInset
                    .padding(.bottom, 8)
                }
                
                // ✅ سحب السكروول ينزل الكيبورد
                .scrollDismissesKeyboard(.interactively)
                
                // ✅ الضغط بأي مكان ينزل الكيبورد
                .contentShape(Rectangle())
                .onTapGesture {
                    isCommentFieldFocused = false
                    hideKeyboard()
                }
                
                // ✅ أهم جزء: البار ينحط في safeAreaInset ويرتفع تلقائيًا مع الكيبورد
                .safeAreaInset(edge: .bottom) {
                    commentBar
                }
                
            } else {
                ProgressView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        
        // ✅ زر "تم" فوق الكيبورد
        .toolbar {

            
            ToolbarItem(placement: .navigationBarLeading) {
                if isMyPost {
                    Button(action: { showDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(.red)
                            .frame(width: 36, height: 36)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
        }
        
        .alert("حذف المنشور", isPresented: $showDeleteAlert) {
            Button("إلغاء", role: .cancel) {}
            Button("حذف", role: .destructive) { deletePost() }
        } message: {
            Text("هل أنت متأكد من حذف هذا المنشور؟")
        }
        
        .sheet(isPresented: $showLikesList) {
            if let post = post {
                LikesListView(postId: post.id)
            }
        }
        
        .onAppear {
            loadPost()
            loadComments()
            loadUserData()
        }
        
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
    }
    
    // MARK: - Comment Bar (Bottom)
    private var commentBar: some View {
        HStack(spacing: 12) {
            AvatarView(displayName: "", urlString: userPhotoURL, size: 36)
            
            TextField("اكتب تعليقاً...", text: $newCommentText, axis: .vertical)
                .font(.system(size: 15))
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(20)
                .lineLimit(1...4)
                .multilineTextAlignment(.leading)
                .focused($isCommentFieldFocused)
                .submitLabel(.send)              // ✅ يظهر زر Send/Return
                .onSubmit {                      // ✅ الضغط على Send يرسل
                    postComment()
                }
            
            Button(action: postComment) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color.gray.opacity(0.5)
                        : Color(red: 0.47, green: 0.58, blue: 0.44)
                    )
                    .clipShape(Circle())
            }
            .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPostingComment)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            Color.white
                .shadow(.drop(color: .black.opacity(0.1), radius: 5, y: -5))
        )
    }
    
    // MARK: - وظائف البيانات
    
    private func loadPost() {
        guard let userId = currentUserId else { return }
        let db = Firestore.firestore()
        
        db.collection("community_posts").document(postId).getDocument { document, error in
            if let error = error {
                print("❌ خطأ في جلب المنشور: \(error.localizedDescription)")
                DispatchQueue.main.async { self.isLoading = false }
                return
            }
            guard let document = document, document.exists else {
                DispatchQueue.main.async { self.isLoading = false }
                return
            }
            
            guard var post = CommunityPost.fromDocument(document, currentUserId: userId) else {
                DispatchQueue.main.async { self.isLoading = false }
                return
            }
            
            db.collection("post_likes")
                .whereField("userId", isEqualTo: userId)
                .whereField("postId", isEqualTo: self.postId)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("❌ خطأ في فحص حالة اللايك: \(error.localizedDescription)")
                    } else {
                        post.isLikedByCurrentUser = !(snapshot?.documents.isEmpty ?? true)
                    }
                    DispatchQueue.main.async {
                        self.post = post
                        self.isLoading = false
                    }
                }
        }
    }
    
    private func loadComments() {
        communityService.fetchComments(postId: postId) { comments in
            self.comments = comments
        }
    }
    
    private func toggleLike() {
        guard let userId = currentUserId, var post = post else { return }
        
        let wasLiked = post.isLikedByCurrentUser
        
        post.isLikedByCurrentUser.toggle()
        post.likesCount += post.isLikedByCurrentUser ? 1 : -1
        self.post = post
        
        communityService.toggleLike(
            postId: postId,
            userId: userId,
            postOwnerId: post.userId,
            postImageURL: post.imageURL
        ) { isLiked in
            if isLiked != post.isLikedByCurrentUser {
                var revertedPost = post
                revertedPost.isLikedByCurrentUser = wasLiked
                revertedPost.likesCount += wasLiked ? 1 : -1
                self.post = revertedPost
            }
        }
    }
    
    private func postComment() {
        guard let userId = currentUserId else { return }
        let text = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard !isPostingComment else { return }
        
        isPostingComment = true
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { document, error in
            let userData = document?.data()
            let username = (userData?["username"] as? String) ?? "مستخدم"
            let userFullName = userData?["fullName"] as? String
            let userPhotoURL = userData?["photoURL"] as? String
            
            self.communityService.addComment(
                postId: self.postId,
                userId: userId,
                username: username,
                userFullName: userFullName,
                userPhotoURL: userPhotoURL,
                text: text
            ) { success in
                self.isPostingComment = false
                if success {
                    self.newCommentText = ""
                    self.isCommentFieldFocused = false
                    hideKeyboard()
                    
                    if var post = self.post {
                        post.commentsCount += 1
                        self.post = post
                    }
                    self.loadComments()
                }
            }
        }
    }
    
    private func deletePost() {
        guard let userId = currentUserId else { return }
        communityService.deletePost(postId: postId, userId: userId) { success in
            if success {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ar")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func loadUserData() {
        Task {
            userData = await authManager.getUserData()
            userPhotoURL = userData?["photoURL"] as? String
            isLoading = false
        }
    }
}

// MARK: - Helpers (إغلاق الكيبورد)
private func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                    to: nil, from: nil, for: nil)
}

// MARK: - قائمة المعجبين
struct LikesListView: View {
    let postId: String
    
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var communityService = CommunityService()
    @State private var likeUsers: [LikeUser] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.white.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                } else if likeUsers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("لا توجد إعجابات")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(likeUsers) { user in
                                LikeUserRow(user: user)
                                if user.id != likeUsers.last?.id {
                                    Divider().padding(.horizontal, 20)
                                }
                            }
                        }
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("الإعجابات")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("تم") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.47, green: 0.58, blue: 0.44))
                }
            }
        }
        .onAppear { loadLikes() }
        .environment(\.layoutDirection, .rightToLeft)
    }
    
    private func loadLikes() {
        print("🔍 Loading likes for post: \(postId)")
        communityService.fetchPostLikes(postId: postId) { users in
            print("📊 Received \(users.count) users from service")
            self.likeUsers = users
            self.isLoading = false
        }
    }
}

// MARK: - صف المستخدم المعجب
struct LikeUserRow: View {
    let user: LikeUser
    
    var body: some View {
        HStack(spacing: 12) {
            AvatarView(
                displayName: user.userFullName ?? user.username,
                urlString: user.userPhotoURL,
                size: 44
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.userFullName ?? user.username)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("@\(user.username)")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - صف التعليق
struct CommentRow: View {
    let comment: PostComment
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(displayName: comment.username, urlString: comment.userPhotoURL, size: 36)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(comment.username)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(formatDate(comment.createdAt))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                Text(comment.text)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ar")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct PostDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PostDetailsView(postId: "sample_post_id")
        }
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
    }
}
