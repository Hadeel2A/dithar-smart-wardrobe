//
//  NotificationsView.swift
//  DitharApp
//
//  شاشة عرض الإشعارات - محدثة مع أنواع الإشعارات الجديدة
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct NotificationsView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var notificationService = NotificationService()
    
    @State private var notifications: [AppNotification] = []
    @State private var isLoading = true
    @State private var selectedPostId: String?
    @State private var selectedClothingItemId: String?
    @State private var selectedEventId: String?
    @State private var showDeleteAlert = false
    @State private var notificationsEnabled = true
    @State private var showPostDetails = false
    @State private var showClothingDetails = false
    
    private var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: - الشريط العلوي
                    HStack {
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                        }
                        
                        Spacer()
                        
                        Text("الإشعارات")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Menu {
                            Button(action: markAllAsRead) {
                                Label("تحديد الكل كمقروء", systemImage: "checkmark.circle")
                            }
                            
                            Button(role: .destructive, action: { showDeleteAlert = true }) {
                                Label("حذف جميع الإشعارات", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    
                    Divider()
                    
                    // MARK: - المحتوى
                    if isLoading {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if !notificationsEnabled {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "bell.slash")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Text("الإشعارات معطلة")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("فعل الإشعارات من الإعدادات")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            
                            NavigationLink(destination: SettingsView()) {
                                Text("اذهب للإعدادات")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color(red: 0.47, green: 0.58, blue: 0.44))
                                    .cornerRadius(25)
                            }
                        }
                        Spacer()
                    } else if notifications.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "bell.slash")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Text("لا توجد إشعارات")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                            
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(notifications) { notification in
                                    NotificationRow(
                                        notification: notification,
                                        onTap: {
                                            handleNotificationTap(notification)
                                        },
                                        onDelete: {
                                            deleteNotification(notification.id)
                                        }
                                    )
                                    
                                    Divider()
                                        .padding(.leading, 80)
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showPostDetails) {
                if let postId = selectedPostId {
                    NavigationStack {
                        PostDetailsView(postId: postId)
                    }
                }
            }
            .sheet(isPresented: $showClothingDetails) {
                if let itemId = selectedClothingItemId {
                    NavigationStack {
                        ClothingItemDetailsView(clothingItemId: itemId)
                    }
                }
            }
            .alert("حذف جميع الإشعارات", isPresented: $showDeleteAlert) {
                Button("إلغاء", role: .cancel) {}
                Button("حذف", role: .destructive) {
                    deleteAllNotifications()
                }
            } message: {
                Text("هل أنت متأكد من حذف جميع الإشعارات؟")
            }
            .onAppear {
                checkNotificationSettings()
                loadNotifications()
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
    
    // MARK: - الوظائف
    
    private func checkNotificationSettings() {
        guard let userId = currentUserId else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { document, error in
            if let data = document?.data() {
                self.notificationsEnabled = data["notificationsEnabled"] as? Bool ?? false
            } else {
                self.notificationsEnabled = false
            }
            
            print("🔔 حالة الإشعارات للمستخدم \(userId): \(self.notificationsEnabled ? "مفعّلة" : "معطّلة")")
        }
    }
    
    private func loadNotifications() {
        guard let userId = currentUserId else { return }
        guard notificationsEnabled else {
            isLoading = false
            return
        }
        
        isLoading = true
        notificationService.fetchNotifications(userId: userId) { fetchedNotifications in
            self.notifications = fetchedNotifications
            self.isLoading = false
        }
    }
    
    private func handleNotificationTap(_ notification: AppNotification) {
        // تحديد الإشعار كمقروء
        if !notification.isRead {
            notificationService.markAsRead(notificationId: notification.id)
            
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                notifications[index].isRead = true
            }
        }
        
        // التنقل حسب نوع الإشعار
        switch notification.type {
        case .like, .comment:
            if let postId = notification.postId {
                selectedPostId = postId
                showPostDetails = true
            }
            
        case .clothingStatusChange:
            if let itemId = notification.clothingItemId {
                selectedClothingItemId = itemId
                showClothingDetails = true
            }
            
        case .eventReminder:
            // التنقل إلى صفحة التقويم
            // يمكن إضافة logic للتنقل للحدث المحدد
            print("📍 التنقل إلى التقويم")
        }
    }
    
    private func markAllAsRead() {
        guard let userId = currentUserId else { return }
        
        notificationService.markAllAsRead(userId: userId) { success in
            if success {
                for i in 0..<notifications.count {
                    notifications[i].isRead = true
                }
            }
        }
    }
    
    private func deleteNotification(_ notificationId: String) {
        notificationService.deleteNotification(notificationId: notificationId) { success in
            if success {
                notifications.removeAll { $0.id == notificationId }
            }
        }
    }
    
    private func deleteAllNotifications() {
        guard let userId = currentUserId else { return }
        
        notificationService.deleteAllNotifications(userId: userId) { success in
            if success {
                notifications.removeAll()
            }
        }
    }
}

// MARK: - صف الإشعار
struct NotificationRow: View {
    let notification: AppNotification
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // صورة أو أيقونة حسب نوع الإشعار
                notificationImage
                
                // محتوى الإشعار
                VStack(alignment: .leading, spacing: 6) {
                    Text(notification.notificationText)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                    
                    Text(formatDate(notification.createdAt))
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // صورة المنشور/القطعة
                thumbnailImage
                
                // نقطة غير مقروء
                if !notification.isRead {
                    Circle()
                        .fill(Color(red: 0.47, green: 0.58, blue: 0.44))
                        .frame(width: 10, height: 10)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(notification.isRead ? Color.clear : Color.gray.opacity(0.05))
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("حذف الإشعار", systemImage: "trash")
            }
        }
    }
    
    @ViewBuilder
    private var notificationImage: some View {
        switch notification.type {
        case .like, .comment:
            // صورة المستخدم مع أيقونة نوع الإشعار
            ZStack(alignment: .bottomTrailing) {
                AvatarView(
                    displayName: notification.fromUserFullName ?? notification.fromUsername ?? "مستخدم",
                    urlString: notification.fromUserPhotoURL,
                    size: 50
                )
                
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: notification.icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(notification.type == .like ? .red : .blue)
                }
                .offset(x: 2, y: 2)
            }
            
        case .clothingStatusChange:
            // أيقونة القطعة
            ZStack {
                Circle()
                    .fill(Color(red: 0.91, green: 0.93, blue: 0.88))
                    .frame(width: 50, height: 50)
                
                Image(systemName: notification.icon)
                    .font(.system(size: 24))
                    .foregroundColor(notification.isOutside == true ? .orange : Color(red: 0.47, green: 0.58, blue: 0.44))
            }
            
        case .eventReminder:
            // أيقونة المناسبة
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: notification.icon)
                    .font(.system(size: 24))
                    .foregroundColor(.purple)
            }
        }
    }
    
    @ViewBuilder
    private var thumbnailImage: some View {
        switch notification.type {
        case .like, .comment:
            if let imageURL = notification.postImageURL {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
        case .clothingStatusChange:
            if let imageURL = notification.clothingItemImageURL {
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
        case .eventReminder:
            EmptyView()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ar")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview
struct NotificationsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationsView()
            .environment(\.layoutDirection, .rightToLeft)
    }
}
