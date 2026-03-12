//
//  AppNotification.swift
//  DitharApp
//
//  نموذج بيانات الإشعارات في التطبيق - محدث مع إشعارات الخزانة والمناسبات
//

import Foundation
import FirebaseFirestore

// MARK: - نوع الإشعار
enum NotificationType: String, Codable {
    case like = "like"                          // إعجاب بالمنشور
    case comment = "comment"                    // تعليق على المنشور
    case clothingStatusChange = "clothingStatusChange"  // ✅ تغيير حالة القطعة (داخل/خارج)
    case eventReminder = "eventReminder"        // ✅ تذكير بمناسبة قادمة
}

// MARK: - نموذج الإشعار
struct AppNotification: Identifiable, Codable {
    let id: String
    let userId: String              // المستخدم المستقبل للإشعار
    let type: NotificationType      // نوع الإشعار
    
    // ✅ حقول المنشورات (للإعجاب والتعليق)
    let postId: String?             // معرف المنشور (اختياري الآن)
    let fromUserId: String?         // المستخدم المرسل (اختياري الآن)
    let fromUsername: String?       // اسم المستخدم المرسل
    let fromUserFullName: String?   // الاسم الكامل للمرسل
    let fromUserPhotoURL: String?   // صورة المرسل
    let postImageURL: String?       // صورة المنشور (للعرض في الإشعار)
    let commentText: String?        // نص التعليق
    
    // ✅ حقول جديدة للخزانة والمناسبات
    let clothingItemId: String?     // معرف القطعة (للخزانة)
    let clothingItemName: String?   // اسم القطعة
    let clothingItemCategory: String? // فئة القطعة
    let clothingItemImageURL: String? // صورة القطعة
    let isOutside: Bool?            // حالة القطعة (خارج/داخل)
    
    let eventId: String?            // معرف الحدث (للمناسبات)
    let eventTitle: String?         // عنوان المناسبة
    let eventDate: Date?            // تاريخ المناسبة
    let eventTime: Date?            // وقت المناسبة (اختياري)
    let eventOutfitId: String?      // معرف الإطلالة المرتبطة
    
    var isRead: Bool                // هل تم قراءة الإشعار؟
    let createdAt: Date             // تاريخ الإشعار
    
    enum CodingKeys: String, CodingKey {
        case id, userId, type
        case postId, fromUserId, fromUsername, fromUserFullName, fromUserPhotoURL, postImageURL, commentText
        case clothingItemId, clothingItemName, clothingItemCategory, clothingItemImageURL, isOutside
        case eventId, eventTitle, eventDate, eventTime, eventOutfitId
        case isRead, createdAt
    }
    
    // MARK: - Decodable Implementation
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        
        let typeString = try container.decode(String.self, forKey: .type)
        type = NotificationType(rawValue: typeString) ?? .like
        
        // حقول المنشورات
        postId = try container.decodeIfPresent(String.self, forKey: .postId)
        fromUserId = try container.decodeIfPresent(String.self, forKey: .fromUserId)
        fromUsername = try container.decodeIfPresent(String.self, forKey: .fromUsername)
        fromUserFullName = try container.decodeIfPresent(String.self, forKey: .fromUserFullName)
        fromUserPhotoURL = try container.decodeIfPresent(String.self, forKey: .fromUserPhotoURL)
        postImageURL = try container.decodeIfPresent(String.self, forKey: .postImageURL)
        commentText = try container.decodeIfPresent(String.self, forKey: .commentText)
        
        // حقول الخزانة
        clothingItemId = try container.decodeIfPresent(String.self, forKey: .clothingItemId)
        clothingItemName = try container.decodeIfPresent(String.self, forKey: .clothingItemName)
        clothingItemCategory = try container.decodeIfPresent(String.self, forKey: .clothingItemCategory)
        clothingItemImageURL = try container.decodeIfPresent(String.self, forKey: .clothingItemImageURL)
        isOutside = try container.decodeIfPresent(Bool.self, forKey: .isOutside)
        
        // حقول المناسبات
        eventId = try container.decodeIfPresent(String.self, forKey: .eventId)
        eventTitle = try container.decodeIfPresent(String.self, forKey: .eventTitle)
        eventDate = try container.decodeIfPresent(Date.self, forKey: .eventDate)
        eventTime = try container.decodeIfPresent(Date.self, forKey: .eventTime)
        eventOutfitId = try container.decodeIfPresent(String.self, forKey: .eventOutfitId)
        
        isRead = try container.decode(Bool.self, forKey: .isRead)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
    
    // MARK: - تحويل من Firestore Document
    static func fromDocument(_ document: DocumentSnapshot) -> AppNotification? {
        guard let data = document.data() else { return nil }
        
        let id = document.documentID
        let userId = data["userId"] as? String ?? ""
        let typeString = data["type"] as? String ?? "like"
        let type = NotificationType(rawValue: typeString) ?? .like
        
        // حقول المنشورات
        let postId = data["postId"] as? String
        let fromUserId = data["fromUserId"] as? String
        let fromUsername = data["fromUsername"] as? String
        let fromUserFullName = data["fromUserFullName"] as? String
        let fromUserPhotoURL = data["fromUserPhotoURL"] as? String
        let postImageURL = data["postImageURL"] as? String
        let commentText = data["commentText"] as? String
        
        // حقول الخزانة
        let clothingItemId = data["clothingItemId"] as? String
        let clothingItemName = data["clothingItemName"] as? String
        let clothingItemCategory = data["clothingItemCategory"] as? String
        let clothingItemImageURL = data["clothingItemImageURL"] as? String
        let isOutside = data["isOutside"] as? Bool
        
        // حقول المناسبات
        let eventId = data["eventId"] as? String
        let eventTitle = data["eventTitle"] as? String
        let eventDate: Date? = {
            if let ts = data["eventDate"] as? Timestamp {
                return ts.dateValue()
            }
            return nil
        }()
        let eventTime: Date? = {
            if let ts = data["eventTime"] as? Timestamp {
                return ts.dateValue()
            }
            return nil
        }()
        let eventOutfitId = data["eventOutfitId"] as? String
        
        let isRead = data["isRead"] as? Bool ?? false
        
        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }
        
        return AppNotification(
            id: id,
            userId: userId,
            type: type,
            postId: postId,
            fromUserId: fromUserId,
            fromUsername: fromUsername,
            fromUserFullName: fromUserFullName,
            fromUserPhotoURL: fromUserPhotoURL,
            postImageURL: postImageURL,
            commentText: commentText,
            clothingItemId: clothingItemId,
            clothingItemName: clothingItemName,
            clothingItemCategory: clothingItemCategory,
            clothingItemImageURL: clothingItemImageURL,
            isOutside: isOutside,
            eventId: eventId,
            eventTitle: eventTitle,
            eventDate: eventDate,
            eventTime: eventTime,
            eventOutfitId: eventOutfitId,
            isRead: isRead,
            createdAt: createdAt
        )
    }
    
    // MARK: - مُنشئ عادي
    init(
        id: String = UUID().uuidString,
        userId: String,
        type: NotificationType,
        postId: String? = nil,
        fromUserId: String? = nil,
        fromUsername: String? = nil,
        fromUserFullName: String? = nil,
        fromUserPhotoURL: String? = nil,
        postImageURL: String? = nil,
        commentText: String? = nil,
        clothingItemId: String? = nil,
        clothingItemName: String? = nil,
        clothingItemCategory: String? = nil,
        clothingItemImageURL: String? = nil,
        isOutside: Bool? = nil,
        eventId: String? = nil,
        eventTitle: String? = nil,
        eventDate: Date? = nil,
        eventTime: Date? = nil,
        eventOutfitId: String? = nil,
        isRead: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.postId = postId
        self.fromUserId = fromUserId
        self.fromUsername = fromUsername
        self.fromUserFullName = fromUserFullName
        self.fromUserPhotoURL = fromUserPhotoURL
        self.postImageURL = postImageURL
        self.commentText = commentText
        self.clothingItemId = clothingItemId
        self.clothingItemName = clothingItemName
        self.clothingItemCategory = clothingItemCategory
        self.clothingItemImageURL = clothingItemImageURL
        self.isOutside = isOutside
        self.eventId = eventId
        self.eventTitle = eventTitle
        self.eventDate = eventDate
        self.eventTime = eventTime
        self.eventOutfitId = eventOutfitId
        self.isRead = isRead
        self.createdAt = createdAt
    }
    
    // MARK: - تحويل إلى Dictionary للحفظ في Firebase
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "userId": userId,
            "type": type.rawValue,
            "isRead": isRead,
            "createdAt": Timestamp(date: createdAt)
        ]
        
        // حقول المنشورات
        if let postId = postId { dict["postId"] = postId }
        if let fromUserId = fromUserId { dict["fromUserId"] = fromUserId }
        if let fromUsername = fromUsername { dict["fromUsername"] = fromUsername }
        if let fromUserFullName = fromUserFullName { dict["fromUserFullName"] = fromUserFullName }
        if let fromUserPhotoURL = fromUserPhotoURL { dict["fromUserPhotoURL"] = fromUserPhotoURL }
        if let postImageURL = postImageURL { dict["postImageURL"] = postImageURL }
        if let commentText = commentText { dict["commentText"] = commentText }
        
        // حقول الخزانة
        if let clothingItemId = clothingItemId { dict["clothingItemId"] = clothingItemId }
        if let clothingItemName = clothingItemName { dict["clothingItemName"] = clothingItemName }
        if let clothingItemCategory = clothingItemCategory { dict["clothingItemCategory"] = clothingItemCategory }
        if let clothingItemImageURL = clothingItemImageURL { dict["clothingItemImageURL"] = clothingItemImageURL }
        if let isOutside = isOutside { dict["isOutside"] = isOutside }
        
        // حقول المناسبات
        if let eventId = eventId { dict["eventId"] = eventId }
        if let eventTitle = eventTitle { dict["eventTitle"] = eventTitle }
        if let eventDate = eventDate { dict["eventDate"] = Timestamp(date: eventDate) }
        if let eventTime = eventTime { dict["eventTime"] = Timestamp(date: eventTime) }
        if let eventOutfitId = eventOutfitId { dict["eventOutfitId"] = eventOutfitId }
        
        return dict
    }
    
    // MARK: - Helper Methods
    
    /// الحصول على نص الإشعار
    var notificationText: String {
        switch type {
        case .like:
            let displayName = fromUserFullName ?? fromUsername ?? "مستخدم"
            return "أعجب \(displayName) بمنشورك"
            
        case .comment:
            let displayName = fromUserFullName ?? fromUsername ?? "مستخدم"
            if let text = commentText, !text.isEmpty {
                return "علّق \(displayName): \(text)"
            } else {
                return "علّق \(displayName) على منشورك"
            }
            
        case .clothingStatusChange:
            let itemName = clothingItemName ?? clothingItemCategory ?? "قطعة ملابس"
            if let isOutside = isOutside {
                return isOutside ? "\(itemName) خارج الخزانة" : "\(itemName) داخل الخزانة"
            }
            return "تغيرت حالة \(itemName)"
            
        case .eventReminder:
            let title = eventTitle ?? "مناسبة"
            if let eventDate = eventDate {
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                let targetDay = calendar.startOfDay(for: eventDate)
                
                let daysUntil = calendar.dateComponents([.day], from: today, to: targetDay).day ?? 0
                
                if daysUntil == 0 {
                    return "تذكير: \(title) اليوم!"
                } else if daysUntil == 1 {
                    return "تذكير: \(title) غداً"
                } else if daysUntil == 2 {
                    return "تذكير: \(title) بعد يومين"
                } else if daysUntil > 2 {
                    return "تذكير: \(title) بعد \(daysUntil) أيام"
                } else if daysUntil < 0 {
                    // في حالة أن الحدث فات
                    return "تذكير: \(title) (منتهي)"
                }
            }
            return "تذكير بـ \(title)"
        }
    }
    
    /// أيقونة الإشعار
    var icon: String {
        switch type {
        case .like:
            return "heart.fill"
        case .comment:
            return "message.fill"
        case .clothingStatusChange:
            return isOutside == true ? "arrow.up.forward.square.fill" : "arrow.down.backward.square.fill"
        case .eventReminder:
            return "calendar.badge.clock"
        }
    }
    
    /// لون الأيقونة
    var iconColor: String {
        switch type {
        case .like:
            return "red"
        case .comment:
            return "blue"
        case .clothingStatusChange:
            return isOutside == true ? "orange" : "green"
        case .eventReminder:
            return "purple"
        }
    }
}
