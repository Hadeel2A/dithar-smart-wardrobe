//
//  CommunityPost.swift
//  DitharApp
//
//  نموذج بيانات المنشور في الكميونتي
//  ⚠️ هذا منفصل تماماً عن ClothingItem (قطع الدولاب)
//

import Foundation
import FirebaseFirestore

// MARK: - نموذج المنشور في الكميونتي
struct CommunityPost: Identifiable, Codable {
    let id: String
    let userId: String
    let username: String
    let userFullName: String?
    let userPhotoURL: String?
    let imageURL: String                    // صورة التنسيقة الكاملة
    let description: String                 // وصف الإطلالة
    let linkedItems: [LinkedClothingItem]   // القطع المستخدمة (اختياري)
    var likesCount: Int
    var commentsCount: Int
    let createdAt: Date
    var isLikedByCurrentUser: Bool          // للعرض فقط (لا يُحفظ في Firebase)
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case username
        case userFullName
        case userPhotoURL
        case imageURL
        case description
        case linkedItems
        case likesCount
        case commentsCount
        case createdAt
        // isLikedByCurrentUser لا يُحفظ في Firebase
    }
    
    // MARK: - Decodable Implementation
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        username = try container.decode(String.self, forKey: .username)
        userFullName = try container.decodeIfPresent(String.self, forKey: .userFullName)
        userPhotoURL = try container.decodeIfPresent(String.self, forKey: .userPhotoURL)
        imageURL = try container.decode(String.self, forKey: .imageURL)
        description = try container.decode(String.self, forKey: .description)
        linkedItems = try container.decode([LinkedClothingItem].self, forKey: .linkedItems)
        likesCount = try container.decode(Int.self, forKey: .likesCount)
        commentsCount = try container.decode(Int.self, forKey: .commentsCount)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        
        // isLikedByCurrentUser لا يأتي من Decoder
        isLikedByCurrentUser = false
    }
    
    // تحويل من Firestore Document
    static func fromDocument(_ document: DocumentSnapshot, currentUserId: String) -> CommunityPost? {
        guard let data = document.data() else { return nil }
        
        let id = document.documentID
        let userId = data["userId"] as? String ?? ""
        let username = data["username"] as? String ?? ""
        let userFullName = data["userFullName"] as? String
        let userPhotoURL = data["userPhotoURL"] as? String
        let imageURL = data["imageURL"] as? String ?? ""
        let description = data["description"] as? String ?? ""
        let likesCount = data["likesCount"] as? Int ?? 0
        let commentsCount = data["commentsCount"] as? Int ?? 0
        
        // تحويل التاريخ
        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }
        
        // تحويل القطع المرتبطة
        let linkedItems: [LinkedClothingItem]
        if let itemsData = data["linkedItems"] as? [[String: Any]] {
            linkedItems = itemsData.compactMap { LinkedClothingItem(dictionary: $0) }
        } else {
            linkedItems = []
        }
        
        return CommunityPost(
            id: id,
            userId: userId,
            username: username,
            userFullName: userFullName,
            userPhotoURL: userPhotoURL,
            imageURL: imageURL,
            description: description,
            linkedItems: linkedItems,
            likesCount: likesCount,
            commentsCount: commentsCount,
            createdAt: createdAt,
            isLikedByCurrentUser: false
        )
    }
    
    // مُنشئ عادي
    init(
        id: String = UUID().uuidString,
        userId: String,
        username: String,
        userFullName: String? = nil,
        userPhotoURL: String? = nil,
        imageURL: String,
        description: String,
        linkedItems: [LinkedClothingItem] = [],
        likesCount: Int = 0,
        commentsCount: Int = 0,
        createdAt: Date = Date(),
        isLikedByCurrentUser: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.username = username
        self.userFullName = userFullName
        self.userPhotoURL = userPhotoURL
        self.imageURL = imageURL
        self.description = description
        self.linkedItems = linkedItems
        self.likesCount = likesCount
        self.commentsCount = commentsCount
        self.createdAt = createdAt
        self.isLikedByCurrentUser = isLikedByCurrentUser
    }
    
    // تحويل إلى Dictionary للحفظ في Firebase
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "userId": userId,
            "username": username,
            "imageURL": imageURL,
            "description": description,
            "likesCount": likesCount,
            "commentsCount": commentsCount,
            "createdAt": Timestamp(date: createdAt)
        ]
        
        if let fullName = userFullName {
            dict["userFullName"] = fullName
        }
        
        if let photoURL = userPhotoURL {
            dict["userPhotoURL"] = photoURL
        }
        
        if !linkedItems.isEmpty {
            dict["linkedItems"] = linkedItems.map { $0.toDictionary() }
        }
        
        return dict
    }
}

// MARK: - نموذج القطعة المرتبطة بالمنشور
// ⚠️ هذا مختلف عن ClothingItem - فقط للعرض في المنشور
struct LinkedClothingItem: Identifiable, Codable {
    let id: String              // معرف القطعة الأصلية في الدولاب
    let category: String        // نوع القطعة (معطف، بنطال، إلخ)
    let color: String?          // لون القطعة
    let imageURL: String        // رابط صورة القطعة
    let purchaseLink: String?   // رابط الشراء (اختياري)
    
    // مُنشئ عادي
    init(
        id: String,
        category: String,
        color: String?,
        imageURL: String,
        purchaseLink: String? = nil
    ) {
        self.id = id
        self.category = category
        self.color = color
        self.imageURL = imageURL
        self.purchaseLink = purchaseLink
    }
    
    // تحويل من Dictionary
    init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let category = dictionary["category"] as? String,
              let imageURL = dictionary["imageURL"] as? String else {
            return nil
        }
        
        self.id = id
        self.category = category
        self.color = dictionary["color"] as? String
        self.imageURL = imageURL
        self.purchaseLink = dictionary["purchaseLink"] as? String
    }
    
    // تحويل إلى Dictionary
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "category": category,
            "imageURL": imageURL
        ]
        
        if let color = color {
            dict["color"] = color
        }
        
        if let link = purchaseLink {
            dict["purchaseLink"] = link
        }
        
        return dict
    }
}

// MARK: - نموذج التعليق على المنشور
struct PostComment: Identifiable, Codable {
    let id: String
    let postId: String
    let userId: String
    let username: String
    let userFullName: String?
    let userPhotoURL: String?
    let text: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case postId
        case userId
        case username
        case userFullName
        case userPhotoURL
        case text
        case createdAt
    }
    
    // MARK: - Decodable Implementation
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        postId = try container.decode(String.self, forKey: .postId)
        userId = try container.decode(String.self, forKey: .userId)
        username = try container.decode(String.self, forKey: .username)
        userFullName = try container.decodeIfPresent(String.self, forKey: .userFullName)
        userPhotoURL = try container.decodeIfPresent(String.self, forKey: .userPhotoURL)
        text = try container.decode(String.self, forKey: .text)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
    
    // تحويل من Firestore Document
    static func fromDocument(_ document: DocumentSnapshot) -> PostComment? {
        guard let data = document.data() else { return nil }
        
        let id = document.documentID
        let postId = data["postId"] as? String ?? ""
        let userId = data["userId"] as? String ?? ""
        let username = data["username"] as? String ?? ""
        let userFullName = data["userFullName"] as? String
        let userPhotoURL = data["userPhotoURL"] as? String
        let text = data["text"] as? String ?? ""
        
        // تحويل التاريخ
        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }
        
        return PostComment(
            id: id,
            postId: postId,
            userId: userId,
            username: username,
            userFullName: userFullName,
            userPhotoURL: userPhotoURL,
            text: text,
            createdAt: createdAt
        )
    }
    
    // مُنشئ عادي
    init(
        id: String = UUID().uuidString,
        postId: String,
        userId: String,
        username: String,
        userFullName: String? = nil,
        userPhotoURL: String? = nil,
        text: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.postId = postId
        self.userId = userId
        self.username = username
        self.userFullName = userFullName
        self.userPhotoURL = userPhotoURL
        self.text = text
        self.createdAt = createdAt
    }
    
    // تحويل إلى Dictionary للحفظ في Firebase
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "postId": postId,
            "userId": userId,
            "username": username,
            "text": text,
            "createdAt": Timestamp(date: createdAt)
        ]
        
        if let fullName = userFullName {
            dict["userFullName"] = fullName
        }
        
        if let photoURL = userPhotoURL {
            dict["userPhotoURL"] = photoURL
        }
        
        return dict
    }
}

// MARK: - نموذج الإعجاب (للتتبع الداخلي)
struct PostLike: Identifiable, Codable {
    let id: String
    let postId: String
    let userId: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case postId
        case userId
        case createdAt
    }
    
    // MARK: - Decodable Implementation
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        postId = try container.decode(String.self, forKey: .postId)
        userId = try container.decode(String.self, forKey: .userId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
    
    // تحويل من Firestore Document
    static func fromDocument(_ document: DocumentSnapshot) -> PostLike? {
        guard let data = document.data() else { return nil }
        
        let id = document.documentID
        let postId = data["postId"] as? String ?? ""
        let userId = data["userId"] as? String ?? ""
        
        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }
        
        return PostLike(
            id: id,
            postId: postId,
            userId: userId,
            createdAt: createdAt
        )
    }
    
    // مُنشئ عادي
    init(
        id: String = UUID().uuidString,
        postId: String,
        userId: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.postId = postId
        self.userId = userId
        self.createdAt = createdAt
    }
    
    // تحويل إلى Dictionary
    func toDictionary() -> [String: Any] {
        return [
            "postId": postId,
            "userId": userId,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
}

// MARK: - نموذج بيانات المستخدم المعجب
struct LikeUser: Identifiable {
    let id: String
    let username: String
    let userFullName: String?
    let userPhotoURL: String?
    
    static func fromDocument(_ document: DocumentSnapshot) -> LikeUser? {
        guard let data = document.data() else { return nil }
        
        return LikeUser(
            id: document.documentID,
            username: data["username"] as? String ?? "مستخدم",
            userFullName: data["fullName"] as? String,
            userPhotoURL: data["photoURL"] as? String
        )
    }
}
