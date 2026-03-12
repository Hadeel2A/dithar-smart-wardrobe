//
//  CalendarPageView.swift
//  DitharApp
//
//  Created by Rahaf AlFantoukh on 20/05/1447 AH.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct AppColors {
    static let darkGreen = Color(red: 0.47, green: 0.58, blue: 0.44)
}

// MARK: - Calendar Page (Refactored)
struct CalendarPageView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.presentationMode) var presentationMode

    // MARK: - State Variables
    @State private var selectedDate: Date = Date()
    @State private var events: [CalendarEvent] = []
    @State private var allOutfits: [Outfit] = []
    @State private var isLoading = true
    @State private var showAddEventSheet = false
    @State private var navigationPath = NavigationPath()
    @State private var showDeleteEventAlert = false
    @State private var pendingDeleteEvent: CalendarEvent? = nil
    @State private var editingEvent: CalendarEvent? = nil
    @State private var outfitsLoading = false

    // MARK: - Computed Properties
    private var eventsForSelectedDate: [CalendarEvent] {
        events
            .filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { ($0.time ?? Date.distantFuture) < ($1.time ?? Date.distantFuture) }
    }

    private var eventDates: Set<Date> {
        Set(events.map { Calendar.current.startOfDay(for: $0.date) })
    }

    // MARK: - Body
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .bottomLeading) {
                Color.white.ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    StyledCalendarView(selectedDate: $selectedDate, eventDates: eventDates)
                        .padding(.horizontal)
                        .padding(.bottom, 10)

                    eventsSection
                }
                .background(Color.white)

                addEventButton
            }
            .navigationBarHidden(true)
            .onAppear(perform: fetchData)
            .onChange(of: authManager.user?.uid) { _ in
                fetchOutfits()
            }

            // ✅ تحرير
            .sheet(item: $editingEvent) { ev in
                AddEventView(
                    selectedDate: ev.date,
                    allOutfits: allOutfits,
                    existingEvent: ev
                ) { updatedEvent in
                    updateEvent(updatedEvent)
                }
                .environmentObject(authManager)
            }

            // ✅ إضافة
            .sheet(isPresented: $showAddEventSheet) {
                AddEventView(selectedDate: selectedDate, allOutfits: allOutfits) { newEvent in
                    saveEvent(newEvent)
                }
                .environmentObject(authManager)
                .id(allOutfits.count)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
    }

    // MARK: - Subviews
    private var header: some View {
        HStack {
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "arrow.right")
                    .font(.title2.weight(.medium))
                    .foregroundColor(.primary)
                    .flipsForRightToLeftLayoutDirection(false)
            }

            Spacer()

            Text("التقويم")
                .font(.system(size: 20, weight: .bold))

            Spacer()
        }
        .padding()
        .background(Color.white)
    }

    @ViewBuilder
    private var eventsSection: some View {
        VStack(spacing: 0) {
            Text("أحداث اليوم")
                .font(.system(size: 18, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .padding([.horizontal, .top])
                .padding(.bottom, 10)

            if isLoading {
                ProgressView().padding()
            } else if eventsForSelectedDate.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundColor(.gray.opacity(0.5))
                    Text("لا توجد أحداث لهذا اليوم")
                        .foregroundColor(.gray)
                }
                .padding(40)
            } else {
                List {
                    ForEach(eventsForSelectedDate) { event in
                        EventRowView(event: event, allOutfits: allOutfits)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {

                                Button {
                                    editingEvent = event
                                } label: {
                                    Label("تحرير", systemImage: "pencil")
                                }
                                .tint(Color(red: 0.47, green: 0.58, blue: 0.44))

                                Button(role: .destructive) {
                                    pendingDeleteEvent = event
                                    showDeleteEventAlert = true
                                } label: {
                                    Label("حذف", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .listRowBackground(Color.clear)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .alert("",
                       isPresented: $showDeleteEventAlert,
                       presenting: pendingDeleteEvent) { ev in
                    Button("نعم", role: .destructive) {
                        deleteEvent(ev)
                    }
                    Button("لا", role: .cancel) { }
                } message: { _ in
                    Text("هل أنت متأكد من حذف هذا الحدث؟")
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
    }

    private var addEventButton: some View {
        Button(action: {
            showAddEventSheet = true
        }) {
            Image(systemName: "plus")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 65, height: 65)
                .background(Color(red: 0.47, green: 0.58, blue: 0.44))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        }
        .disabled(outfitsLoading)
        .opacity(outfitsLoading ? 0.6 : 1)
        .padding(.leading, 30)
        .padding(.bottom, 40)
    }

    // MARK: - Data Functions
    private func fetchData() {
        fetchEvents()
        fetchOutfits()
    }

    private func fetchEvents() {
        guard let userId = authManager.user?.uid else { return }
        isLoading = true
        let db = Firestore.firestore()

        db.collection("users").document(userId).collection("calendarEvents")
            .addSnapshotListener { snapshot, error in
                isLoading = false
                if let error = error {
                    print("Error fetching events: \(error)")
                    return
                }
                guard let documents = snapshot?.documents else { return }
                self.events = documents.compactMap { try? $0.data(as: CalendarEvent.self) }
            }
    }

    private func fetchOutfits() {
        let userId = authManager.user?.uid ?? Auth.auth().currentUser?.uid
        guard let userId else {
            print("No userId yet")
            return
        }

        outfitsLoading = true

        Firestore.firestore()
            .collection("outfits")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in

                outfitsLoading = false

                if let error = error {
                    print("Error fetching outfits:", error.localizedDescription)
                    return
                }

                self.allOutfits = snapshot?.documents.compactMap {
                    try? $0.data(as: Outfit.self)
                } ?? []

                print("Fetched outfits:", self.allOutfits.count)
            }
    }

    private func saveEvent(_ event: CalendarEvent) {
        guard let userId = authManager.user?.uid else { return }
        let db = Firestore.firestore()

        do {
            var eventToSave = event
            eventToSave.userId = userId
            eventToSave.date = Calendar.current.startOfDay(for: eventToSave.date) // ✅ توحيد التاريخ

            try db.collection("users").document(userId).collection("calendarEvents")
                .document(event.id)
                .setData(from: eventToSave)

            EventNotificationScheduler.shared.scheduleNotifications(for: eventToSave) { success in
                if success {
                    print("✅ تم جدولة إشعارات الحدث: \(eventToSave.title)")
                }
            }
        } catch {
            print("Error saving event: \(error)")
        }
    }

    private func updateEvent(_ event: CalendarEvent) {
        guard let userId = authManager.user?.uid else { return }
        let db = Firestore.firestore()

        do {
            var eventToSave = event
            eventToSave.userId = userId
            eventToSave.date = Calendar.current.startOfDay(for: eventToSave.date) // ✅ توحيد التاريخ

            try db.collection("users")
                .document(userId)
                .collection("calendarEvents")
                .document(event.id)
                .setData(from: eventToSave, merge: true)

            EventNotificationScheduler.shared.scheduleNotifications(for: eventToSave) { success in
                if success {
                    print("✅ تم تحديث إشعارات الحدث: \(eventToSave.title)")
                }
            }
        } catch {
            print("Error updating event: \(error)")
        }
    }

    private func deleteEvent(_ event: CalendarEvent) {
        guard let userId = authManager.user?.uid else { return }

        EventNotificationScheduler.shared.cancelNotifications(for: event.id)

        Firestore.firestore()
            .collection("users")
            .document(userId)
            .collection("calendarEvents")
            .document(event.id)
            .delete { error in
                if let error = error {
                    print("Error deleting event: \(error)")
                } else {
                    print("✅ تم حذف الحدث والإشعارات المرتبطة")
                }
                pendingDeleteEvent = nil
            }
    }
}

// MARK: - Styled Calendar View (New Design)
struct StyledCalendarView: View {
    @Binding var selectedDate: Date
    let eventDates: Set<Date>

    // ✅ NEW: يناديه فقط عند ضغط اليوزر على يوم
    var onUserSelectDate: ((Date) -> Void)? = nil

    @State private var month: Date = Date()

    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "ar_SA")
        c.firstWeekday = 7 // السبت
        return c
    }()

    private let daysOfWeek = ["س", "أ", "ن", "ث", "ر", "خ", "ج"]

    var body: some View {
        VStack {
            header
            daysOfWeekHeader
            daysGrid
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
        .onAppear {
            month = startOfMonth(selectedDate)
            selectedDate = calendar.startOfDay(for: selectedDate)
        }
        .onChange(of: selectedDate) { newDate in
            let sod = calendar.startOfDay(for: newDate)

            if sod != newDate {
                selectedDate = sod
                return
            }

            if !calendar.isDate(sod, equalTo: month, toGranularity: .month) {
                month = startOfMonth(sod)
            }
        }
    }

    private var header: some View {
        HStack {
            Button(action: { changeMonth(by: -1) }) {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .flipsForRightToLeftLayoutDirection(false)
            }
            Spacer()
            Text(month, formatter: DateFormatter.monthAndYear)
                .font(.headline.weight(.bold))
            Spacer()
            Button(action: { changeMonth(by: 1) }) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .flipsForRightToLeftLayoutDirection(false)
            }
        }
        .foregroundColor(Color(red: 0.47, green: 0.58, blue: 0.44))
        .padding(.bottom, 10)
    }

    private var daysOfWeekHeader: some View {
        HStack {
            ForEach(daysOfWeek, id: \.self) { day in
                Text(day)
                    .font(.footnote)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var daysGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {

            ForEach(Array(daysInMonth().enumerated()), id: \.offset) { _, date in
                if let date = date {
                    DayCell(
                        date: date,
                        selectedDate: $selectedDate,
                        hasEvent: eventDates.contains(calendar.startOfDay(for: date)),
                        calendar: calendar,
                        onTap: { picked in
                            onUserSelectDate?(picked)
                        }
                    )
                } else {
                    Rectangle().fill(Color.clear)
                        .frame(height: 40)
                }
            }
        }
    }

    private func startOfMonth(_ date: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps)!
    }

    private func changeMonth(by value: Int) {
        let newMonth = calendar.date(byAdding: .month, value: value, to: month) ?? month
        month = startOfMonth(newMonth)
    }

    private func daysInMonth() -> [Date?] {
        let monthStart = startOfMonth(month)
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthStart) else { return [] }

        var days: [Date?] = []

        let firstDayOfWeek = calendar.component(.weekday, from: monthInterval.start)
        let leadingSpaces = (firstDayOfWeek - calendar.firstWeekday + 7) % 7
        days.append(contentsOf: Array(repeating: nil, count: leadingSpaces))

        let range = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<1
        let monthDays: [Date] = range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start)
        }

        days.append(contentsOf: monthDays)

        while days.count % 7 != 0 { days.append(nil) }
        while days.count < 42 { days.append(nil) }

        return days
    }
}

// MARK: - Day Cell (Updated)
struct DayCell: View {
    let date: Date
    @Binding var selectedDate: Date
    let hasEvent: Bool
    let calendar: Calendar

    var onTap: ((Date) -> Void)? = nil

    private var isSelected: Bool { calendar.isDate(date, inSameDayAs: selectedDate) }
    private var isToday: Bool { calendar.isDateInToday(date) }

    var body: some View {
        Button(action: {
            let picked = calendar.startOfDay(for: date)
            selectedDate = picked
            onTap?(picked)
        }) {
            VStack(spacing: 4) {
                Text(String(calendar.component(.day, from: date)))
                    .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                    .frame(width: 32, height: 32)
                    .background(
                        ZStack {
                            if isSelected {
                                Circle().fill(Color(red: 0.47, green: 0.58, blue: 0.44))
                            } else if isToday {
                                Circle().stroke(Color.gray, lineWidth: 1)
                            }
                        }
                    )
                    .foregroundColor(isSelected ? .white : .primary)

                Circle()
                    .fill(hasEvent ? Color.blue : Color.clear)
                    .frame(width: 5, height: 5)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Event Row View (New Design)
struct EventRowView: View {
    @EnvironmentObject var authManager: AuthenticationManager

    let event: CalendarEvent
    let allOutfits: [Outfit]

    private var outfit: Outfit? {
        allOutfits.first { $0.id == event.outfitId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(event.title)
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .padding(.leading, 5)

                Spacer()

                if let time = event.time {
                    Text(time, style: .time)
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.trailing, 5)
                }
            }

            if let outfit = outfit {
                ZStack {
                    HStack {
                        Text("عرض الإطلالة")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "chevron.left")
                            .flipsForRightToLeftLayoutDirection(false)
                    }
                    .foregroundColor(Color(red: 0.47, green: 0.58, blue: 0.44))
                    .padding(10)
                    .background(Color(red: 0.47, green: 0.58, blue: 0.44).opacity(0.1))
                    .cornerRadius(8)

                    NavigationLink {
                        OutfitDetailsView(outfit: outfit)
                            .environmentObject(authManager)
                    } label: { EmptyView() }
                    .opacity(0.0)
                }
                .contentShape(Rectangle())
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 6)
    }
}

// MARK: - ✅ NEW: Calendar Picker Sheet for Editing Date
struct EditEventDateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date

    @State private var tempDate: Date = Date()

    var body: some View {
        ZStack {
            // ✅ لا خلفية نهائياً (شفاف بالكامل)
            // لكن نحتاجه يلتقط الضغط خارج الكرت للإغلاق
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }

            // ✅ الكرت بالمنتصف
            StyledCalendarView(
                selectedDate: $tempDate,
                eventDates: [],
                onUserSelectDate: { picked in
                    selectedDate = Calendar.current.startOfDay(for: picked)
                    dismiss()
                }
            )
            .padding(16)
            .background(Color.white)
            .cornerRadius(22)
            .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 8)
            .frame(maxWidth: 420)         // اختياري: يثبت عرض جميل بالآيباد
            .padding(.horizontal, 24)
            .onTapGesture { }             // ✅ يمنع إغلاقه عند الضغط داخل الكرت
        }
        .onAppear {
            tempDate = Calendar.current.startOfDay(for: selectedDate)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
    }
}

struct OutfitCollageView: View {
    let outfit: Outfit
    let targetWidth: CGFloat
    var targetHeight: CGFloat { targetWidth * 1.2 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)

            GeometryReader { geo in
                let scaleX = geo.size.width / 350
                let scaleY = geo.size.height / 400

                ForEach(outfit.items) { item in
                    if let urlStr = item.localImageURLString, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFit()
                            case .failure(_):
                                Color.gray.opacity(0.15)
                            case .empty:
                                ProgressView()
                            @unknown default:
                                Color.gray.opacity(0.15)
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
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(8)
        }
        .frame(width: targetWidth, height: targetHeight)
    }
}

// MARK: - Add Event View (Updated: supports date editing in edit mode)
struct AddEventView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthenticationManager

    // NOTE: نخليها كـ input فقط، ونستخدم state داخلي للتعديل
    let selectedDate: Date
    let allOutfits: [Outfit]
    let existingEvent: CalendarEvent?
    let onSave: (CalendarEvent) -> Void

    @State private var title: String
    @State private var includeTime: Bool
    @State private var time: Date
    @State private var selectedOutfitId: String?
    @State private var showOutfitSelector = false
    @State private var draftOutfitId: String? = nil

    // ✅ NEW: تاريخ قابل للتعديل داخل التحرير
    @State private var eventDate: Date
    @State private var showEditDateSheet = false

    init(selectedDate: Date,
         allOutfits: [Outfit],
         existingEvent: CalendarEvent? = nil,
         onSave: @escaping (CalendarEvent) -> Void) {

        self.selectedDate = selectedDate
        self.allOutfits = allOutfits
        self.existingEvent = existingEvent
        self.onSave = onSave

        _title = State(initialValue: existingEvent?.title ?? "")
        _includeTime = State(initialValue: existingEvent?.time != nil)
        _time = State(initialValue: existingEvent?.time ?? Date())
        _selectedOutfitId = State(initialValue: existingEvent?.outfitId)

        // ✅ NEW: نبدأ بتاريخ الحدث الموجود أو التاريخ المختار
        let initial = existingEvent?.date ?? selectedDate
        _eventDate = State(initialValue: Calendar.current.startOfDay(for: initial))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {

                    // ✅ Card 1: تفاصيل الحدث
                    card {
                        VStack(alignment: .leading, spacing: 14) {

                            Text("تفاصيل الحدث")
                                .font(.headline)
                                .foregroundColor(AppColors.darkGreen)
                            TextField("اسم الحدث", text: $title)
                                .textFieldStyle(.roundedBorder)

                            Toggle("تحديد وقت", isOn: $includeTime.animation())

                            if includeTime {
                                DatePicker("الوقت", selection: $time, displayedComponents: .hourAndMinute)
                            }

                            if existingEvent != nil {
                                Button {
                                    showEditDateSheet = true
                                } label: {
                                    HStack(spacing: 10) {
                                        Text("تعديل التاريخ")
                                            .foregroundColor(.primary)

                                        Spacer()

                                        Text(eventDate, formatter: DateFormatter.arFullDate)
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)

                                        Image(systemName: "chevron.left")
                                            .foregroundColor(.gray)
                                            .flipsForRightToLeftLayoutDirection(false)
                                    }
                                }
                            }
                        }
                    }

                    // ✅ Card 2: الإطلالة
                    card {
                        VStack(alignment: .leading, spacing: 12) {

                            Text("الإطلالة (اختياري)")
                                .font(.headline)
                                .foregroundColor(AppColors.darkGreen)
                            if let outfit = allOutfits.first(where: { $0.id == selectedOutfitId }) {

                                ZStack(alignment: .topTrailing) {
                                    OutfitCollageView(outfit: outfit, targetWidth: UIScreen.main.bounds.width - 64)
                                        .padding(.top, 45)

                                    HStack(spacing: 12) {
                                        Button(action: {
                                            draftOutfitId = selectedOutfitId
                                            showOutfitSelector = true
                                        }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "pencil")
                                                Text("تعديل")
                                                    .font(.system(size: 16, weight: .medium))
                                            }
                                            .foregroundColor(Color(red: 0.47, green: 0.58, blue: 0.44))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(Color(red: 0.47, green: 0.58, blue: 0.44).opacity(0.1))
                                            .cornerRadius(10)
                                        }
                                        .buttonStyle(.plain)

                                        Button(action: {
                                            selectedOutfitId = nil
                                            draftOutfitId = nil
                                            showOutfitSelector = false
                                        }) {
                                            Image(systemName: "trash")
                                                .font(.system(size: 20))
                                                .foregroundColor(.red)
                                                .frame(width: 40, height: 40)
                                                .background(Color.red.opacity(0.1))
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.trailing, 10)
                                    .offset(y: -10)
                                }

                            } else {
                                Button {
                                    draftOutfitId = selectedOutfitId
                                    showOutfitSelector = true
                                } label: {
                                    HStack {
                                        Text("اختيار إطلالة")
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        Image(systemName: "chevron.left")
                                            .foregroundColor(.gray)
                                            .flipsForRightToLeftLayoutDirection(false)
                                    }
                                    .foregroundColor(.primary)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .background(Color.white.ignoresSafeArea())
            .navigationTitle(existingEvent == nil ? "إضافة حدث" : "تحرير الحدث")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(existingEvent == nil ? "إضافة حدث" : "تحرير الحدث")
                        .font(.headline)
                    .foregroundColor(AppColors.darkGreen)                }
            }            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showOutfitSelector) {
                SelectOutfitViewN(
                    allOutfits: allOutfits,
                    preselectedId: selectedOutfitId
                ) { pickedId in
                    selectedOutfitId = pickedId
                    draftOutfitId = pickedId
                    showOutfitSelector = false
                }
            }
            // ✅ NEW: Sheet لتعديل التاريخ
            .transparentFullScreenCover(isPresented: $showEditDateSheet) {
                EditEventDateSheet(selectedDate: $eventDate)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 6)
    }
    
    private func save() {
        let eventId = existingEvent?.id ?? UUID().uuidString

        let updated = CalendarEvent(
            id: eventId,
            userId: "", // يتحدد في CalendarPageView
            date: Calendar.current.startOfDay(for: (existingEvent == nil ? selectedDate : eventDate)), // ✅ NEW
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            time: includeTime ? time : nil,
            outfitId: selectedOutfitId
        )

        onSave(updated)
        dismiss()
    }
}

// MARK: - Select Outfit View (New)
struct SelectOutfitViewN: View {
    @Environment(\.dismiss) var dismiss

    let allOutfits: [Outfit]
    let preselectedId: String?
    var onPick: (String) -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 15), GridItem(.flexible(), spacing: 15)],
                    spacing: 15
                ) {
                    ForEach(allOutfits) { outfit in
                        Button {
                            onPick(outfit.id)
                            dismiss()
                        } label: {
                            OutfitCard(outfit: outfit, width: 160, height: 200, onFavoriteToggle: {})
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(preselectedId == outfit.id ? Color.blue : Color.clear, lineWidth: 3)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("اختيار إطلالة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إغلاق") { dismiss() } }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
    }
}

// MARK: - Data Model (New)
struct CalendarEvent: Identifiable, Codable, Hashable {
    var id: String
    var userId: String
    var date: Date
    var title: String
    var time: Date?
    var outfitId: String?
}

// MARK: - Helpers
extension DateFormatter {
    static var monthAndYear: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar")
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }

    // ✅ NEW: تنسيق عربي لعرض التاريخ الحالي داخل التحرير
    static var arFullDate: DateFormatter {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ar_SA")
        df.calendar = Calendar(identifier: .gregorian)
        df.dateFormat = "EEEE، d MMMM yyyy"
        return df
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}


struct TransparentFullScreenCover<Content: View>: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let content: () -> Content

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented {
            if uiViewController.presentedViewController == nil {
                let host = UIHostingController(rootView: content())
                host.view.backgroundColor = .clear
                host.modalPresentationStyle = .overCurrentContext
                host.modalTransitionStyle = .crossDissolve
                uiViewController.present(host, animated: true)
            } else {
                (uiViewController.presentedViewController as? UIHostingController<Content>)?.rootView = content()
            }
        } else {
            if let presented = uiViewController.presentedViewController as? UIHostingController<Content> {
                presented.dismiss(animated: true)
            }
        }
    }
}

extension View {
    func transparentFullScreenCover<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        background(TransparentFullScreenCover(isPresented: isPresented, content: content))
    }
}

