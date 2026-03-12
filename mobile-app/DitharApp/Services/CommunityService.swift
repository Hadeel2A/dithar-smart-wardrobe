//
//  CommunityService.swift
//  DitharApp
//
//  خدمة Firebase لإدارة المنشورات والتعليقات في الكميونتي
//  ⚠️ منفصلة تماماً عن خدمات الدولاب
//  ✅ مع دعم الإشعارات
//

import Foundation
import FirebaseFirestore
import FirebaseStorage

class CommunityService: ObservableObject {
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private let notificationService = NotificationService()
    
    // MARK: - Collections
    private let postsCollection = "community_posts"
    private let likesCollection = "post_likes"
    private let commentsCollection = "post_comments"
    
    // MARK: - جلب جميع المنشورات
    /// جلب المنشورات من الكميونتي مع ترتيبها من الأحدث للأقدم
    func fetchAllPosts(currentUserId: String, completion: @escaping ([CommunityPost]) -> Void) {
        db.collection(postsCollection)
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ خطأ في جلب المنشورات: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                
                let posts = documents.compactMap { CommunityPost.fromDocument($0, currentUserId: currentUserId) }
                
                // التحقق من الإعجابات للمستخدم الحالي
                self.checkLikesForPosts(posts: posts, userId: currentUserId) { updatedPosts in
                    completion(updatedPosts)
                }
            }
    }
    
    // MARK: - جلب منشورات مستخدم معين
    /// جلب المنشورات الخاصة بمستخدم محدد
    func fetchUserPosts(userId: String, currentUserId: String, completion: @escaping ([CommunityPost]) -> Void) {
        print("ℹ️ جلب منشورات المستخدم: \(userId)")
        db.collection(postsCollection)
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ خطأ في جلب منشورات المستخدم: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                
                let posts = documents.compactMap { CommunityPost.fromDocument($0, currentUserId: currentUserId) }
                print("✅ تم جلب \(documents.count) مستند و\(posts.count) منشور للمستخدم")
                
                // التحقق من الإعجابات
                self.checkLikesForPosts(posts: posts, userId: currentUserId) { updatedPosts in
                    print("✅ تم إرجاع \(updatedPosts.count) منشور للمستخدم")
                    completion(updatedPosts)
                }
            }
    }
    
    // MARK: - التحقق من الإعجابات
    /// التحقق من المنشورات التي أعجب بها المستخدم الحالي
    private func checkLikesForPosts(posts: [CommunityPost], userId: String, completion: @escaping ([CommunityPost]) -> Void) {
        guard !posts.isEmpty else {
            completion(posts)
            return
        }
        
        let postIds = posts.map { $0.id }
        
        db.collection(likesCollection)
            .whereField("userId", isEqualTo: userId)
            .whereField("postId", in: postIds)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ خطأ في جلب الإعجابات: \(error.localizedDescription)")
                    completion(posts)
                    return
                }
                
                let likedPostIds = Set(snapshot?.documents.compactMap { $0.data()["postId"] as? String } ?? [])
                
                var updatedPosts = posts
                for i in 0..<updatedPosts.count {
                    updatedPosts[i].isLikedByCurrentUser = likedPostIds.contains(updatedPosts[i].id)
                }
                
                completion(updatedPosts)
            }
    }
    
    // MARK: - جلب المستخدمين الذين أعجبوا بالمنشور
    /// جلب قائمة المستخدمين الذين أعجبوا بمنشور معين
    func fetchPostLikes(postId: String, completion: @escaping ([LikeUser]) -> Void) {
        print("🔍 Fetching likes for post: \(postId)")
        
        // جلب الإعجابات أولاً
        db.collection(likesCollection)
            .whereField("postId", isEqualTo: postId)
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ خطأ في جلب الإعجابات: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("⚠️ لا توجد إعجابات لهذا المنشور")
                    completion([])
                    return
                }
                
                print("✅ Found \(documents.count) likes")
                
                let userIds = documents.compactMap { $0.data()["userId"] as? String }
                
                guard !userIds.isEmpty else {
                    print("⚠️ لا توجد معرفات مستخدمين في الإعجابات")
                    completion([])
                    return
                }
                
                print("🔍 Fetching user details for \(userIds.count) users")
                
                // جلب معلومات المستخدمين في دفعات (Firebase تسمح بـ 10 معرفات فقط في الاستعلام)
                self.fetchUsersInBatches(userIds: userIds) { users in
                    // ترتيب المستخدمين حسب ترتيب الإعجابات
                    let sortedUsers = userIds.compactMap { userId in
                        users.first { $0.id == userId }
                    }
                    
                    print("✅ Returning \(sortedUsers.count) users")
                    completion(sortedUsers)
                }
            }
    }
    
    // MARK: - جلب معلومات المستخدمين في دفعات
    private func fetchUsersInBatches(userIds: [String], completion: @escaping ([LikeUser]) -> Void) {
        var allUsers: [LikeUser] = []
        let batchSize = 10
        let batches = stride(from: 0, to: userIds.count, by: batchSize).map {
            Array(userIds[$0..<min($0 + batchSize, userIds.count)])
        }
        
        let dispatchGroup = DispatchGroup()
        
        for batch in batches {
            dispatchGroup.enter()
            
            db.collection("users")
                .whereField(FieldPath.documentID(), in: batch)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("❌ خطأ في جلب دفعة من المستخدمين: \(error.localizedDescription)")
                    } else {
                        let users = snapshot?.documents.compactMap { LikeUser.fromDocument($0) } ?? []
                        allUsers.append(contentsOf: users)
                        print("✅ Fetched \(users.count) users in this batch")
                    }
                    dispatchGroup.leave()
                }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(allUsers)
        }
    }
    
    // MARK: - إضافة منشور جديد
    /// إضافة منشور جديد للكميونتي
    func createPost(
        userId: String,
        username: String,
        userFullName: String?,
        userPhotoURL: String?,
        image: UIImage,
        description: String,
        linkedItems: [LinkedClothingItem],
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // 1. رفع الصورة إلى Storage
        uploadPostImage(image: image, userId: userId) { result in
            switch result {
            case .success(let imageURL):
                // 2. إنشاء المنشور في Firestore
                let post = CommunityPost(
                    userId: userId,
                    username: username,
                    userFullName: userFullName,
                    userPhotoURL: userPhotoURL,
                    imageURL: imageURL,
                    description: description,
                    linkedItems: linkedItems
                )
                
                let docRef = self.db.collection(self.postsCollection).document(post.id)
                
                docRef.setData(post.toDictionary()) { error in
                    if let error = error {
                        print("❌ خطأ في حفظ المنشور: \(error.localizedDescription)")
                        completion(.failure(error))
                    } else {
                        print("✅ تم نشر المنشور بنجاح!")
                        completion(.success(post.id))
                    }
                }
                
            case .failure(let error):
                print("❌ خطأ في رفع الصورة: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - رفع صورة المنشور
    /// رفع صورة التنسيقة إلى Firebase Storage
    private func uploadPostImage(image: UIImage, userId: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(NSError(domain: "CommunityService", code: -1, userInfo: [NSLocalizedDescriptionKey: "فشل تحويل الصورة"])))
            return
        }
        
        let filename = "\(UUID().uuidString).jpg"
        let storageRef = storage.reference().child("community_posts/\(userId)/\(filename)")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        storageRef.putData(imageData, metadata: metadata) { metadata, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            storageRef.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                } else if let url = url {
                    completion(.success(url.absoluteString))
                }
            }
        }
    }
    
    // MARK: - الإعجاب بمنشور (مع الإشعارات)
    /// إضافة أو إزالة إعجاب على منشور مع إرسال إشعار
    func toggleLike(
        postId: String,
        userId: String,
        postOwnerId: String,
        postImageURL: String,
        completion: @escaping (Bool) -> Void
    ) {
        // البحث عن الإعجاب الحالي
        db.collection(likesCollection)
            .whereField("postId", isEqualTo: postId)
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ خطأ في التحقق من الإعجاب: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                if let document = snapshot?.documents.first {
                    // الإعجاب موجود - إزالته
                    document.reference.delete { error in
                        if let error = error {
                            print("❌ خطأ في إزالة الإعجاب: \(error.localizedDescription)")
                            completion(false)
                        } else {
                            // تقليل عدد الإعجابات
                            self.updateLikesCount(postId: postId, increment: false)
                            
                            // حذف إشعار الإعجاب
                            self.notificationService.removeLikeNotification(
                                postId: postId,
                                postOwnerId: postOwnerId,
                                fromUserId: userId
                            )
                            
                            completion(false)
                        }
                    }
                } else {
                    // الإعجاب غير موجود - إضافته
                    let like = PostLike(postId: postId, userId: userId)
                    self.db.collection(self.likesCollection).document(like.id).setData(like.toDictionary()) { error in
                        if let error = error {
                            print("❌ خطأ في إضافة الإعجاب: \(error.localizedDescription)")
                            completion(false)
                        } else {
                            // زيادة عدد الإعجابات
                            self.updateLikesCount(postId: postId, increment: true)
                            
                            // إرسال إشعار الإعجاب
                            self.notificationService.sendLikeNotification(
                                postId: postId,
                                postOwnerId: postOwnerId,
                                postImageURL: postImageURL,
                                fromUserId: userId
                            )
                            
                            completion(true)
                        }
                    }
                }
            }
    }
    
    // MARK: - تحديث عدد الإعجابات
    /// تحديث عداد الإعجابات في المنشور
    private func updateLikesCount(postId: String, increment: Bool) {
        let postRef = db.collection(postsCollection).document(postId)
        postRef.updateData([
            "likesCount": FieldValue.increment(Int64(increment ? 1 : -1))
        ])
    }
    
    // MARK: - جلب التعليقات
    /// جلب تعليقات منشور معين
    func fetchComments(postId: String, completion: @escaping ([PostComment]) -> Void) {
        db.collection(commentsCollection)
            .whereField("postId", isEqualTo: postId)
            .order(by: "createdAt", descending: false)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ خطأ في جلب التعليقات: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                let comments = snapshot?.documents.compactMap { PostComment.fromDocument($0) } ?? []
                completion(comments)
            }
    }
    
    // MARK: - إضافة تعليق (مع الإشعارات)
    /// إضافة تعليق جديد على منشور مع إرسال إشعار
    func addComment(
        postId: String,
        userId: String,
        username: String,
        userFullName: String?,
        userPhotoURL: String?,
        text: String,
        completion: @escaping (Bool) -> Void
    ) {
        let comment = PostComment(
            postId: postId,
            userId: userId,
            username: username,
            userFullName: userFullName,
            userPhotoURL: userPhotoURL,
            text: text
        )
        
        db.collection(commentsCollection).document(comment.id).setData(comment.toDictionary()) { error in
            if let error = error {
                print("❌ خطأ في إضافة التعليق: \(error.localizedDescription)")
                completion(false)
            } else {
                // زيادة عدد التعليقات
                self.updateCommentsCount(postId: postId, increment: true)
                
                // جلب معلومات المنشور لإرسال الإشعار
                self.db.collection(self.postsCollection).document(postId).getDocument { document, error in
                    if let data = document?.data(),
                       let postOwnerId = data["userId"] as? String,
                       let postImageURL = data["imageURL"] as? String {
                        
                        // إرسال إشعار التعليق
                        self.notificationService.sendCommentNotification(
                            postId: postId,
                            postOwnerId: postOwnerId,
                            postImageURL: postImageURL,
                            fromUserId: userId,
                            commentText: text
                        )
                    }
                }
                
                completion(true)
            }
        }
    }
    
    // MARK: - تحديث عدد التعليقات
    /// تحديث عداد التعليقات في المنشور
    private func updateCommentsCount(postId: String, increment: Bool) {
        let postRef = db.collection(postsCollection).document(postId)
        postRef.updateData([
            "commentsCount": FieldValue.increment(Int64(increment ? 1 : -1))
        ])
    }
    
    // MARK: - حذف منشور
    /// حذف منشور (للمالك فقط)
    func deletePost(postId: String, userId: String, completion: @escaping (Bool) -> Void) {
        let postRef = db.collection(postsCollection).document(postId)
        
        // التحقق من أن المستخدم هو المالك
        postRef.getDocument { document, error in
            if let error = error {
                print("❌ خطأ في جلب المنشور: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let data = document?.data(),
                  let ownerId = data["userId"] as? String,
                  ownerId == userId else {
                print("❌ المستخدم ليس مالك المنشور")
                completion(false)
                return
            }
            
            // حذف المنشور
            postRef.delete { error in
                if let error = error {
                    print("❌ خطأ في حذف المنشور: \(error.localizedDescription)")
                    completion(false)
                } else {
                    // حذف الإعجابات والتعليقات المرتبطة
                    self.deletePostRelatedData(postId: postId)
                    completion(true)
                }
            }
        }
    }
    
    // MARK: - حذف البيانات المرتبطة بالمنشور
    /// حذف الإعجابات والتعليقات عند حذف المنشور
    private func deletePostRelatedData(postId: String) {
        // حذف الإعجابات
        db.collection(likesCollection)
            .whereField("postId", isEqualTo: postId)
            .getDocuments { snapshot, _ in
                snapshot?.documents.forEach { $0.reference.delete() }
            }
        
        // حذف التعليقات
        db.collection(commentsCollection)
            .whereField("postId", isEqualTo: postId)
            .getDocuments { snapshot, _ in
                snapshot?.documents.forEach { $0.reference.delete() }
            }
    }
    
    // MARK: - جلب منشور واحد
    /// جلب تفاصيل منشور محدد
    func fetchPost(postId: String, currentUserId: String, completion: @escaping (CommunityPost?) -> Void) {
        db.collection(postsCollection).document(postId).getDocument { document, error in
            if let error = error {
                print("❌ خطأ في جلب المنشور: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let document = document, var post = CommunityPost.fromDocument(document, currentUserId: currentUserId) else {
                completion(nil)
                return
            }
            
            // التحقق من الإعجاب
            self.db.collection(self.likesCollection)
                .whereField("postId", isEqualTo: postId)
                .whereField("userId", isEqualTo: currentUserId)
                .getDocuments { snapshot, _ in
                    post.isLikedByCurrentUser = !(snapshot?.documents.isEmpty ?? true)
                    completion(post)
                }
        }
    }
}
