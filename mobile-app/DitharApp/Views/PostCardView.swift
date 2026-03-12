//
//  PostCardView.swift
//  DitharApp
//
//  بطاقة المنشور في شبكة الكميونتي
//  ✨ مع صورة المستخدم محسّنة + أزرار اللايك والتعليقات
//

import SwiftUI

struct PostCardView: View {
    let post: CommunityPost
    let onLike: () -> Void
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // الصورة الرئيسية للمنشور
            AsyncImage(url: URL(string: post.imageURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        ProgressView()
                    )
            }
            .frame(height: 140)
            .clipped()
            
            // معلومات المنشور
            VStack(alignment: .leading, spacing: 6) {
                // الصف العلوي: معلومات الناشر
                HStack(spacing: 6) {
                    
                    // صورة المستخدم
                    AvatarView(
                        displayName: post.userFullName ?? post.username,
                        urlString: post.userPhotoURL,
                        size: 28
                    )
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(post.userFullName ?? post.username)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        // عرض الوصف إذا كان موجوداً
                        if !post.description.isEmpty {
                            Text(post.description)
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    }
                    Spacer()

                }
                
                // الصف السفلي: أزرار اللايك والتعليقات
                HStack(spacing: 16) {
                    // زر اللايك
                    Button(action: {
                        onLike()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: post.isLikedByCurrentUser ? "heart.fill" : "heart")
                                .font(.system(size: 16))
                                .foregroundColor(post.isLikedByCurrentUser ? .red : Color(red: 0.35, green: 0.45, blue: 0.32))
                            
                            Text("\(post.likesCount)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("إعجاب")
                    
                    // زر التعليقات
                    Button(action: {
                        onTap()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "message")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                            
                            Text("\(post.commentsCount)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("التعليقات")
                    
                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(10)
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Preview
struct PostCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // منشور بصورة مستخدم
            PostCardView(
                post: CommunityPost(
                    id: "1",
                    userId: "user1",
                    username: "sara_style",
                    userFullName: "سارة أحمد",
                    userPhotoURL: nil,
                    imageURL: "",
                    description: "إطلالة خريفية مريحة 🍂",
                    linkedItems: [],
                    likesCount: 127,
                    commentsCount: 23,
                    createdAt: Date(),
                    isLikedByCurrentUser: true
                ),
                onLike: {},
                onTap: {}
            )
            .frame(width: 160)
            
            // منشور بدون صورة مستخدم
            PostCardView(
                post: CommunityPost(
                    id: "2",
                    userId: "user2",
                    username: "fashionista",
                    userFullName: nil,
                    userPhotoURL: nil,
                    imageURL: "",
                    description: "ستايل كلاسيكي",
                    linkedItems: [],
                    likesCount: 45,
                    commentsCount: 8,
                    createdAt: Date(),
                    isLikedByCurrentUser: false
                ),
                onLike: {},
                onTap: {}
            )
            .frame(width: 160)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .environment(\.layoutDirection, .rightToLeft)
    }
}
