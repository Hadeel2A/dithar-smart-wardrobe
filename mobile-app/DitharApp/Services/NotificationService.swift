//
//  NotificationService.swift
//  DitharApp
//
//  خدمة Firebase لإدارة الإشعارات - إشعارات داخل التطبيق فقط (بدون Push Notifications)
//

import Foundation
import FirebaseFirestore
import Combine

class NotificationService: ObservableObject {
    
    private let db = Firestore.firestore()
    
    // MARK: - Collections
    private let notificationsCollection = "notifications"
    private let usersCollection = "users"
    
    // MARK: - Published Properties
    @Published var unreadCount: Int = 0
    @Published var notifications: [AppNotification] = []
    
    // Listener للإشعارات الحية
    private var notificationsListener: ListenerRegistration?
    
    // MARK: - التحقق من إعدادات الإشعارات للمستخدم
    /// التحقق من أن المستخدم فعّل الإشعارات
    private func checkUserNotificationSettings(userId: String, completion: @escaping (Bool) -> Void) {
        db.collection(usersCollection).document(userId).getDocument { document, error in
            if let error = error {
                print("❌ خطأ في جلب إعدادات الإشعارات: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            let data = document?.data()
            let isEnabled = data?["notificationsEnabled"] as? Bool ?? true // ✅ افتراضي: مفعّل
            
            print("ℹ️ حالة الإشعارات للمستخدم \(userId): \(isEnabled ? "مفعّلة" : "معطّلة")")
            
            completion(isEnabled)
        }
    }
    
    // MARK: - ==================== إشعارات المنشورات ====================
    
    // MARK: - إرسال إشعار إعجاب
    func sendLikeNotification(
        postId: String,
        postOwnerId: String,
        postImageURL: String,
        fromUserId: String,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard postOwnerId != fromUserId else {
            completion?(false)
            return
        }
        
        checkUserNotificationSettings(userId: postOwnerId) { isEnabled in
            guard isEnabled else {
                print("ℹ️ المستخدم عطّل الإشعارات")
                completion?(false)
                return
            }
            
            self.createLikeNotification(
                postId: postId,
                postOwnerId: postOwnerId,
                postImageURL: postImageURL,
                fromUserId: fromUserId,
                completion: completion
            )
        }
    }
    
    private func createLikeNotification(
        postId: String,
        postOwnerId: String,
        postImageURL: String,
        fromUserId: String,
        completion: ((Bool) -> Void)? = nil
    ) {
        db.collection(usersCollection).document(fromUserId).getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ خطأ في جلب معلومات المستخدم: \(error.localizedDescription)")
                completion?(false)
                return
            }
            
            let userData = document?.data()
            let username = (userData?["username"] as? String) ?? "مستخدم"
            let userFullName = userData?["fullName"] as? String
            let userPhotoURL = userData?["photoURL"] as? String
            
            self.db.collection(self.notificationsCollection)
                .whereField("userId", isEqualTo: postOwnerId)
                .whereField("postId", isEqualTo: postId)
                .whereField("fromUserId", isEqualTo: fromUserId)
                .whereField("type", isEqualTo: NotificationType.like.rawValue)
                .getDocuments { snapshot, error in
                    
                    if let existingDoc = snapshot?.documents.first {
                        existingDoc.reference.updateData([
                            "createdAt": Timestamp(date: Date()),
                            "isRead": false
                        ]) { error in
                            if let error = error {
                                print("❌ خطأ في تحديث الإشعار: \(error.localizedDescription)")
                                completion?(false)
                            } else {
                                print("✅ تم تحديث إشعار الإعجاب")
                                completion?(true)
                            }
                        }
                    } else {
                        let notification = AppNotification(
                            userId: postOwnerId,
                            type: .like,
                            postId: postId,
                            fromUserId: fromUserId,
                            fromUsername: username,
                            fromUserFullName: userFullName,
                            fromUserPhotoURL: userPhotoURL,
                            postImageURL: postImageURL
                        )
                        
                        self.db.collection(self.notificationsCollection)
                            .document(notification.id)
                            .setData(notification.toDictionary()) { error in
                                if let error = error {
                                    print("❌ خطأ في إرسال إشعار الإعجاب: \(error.localizedDescription)")
                                    completion?(false)
                                } else {
                                    print("✅ تم إرسال إشعار الإعجاب")
                                    completion?(true)
                                }
                            }
                    }
                }
        }
    }
    
    // MARK: - إرسال إشعار تعليق
    func sendCommentNotification(
        postId: String,
        postOwnerId: String,
        postImageURL: String,
        fromUserId: String,
        commentText: String,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard postOwnerId != fromUserId else {
            completion?(false)
            return
        }
        
        checkUserNotificationSettings(userId: postOwnerId) { isEnabled in
            guard isEnabled else {
                print("ℹ️ المستخدم عطّل الإشعارات")
                completion?(false)
                return
            }
            
            self.createCommentNotification(
                postId: postId,
                postOwnerId: postOwnerId,
                postImageURL: postImageURL,
                fromUserId: fromUserId,
                commentText: commentText,
                completion: completion
            )
        }
    }
    
    private func createCommentNotification(
        postId: String,
        postOwnerId: String,
        postImageURL: String,
        fromUserId: String,
        commentText: String,
        completion: ((Bool) -> Void)? = nil
    ) {
        db.collection(usersCollection).document(fromUserId).getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ خطأ في جلب معلومات المستخدم: \(error.localizedDescription)")
                completion?(false)
                return
            }
            
            let userData = document?.data()
            let username = (userData?["username"] as? String) ?? "مستخدم"
            let userFullName = userData?["fullName"] as? String
            let userPhotoURL = userData?["photoURL"] as? String
            
            let notification = AppNotification(
                userId: postOwnerId,
                type: .comment,
                postId: postId,
                fromUserId: fromUserId,
                fromUsername: username,
                fromUserFullName: userFullName,
                fromUserPhotoURL: userPhotoURL,
                postImageURL: postImageURL,
                commentText: commentText
            )
            
            self.db.collection(self.notificationsCollection)
                .document(notification.id)
                .setData(notification.toDictionary()) { error in
                    if let error = error {
                        print("❌ خطأ في إرسال إشعار التعليق: \(error.localizedDescription)")
                        completion?(false)
                    } else {
                        print("✅ تم إرسال إشعار التعليق")
                        completion?(true)
                    }
                }
        }
    }
    
    // MARK: - حذف إشعار إعجاب (عند إلغاء الإعجاب)
    func removeLikeNotification(
        postId: String,
        postOwnerId: String,
        fromUserId: String
    ) {
        db.collection(notificationsCollection)
            .whereField("userId", isEqualTo: postOwnerId)
            .whereField("postId", isEqualTo: postId)
            .whereField("fromUserId", isEqualTo: fromUserId)
            .whereField("type", isEqualTo: NotificationType.like.rawValue)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ خطأ في البحث عن إشعار الإعجاب: \(error.localizedDescription)")
                    return
                }
                
                snapshot?.documents.forEach { document in
                    document.reference.delete { error in
                        if let error = error {
                            print("❌ خطأ في حذف إشعار الإعجاب: \(error.localizedDescription)")
                        } else {
                            print("✅ تم حذف إشعار الإعجاب")
                        }
                    }
                }
            }
    }
    
    // MARK: - ==================== إشعارات الخزانة ====================
    
    /// إرسال إشعار عند تغيير حالة القطعة (داخل/خارج الخزانة)
    func sendClothingStatusChangeNotification(
        userId: String,
        clothingItemId: String,
        clothingItemName: String?,
        clothingItemCategory: String?,
        clothingItemColor: String?,
        clothingItemImageURL: String?,
        isOutside: Bool,
        completion: ((Bool) -> Void)? = nil
    ) {
        checkUserNotificationSettings(userId: userId) { isEnabled in
            guard isEnabled else {
                print("ℹ️ المستخدم عطّل الإشعارات")
                completion?(false)
                return
            }
            
            // ✅ Build descriptive name from category and color
            var itemDescription = ""
            if let category = clothingItemCategory, !category.isEmpty {
                itemDescription = category
            }
            if let color = clothingItemColor, !color.isEmpty {
                if !itemDescription.isEmpty {
                    itemDescription += " \(color)"
                } else {
                    itemDescription = color
                }
            }
            if itemDescription.isEmpty {
                itemDescription = "قطعة ملابس"
            }
            
            let notification = AppNotification(
                userId: userId,
                type: .clothingStatusChange,
                clothingItemId: clothingItemId,
                clothingItemName: itemDescription, // ✅ Use the built description
                clothingItemCategory: clothingItemCategory,
                clothingItemImageURL: clothingItemImageURL,
                isOutside: isOutside
            )
            
            self.db.collection(self.notificationsCollection)
                .document(notification.id)
                .setData(notification.toDictionary()) { error in
                    if let error = error {
                        print("❌ خطأ في إرسال إشعار تغيير حالة القطعة: \(error.localizedDescription)")
                        completion?(false)
                    } else {
                        print("✅ تم إرسال إشعار تغيير حالة القطعة")
                        completion?(true)
                    }
                }
        }
    }
    
    // MARK: - ==================== إشعارات المناسبات ====================
    
    /// إرسال إشعار تذكير بمناسبة قادمة
    func sendEventReminderNotification(
        userId: String,
        eventId: String,
        eventTitle: String,
        eventDate: Date,
        eventTime: Date?,
        eventOutfitId: String?,
        completion: ((Bool) -> Void)? = nil
    ) {
        checkUserNotificationSettings(userId: userId) { isEnabled in
            guard isEnabled else {
                print("ℹ️ المستخدم عطّل الإشعارات")
                completion?(false)
                return
            }
            
            let notification = AppNotification(
                userId: userId,
                type: .eventReminder,
                eventId: eventId,
                eventTitle: eventTitle,
                eventDate: eventDate,
                eventTime: eventTime,
                eventOutfitId: eventOutfitId
            )
            
            self.db.collection(self.notificationsCollection)
                .document(notification.id)
                .setData(notification.toDictionary()) { error in
                    if let error = error {
                        print("❌ خطأ في إرسال إشعار تذكير المناسبة: \(error.localizedDescription)")
                        completion?(false)
                    } else {
                        print("✅ تم إرسال إشعار تذكير المناسبة")
                        completion?(true)
                    }
                }
        }
    }
    
    // MARK: - ==================== عمليات عامة ====================
    
    // MARK: - جلب الإشعارات
    func fetchNotifications(userId: String, completion: @escaping ([AppNotification]) -> Void) {
        db.collection(notificationsCollection)
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ خطأ في جلب الإشعارات: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                let notifications = snapshot?.documents.compactMap { AppNotification.fromDocument($0) } ?? []
                completion(notifications)
            }
    }
    
    // MARK: - الاستماع للإشعارات الحية
    func startListeningToNotifications(userId: String) {
        stopListeningToNotifications()
        
        notificationsListener = db.collection(notificationsCollection)
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ خطأ في الاستماع للإشعارات: \(error.localizedDescription)")
                    return
                }
                
                let notifications = snapshot?.documents.compactMap { AppNotification.fromDocument($0) } ?? []
                
                DispatchQueue.main.async {
                    self.notifications = notifications
                    self.unreadCount = notifications.filter { !$0.isRead }.count
                }
            }
    }
    
    // MARK: - إيقاف الاستماع
    func stopListeningToNotifications() {
        notificationsListener?.remove()
        notificationsListener = nil
    }
    
    // MARK: - تحديث حالة القراءة
    func markAsRead(notificationId: String, completion: ((Bool) -> Void)? = nil) {
        db.collection(notificationsCollection)
            .document(notificationId)
            .updateData(["isRead": true]) { error in
                if let error = error {
                    print("❌ خطأ في تحديث حالة الإشعار: \(error.localizedDescription)")
                    completion?(false)
                } else {
                    print("✅ تم تحديث حالة الإشعار")
                    completion?(true)
                }
            }
    }
    
    // MARK: - تحديد جميع الإشعارات كمقروءة
    func markAllAsRead(userId: String, completion: ((Bool) -> Void)? = nil) {
        db.collection(notificationsCollection)
            .whereField("userId", isEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ خطأ في جلب الإشعارات غير المقروءة: \(error.localizedDescription)")
                    completion?(false)
                    return
                }
                
                let batch = self.db.batch()
                snapshot?.documents.forEach { document in
                    batch.updateData(["isRead": true], forDocument: document.reference)
                }
                
                batch.commit { error in
                    if let error = error {
                        print("❌ خطأ في تحديث الإشعارات: \(error.localizedDescription)")
                        completion?(false)
                    } else {
                        print("✅ تم تحديث جميع الإشعارات")
                        completion?(true)
                    }
                }
            }
    }
    
    // MARK: - حذف إشعار
    func deleteNotification(notificationId: String, completion: ((Bool) -> Void)? = nil) {
        db.collection(notificationsCollection)
            .document(notificationId)
            .delete { error in
                if let error = error {
                    print("❌ خطأ في حذف الإشعار: \(error.localizedDescription)")
                    completion?(false)
                } else {
                    print("✅ تم حذف الإشعار")
                    completion?(true)
                }
            }
    }
    
    // MARK: - حذف جميع الإشعارات
    func deleteAllNotifications(userId: String, completion: ((Bool) -> Void)? = nil) {
        db.collection(notificationsCollection)
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ خطأ في جلب الإشعارات للحذف: \(error.localizedDescription)")
                    completion?(false)
                    return
                }
                
                let batch = self.db.batch()
                snapshot?.documents.forEach { document in
                    batch.deleteDocument(document.reference)
                }
                
                batch.commit { error in
                    if let error = error {
                        print("❌ خطأ في حذف الإشعارات: \(error.localizedDescription)")
                        completion?(false)
                    } else {
                        print("✅ تم حذف جميع الإشعارات")
                        completion?(true)
                    }
                }
            }
    }
    
    // MARK: - حساب عدد الإشعارات غير المقروءة
    func fetchUnreadCount(userId: String, completion: @escaping (Int) -> Void) {
        db.collection(notificationsCollection)
            .whereField("userId", isEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ خطأ في حساب الإشعارات غير المقروءة: \(error.localizedDescription)")
                    completion(0)
                    return
                }
                
                let count = snapshot?.documents.count ?? 0
                completion(count)
            }
    }
}
