//
//  EventNotificationScheduler.swift
//  DitharApp
//
//  Created by Fatmah Alsufaian on 14/08/1447 AH.
//


import Foundation
import FirebaseAuth
import FirebaseFirestore

class EventNotificationScheduler {
    
    static let shared = EventNotificationScheduler()
    private let notificationService = NotificationService()
    
    // Keep track of scheduled work items
    private var scheduledWorkItems: [String: [DispatchWorkItem]] = [:]
    
    private init() {}
    
    // MARK: - Schedule Event Notifications
    
    /// جدولة إشعارات المناسبة (3 أيام قبل + نفس اليوم) - في Firestore فقط
    func scheduleNotifications(for event: CalendarEvent, completion: ((Bool) -> Void)? = nil) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion?(false)
            return
        }
        
        // تأكد من أن التاريخ في المستقبل
        let now = Date()
        guard event.date > now else {
            print("⚠️ الحدث في الماضي، لن يتم جدولة الإشعارات")
            completion?(false)
            return
        }
        
        // احذف الإشعارات القديمة أولاً (في حالة التعديل)
        cancelNotifications(for: event.id)
        
        var scheduledCount = 0
        
        // 1️⃣ إشعار قبل 3 أيام الساعة 12:00 ظهراً
        if let threeDaysBeforeDate = calculateThreeDaysBeforeAt12PM(from: event.date) {
            if threeDaysBeforeDate > now {
                scheduleFirestoreNotification(
                    eventId: event.id,
                    eventTitle: event.title,
                    eventDate: event.date,
                    eventTime: event.time,
                    eventOutfitId: event.outfitId,
                    notificationDate: threeDaysBeforeDate,
                    userId: userId
                )
                scheduledCount += 1
            } else {
                print("⏭️ إشعار 3 أيام قبل في الماضي، سيتم تخطيه")
            }
        }
        
        // 2️⃣ إشعار نفس اليوم الساعة 5:00 صباحاً
        if let sameDayDate = calculateSameDayAt5AM(from: event.date) {
            if sameDayDate > now {
                scheduleFirestoreNotification(
                    eventId: event.id,
                    eventTitle: event.title,
                    eventDate: event.date,
                    eventTime: event.time,
                    eventOutfitId: event.outfitId,
                    notificationDate: sameDayDate,
                    userId: userId
                )
                scheduledCount += 1
            } else {
                print("⏭️ إشعار نفس اليوم في الماضي، سيتم تخطيه")
            }
        }
        
        let success = scheduledCount > 0
        print(success ? "✅ تم جدولة \(scheduledCount) إشعار للحدث \(event.title)" : "❌ لم يتم جدولة أي إشعارات")
        completion?(success)
    }
    
    // MARK: - Schedule Firestore Notification
    
    private func scheduleFirestoreNotification(
        eventId: String,
        eventTitle: String,
        eventDate: Date,
        eventTime: Date?,
        eventOutfitId: String?,
        notificationDate: Date,
        userId: String
    ) {
        let timeInterval = notificationDate.timeIntervalSinceNow
        
        guard timeInterval > 0 else {
            print("⚠️ الوقت المحدد في الماضي")
            return
        }
        
        // ✅ Create a unique ID for this work item
        let workItemId = UUID()
        
        // ✅ إنشاء DispatchWorkItem
        let workItem = DispatchWorkItem { [weak self] in
            // إنشاء إشعار في Firestore عند حلول الوقت
            self?.notificationService.sendEventReminderNotification(
                userId: userId,
                eventId: eventId,
                eventTitle: eventTitle,
                eventDate: eventDate,
                eventTime: eventTime,
                eventOutfitId: eventOutfitId
            ) { success in
                if success {
                    print("✅ تم إنشاء إشعار المناسبة في Firestore: \(eventTitle)")
                } else {
                    print("❌ فشل إنشاء إشعار المناسبة في Firestore")
                }
            }
        }
        
        // جدولة الـ WorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + timeInterval, execute: workItem)
        
        // حفظ WorkItem للإلغاء لاحقاً إذا لزم الأمر
        if scheduledWorkItems[eventId] == nil {
            scheduledWorkItems[eventId] = []
        }
        scheduledWorkItems[eventId]?.append(workItem)
        
        print("✅ تم جدولة إشعار للحدث \(eventTitle) في \(notificationDate)")
    }
    
    // MARK: - Cancel Notifications
    
    /// إلغاء جميع إشعارات حدث معين
    func cancelNotifications(for eventId: String) {
        if let workItems = scheduledWorkItems[eventId] {
            workItems.forEach { $0.cancel() }
            scheduledWorkItems.removeValue(forKey: eventId)
            print("🗑️ تم إلغاء الإشعارات للحدث \(eventId)")
        }
    }
    
    // MARK: - Helpers
    
    private func calculateThreeDaysBeforeAt12PM(from eventDate: Date) -> Date? {
        let calendar = Calendar.current
        
        // اطرح 3 أيام
        guard let threeDaysBefore = calendar.date(byAdding: .day, value: -3, to: eventDate) else {
            return nil
        }
        
        // حدد الساعة 12:00 ظهراً
        var components = calendar.dateComponents([.year, .month, .day], from: threeDaysBefore)
        components.hour = 12
        components.minute = 0
        components.second = 0
        
        return calendar.date(from: components)
    }

    private func calculateSameDayAt5AM(from eventDate: Date) -> Date? {
        let calendar = Calendar.current
        
        // نفس اليوم الساعة 5:00 صباحاً
        var components = calendar.dateComponents([.year, .month, .day], from: eventDate)
        components.hour = 5
        components.minute = 0
        components.second = 0
        
        return calendar.date(from: components)
    }
}
