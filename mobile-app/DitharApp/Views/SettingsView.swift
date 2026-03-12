import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import UserNotifications

// MARK: - Accessibility Support
// (يتم استخدام DitharVoiceAssistant و AccessibilityManager من ملفات منفصلة)

struct SettingsView: View {
    // Toggles
    @State private var notificationsEnabled = false
    @State private var voiceDescriptionEnabled = false
    @Environment(\.openURL) private var openURL
    // Change Password
    @State private var showChangePassword = false
    
    // UI state
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showDeleteConfirmation = false
    // الإضافة رقم 1: متغير حالة جديد لتأكيد تسجيل الخروج
    @State private var showSignOutConfirmation = false

    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        ZStack {
            Color.customBackground.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    Spacer().frame(height: 35)
                    
                    // MARK: - Notification Toggle
                    SettingsCard {
                        Toggle(isOn: Binding(
                            get: { notificationsEnabled },
                            set: { newValue in
                                notificationsEnabled = newValue
                                handleNotificationToggle(newValue)
                            }
                        )) {
                            HStack(spacing: 12) {
                                Image(systemName: "bell.fill")
                                    .foregroundColor(.customIconColor)
                                    .accessibilityHidden(true)
                                Text("تفعيل الإشعارات")
                                    .foregroundColor(.customPrimaryText)
                            }
                        }
                        .tint(Color(red: 0.47, green: 0.58, blue: 0.44))
                        .accessibilityLabel("تفعيل الإشعارات")
                        .accessibilityValue(notificationsEnabled ? "مفعل" : "غير مفعل")
                        .accessibilityHint("اضغط مرتين لتفعيل أو إلغاء الإشعارات")
                        // نطق اسم الخيار عند اللمس (قبل التغيير)
                        .simultaneousGesture(TapGesture().onEnded {
                            if AccessibilityManager.shared.isAVSpeechEnabled {
                                DitharVoiceAssistant.shared.speak("خيار تفعيل الإشعارات")
                            }
                        })
                        // نطق حالة التفعيل/الإلغاء بعد ما يتغير
                        .onChange(of: notificationsEnabled) { newVal in
                            let message = newVal
                                ? "تم تفعيل الإشعارات"
                                : "تم إلغاء تفعيل الإشعارات"

                            if UIAccessibility.isVoiceOverRunning {
                                UIAccessibility.post(notification: .announcement, argument: message)
                            } else if AccessibilityManager.shared.isAVSpeechEnabled {
                                DitharVoiceAssistant.shared.speak(message, interrupt: true)
                            }
                        }
                    }
                    
                    
                    // MARK: - Voice Description Toggle
                    SettingsCard {
                        Toggle(isOn: $voiceDescriptionEnabled) {
                            HStack(spacing: 12) {
                                Image(systemName: "ear")
                                    .foregroundColor(.customIconColor)
                                    .accessibilityHidden(true)
                                Text("تفعيل الوصف الصوتي")
                                    .foregroundColor(.customPrimaryText)
                            }
                        }
                        .tint(Color(red: 0.47, green: 0.58, blue: 0.44))
                        .accessibilityLabel("تفعيل الوصف الصوتي")
                        .accessibilityValue(voiceDescriptionEnabled ? "مفعل" : "غير مفعل")
                        .onChange(of: voiceDescriptionEnabled) { newVal in
                            let message = newVal
                                ? "تم تفعيل الوصف الصوتي"
                                : "تم إلغاء تفعيل الوصف الصوتي"

                            // لو كان الفويس أوفر شغّال، نخلي النظام يعلن
                            if UIAccessibility.isVoiceOverRunning {
                                UIAccessibility.post(notification: .announcement, argument: message)
                            } else {
                                // نضمن إنه يتكلم حتى لو كنا قاعدين نطفيه
                                let manager = AccessibilityManager.shared
                                let previous = manager.isAVSpeechEnabled

                                // نفعّله مؤقتاً عشان يقدر يتكلم
                                manager.isAVSpeechEnabled = true
                                DitharVoiceAssistant.shared.speak(message, interrupt: true)
                                // نرجّعه للحالة الجديدة بعد ما يتكلم
                                manager.isAVSpeechEnabled = newVal

                                // (لو حابة ترجّعين القديم لأي سبب)
                                _ = previous
                            }

                            // نحدّث الفلاغ الفعلي في المانجر والداتا
                            AccessibilityManager.shared.isAVSpeechEnabled = newVal
                            UserDefaults.standard.set(newVal, forKey: "voiceDescriptionEnabled")

                            Task { await persistVoiceDescription(newVal) }
                        }
                    }

                    
                    // MARK: - Change Password Button
                    SettingsCard {
                        Button(action: { showChangePassword = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "key.fill")
                                    .foregroundColor(.customIconColor)
                                    .accessibilityHidden(true)
                                Text("تغيير كلمة المرور")
                                    .foregroundColor(.customPrimaryText)
                                Spacer()
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.gray.opacity(0.5))
                                    .accessibilityHidden(true)
                            }
                        }
                        .accessibilityLabel(" تغيير كلمة المرور")
                        .accessibilityHint("اضغط مرتين لفتح صفحة تغيير كلمة المرور")
                        // إضافة النطق عند اللمس
                        .simultaneousGesture(TapGesture().onEnded {
                            if voiceDescriptionEnabled {
                                DitharVoiceAssistant.shared.speak("زر تغيير كلمة المرور")
                            }
                        })
                    }
                    
                    // MARK: - About
                    // MARK: - About
                    AboutSection()
                        // إضافة النطق + فتح موقع دِثار عند اللمس
                        .contentShape(Rectangle()) // يجعل كامل الكرت قابل للمس
                        .simultaneousGesture(TapGesture().onEnded {
                            if voiceDescriptionEnabled {
                                DitharVoiceAssistant.shared.speak("فتح موقع دِثار")
                            }
                            if let url = URL(string: "https://dithar-950c1.web.app") {
                                openURL(url)
                            }
                        })
                        .accessibilityAddTraits(.isLink)
                        .accessibilityLabel("حول دِثار")
                        .accessibilityHint("يفتح موقع دِثار في المتصفح")

                    Spacer().frame(height: 80)

                    
                    // MARK: - Auth Actions
                    VStack(spacing: 16) {
                        // تعديل زر تسجيل الخروج ليعرض نافذة التأكيد
                        Button(action: {
                            showSignOutConfirmation = true
                        }) {
                            Text("تسجيل الخروج")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.customPrimaryText)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
                        }
                        .accessibilityLabel(" تسجيل الخروج")
                        .accessibilityHint("اضغط مرتين لتسجيل الخروج من حسابك")
                        // إضافة النطق عند اللمس
                        .simultaneousGesture(TapGesture().onEnded {
                            if voiceDescriptionEnabled {
                                DitharVoiceAssistant.shared.speak("زر تسجيل الخروج")
                            }
                        })
                        // إضافة نافذة تأكيد تسجيل الخروج
                        .confirmationDialog(
                            "هل أنت متأكد من تسجيل الخروج؟",
                            isPresented: $showSignOutConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button("تأكيد تسجيل الخروج", role: .destructive, action: signOut)
                            Button("إلغاء", role: .cancel) { }
                        }
                        
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Text("حذف الحساب")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
                        }
                        .accessibilityLabel(" حذف الحساب نهائياً")
                        .accessibilityHint("تحذير: اضغط مرتين لحذف حسابك بشكل نهائي")
                        // إضافة النطق عند اللمس
                        .simultaneousGesture(TapGesture().onEnded {
                            if voiceDescriptionEnabled {
                                DitharVoiceAssistant.shared.speak("زر حذف الحساب")
                            }
                        })
                        .confirmationDialog(
                            "هل أنت متأكد من حذف الحساب نهائيًا؟",
                            isPresented: $showDeleteConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button("تأكيد", role: .destructive, action: deleteAccount)
                            Button("إلغاء", role: .cancel) { }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .padding(.top, 16)
            }
            
            if isLoading {
                ProgressView().scaleEffect(1.2)
            }
        }
        .navigationTitle("الإعدادات")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.customPrimaryText)
                }
                .accessibilityLabel(" الرجوع")
                .accessibilityHint("اضغط مرتين للعودة للصفحة السابقة")
                // إضافة النطق عند اللمس لزر الرجوع
                .simultaneousGesture(TapGesture().onEnded {
                    if voiceDescriptionEnabled {
                        DitharVoiceAssistant.shared.speak("زر الرجوع")
                    }
                })
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("تنبيه"), message: Text(alertMessage), dismissButton: .default(Text("حسنًا")))
        }
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordViewSettings()
        }
        .task {
            await loadUserSettings()
            
            // إعلان دخول صفحة الإعدادات
            DitharVoiceAssistant.shared.announceScreenChange("صفحة الإعدادات")
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}




// MARK: - Helpers
extension SettingsView {
    private func loadUserSettings() async {
        guard let user = Auth.auth().currentUser else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let snap = try await Firestore.firestore().collection("users").document(user.uid).getDocument()
            let data = snap.data() ?? [:]
            self.notificationsEnabled = data["notificationsEnabled"] as? Bool ?? false
            self.voiceDescriptionEnabled = data["voiceDescriptionEnabled"] as? Bool ?? false
        } catch {
            alertMessage = "تعذّر جلب الإعدادات: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func persistNotifications(_ enabled: Bool) async {
        guard let user = Auth.auth().currentUser else { return }
        do {
            try await Firestore.firestore()
                .collection("users").document(user.uid)
                .updateData(["notificationsEnabled": enabled, "updatedAt": Timestamp()])
        } catch {
            alertMessage = "فشل حفظ إعداد الإشعارات: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func persistVoiceDescription(_ enabled: Bool) async {
        guard let user = Auth.auth().currentUser else { return }
        do {
            try await Firestore.firestore()
                .collection("users").document(user.uid)
                .updateData(["voiceDescriptionEnabled": enabled, "updatedAt": Timestamp()])
        } catch {
            alertMessage = "فشل حفظ إعداد الوصف الصوتي: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    private func handleNotificationToggle(_ newValue: Bool) {
        if newValue {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                DispatchQueue.main.async {
                    self.notificationsEnabled = granted
                    if granted {
                        Task { await persistNotifications(true) }
                    } else {
                        Task { await persistNotifications(false) }
                        alertMessage = "تم رفض الإذن بالإشعارات. يمكنكِ تفعيله من إعدادات النظام."
                        showAlert = true
                        openAppSettings()
                    }
                }
            }
        } else {
            Task { await persistNotifications(false) }
        }
    }
    
    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
    
    private func signOut() {
        do {
            try Auth.auth().signOut()
            alertMessage = "تم تسجيل الخروج بنجاح."
        } catch {
            alertMessage = "حدث خطأ أثناء تسجيل الخروج: \(error.localizedDescription)"
        }
        showAlert = true
    }
    
    private func deleteAccount() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        
        db.collection("users").document(user.uid).delete { _ in
            user.delete { error in
                if let error = error {
                    alertMessage = "حدث خطأ أثناء حذف الحساب: \(error.localizedDescription)"
                } else {
                    alertMessage = "تم حذف الحساب نهائيًا."
                }
                showAlert = true
            }
        }
    }
}


// MARK: - Change Password View (نفس تصميم ProfileView + الشروط الأربعة)
struct ChangePasswordViewSettings: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    
    @State private var isCurrentPasswordVisible = false
    @State private var isNewPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isSuccess = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.customBackground.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Current Password
                    VStack(alignment: .trailing, spacing: 8) {
                        Text("كلمة المرور الحالية")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.customPrimaryText)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        
                        HStack {
                            Button(action: { isCurrentPasswordVisible.toggle() }) {
                                Image(systemName: isCurrentPasswordVisible ? "eye.slash" : "eye")
                                    .foregroundColor(.gray)
                            }
                            // إضافة نطق لزر العين
                            .simultaneousGesture(TapGesture().onEnded {
                                if AccessibilityManager.shared.isAVSpeechEnabled {
                                    DitharVoiceAssistant.shared.speak("إظهار أو إخفاء كلمة المرور الحالية")
                                }
                            })
                            
                            if isCurrentPasswordVisible {
                                TextField("", text: $currentPassword)
                                    .multilineTextAlignment(.trailing)
                            } else {
                                SecureField("", text: $currentPassword)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                    
                    // New Password
                    VStack(alignment: .trailing, spacing: 8) {
                        Text("كلمة المرور الجديدة")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.customPrimaryText)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        
                        HStack {
                            Button(action: { isNewPasswordVisible.toggle() }) {
                                Image(systemName: isNewPasswordVisible ? "eye.slash" : "eye")
                                    .foregroundColor(.gray)
                            }
                            // إضافة نطق لزر العين
                            .simultaneousGesture(TapGesture().onEnded {
                                if AccessibilityManager.shared.isAVSpeechEnabled {
                                    DitharVoiceAssistant.shared.speak("إظهار أو إخفاء كلمة المرور الجديدة")
                                }
                            })
                            
                            if isNewPasswordVisible {
                                TextField("", text: $newPassword)
                                    .multilineTextAlignment(.trailing)
                            } else {
                                SecureField("", text: $newPassword)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        
                        // Password Requirements (الشروط الأربعة)
                        VStack(alignment: .leading, spacing: 6) {
                            PasswordRequirementRow(
                                text: "8 أحرف على الأقل",
                                isMet: newPassword.count >= 8
                            )
                            PasswordRequirementRow(
                                text: "حرف كبير واحد على الأقل",
                                isMet: newPassword.contains(where: { $0.isUppercase })
                            )
                            PasswordRequirementRow(
                                text: "رقم واحد على الأقل",
                                isMet: newPassword.contains(where: { $0.isNumber })
                            )
                            PasswordRequirementRow(
                                text: "رمز خاص واحد على الأقل (@!#$%&*...)",
                                isMet: {
                                    let specialChars = "@!#$%^&*()_+-=[]{}|;:',.<>?/~`"
                                    return newPassword.contains(where: { specialChars.contains($0) })
                                }()
                            )
                        }
                        .padding(.top, 4)
                    }
                    
                    // Confirm Password
                    VStack(alignment: .trailing, spacing: 8) {
                        Text("تأكيد كلمة المرور")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.customPrimaryText)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        
                        HStack {
                            Button(action: { isConfirmPasswordVisible.toggle() }) {
                                Image(systemName: isConfirmPasswordVisible ? "eye.slash" : "eye")
                                    .foregroundColor(.gray)
                            }
                            // إضافة نطق لزر العين
                            .simultaneousGesture(TapGesture().onEnded {
                                if AccessibilityManager.shared.isAVSpeechEnabled {
                                    DitharVoiceAssistant.shared.speak("إظهار أو إخفاء تأكيد كلمة المرور")
                                }
                            })
                            
                            if isConfirmPasswordVisible {
                                TextField("", text: $confirmPassword)
                                    .multilineTextAlignment(.trailing)
                            } else {
                                SecureField("", text: $confirmPassword)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                    
                    Spacer()
                    
                    Button(action: changePassword) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("تغيير كلمة المرور")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isPasswordValid ? Color.green : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(!isPasswordValid || isLoading)
                    // إضافة نطق عند اللمس لزر التغيير
                    .simultaneousGesture(TapGesture().onEnded {
                        if AccessibilityManager.shared.isAVSpeechEnabled {
                            DitharVoiceAssistant.shared.speak("زر تنفيذ تغيير كلمة المرور")
                        }
                    })
                }
                .padding(20)
            }
            .navigationBarTitle("تغيير كلمة المرور", displayMode: .inline)
            .navigationBarItems(leading: Button("إلغاء") {
                presentationMode.wrappedValue.dismiss()
            }
            .simultaneousGesture(TapGesture().onEnded {
                if AccessibilityManager.shared.isAVSpeechEnabled {
                    DitharVoiceAssistant.shared.speak("زر إلغاء")
                }
            }))
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(isSuccess ? "نجح" : "خطأ"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("حسنًا")) {
                        if isSuccess {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                )
            }
        }
    }
    
    private var isPasswordValid: Bool {
        let hasMinLength = newPassword.count >= 8
        let hasUppercase = newPassword.contains(where: { $0.isUppercase })
        let hasNumber = newPassword.contains(where: { $0.isNumber })
        let specialChars = "@!#$%^&*()_+-=[]{}|;:',.<>?/~`"
        let hasSpecialChar = newPassword.contains(where: { specialChars.contains($0) })
        let passwordsMatch = newPassword == confirmPassword && !newPassword.isEmpty
        
        return hasMinLength && hasUppercase && hasNumber && hasSpecialChar && passwordsMatch && !currentPassword.isEmpty
    }
    
    private func changePassword() {
        guard let user = Auth.auth().currentUser else { return }
        guard let email = user.email else { return }
        
        isLoading = true
        
        // Re-authenticate user
        let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
        
        user.reauthenticate(with: credential) { _, error in
            if let error = error {
                isLoading = false
                alertMessage = "كلمة المرور الحالية غير صحيحة"
                isSuccess = false
                showAlert = true
                return
            }
            
            // Update password
            user.updatePassword(to: newPassword) { error in
                isLoading = false
                if let error = error {
                    alertMessage = "فشل تغيير كلمة المرور: \(error.localizedDescription)"
                    isSuccess = false
                } else {
                    alertMessage = "تم تغيير كلمة المرور بنجاح"
                    isSuccess = true
                }
                showAlert = true
            }
        }
    }
}

// MARK: - Password Requirement Row
struct PasswordRequirementRow: View {
    let text: String
    let isMet: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Spacer()
            
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(isMet ? .green : .gray)
            
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12))
                .foregroundColor(isMet ? .green : .gray)
        }
    }
}


// MARK: - Reusable card
private struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 20)
    }
}

// MARK: - About
struct AboutSection: View {
    var body: some View {
        VStack(spacing: 0) {
            CustomRowS(title: "حول دِثار", iconName: "info.circle.fill", hasChevron: true)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
        }
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 20)
    }
}

// MARK: - CustomRowS
struct CustomRowS: View {
    let title: String
    let iconName: String
    let hasChevron: Bool
    var action: (() -> Void)? = nil
    
    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 18))
                    .foregroundColor(.customIconColor)
                
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.customPrimaryText)
                
                Spacer()
                
                if hasChevron {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.gray.opacity(0.5))
                }
            }
        }
        .buttonStyle(.plain)
    }
}


extension Color {
    static let customBackground = Color(red: 0.97, green: 0.97, blue: 0.96)
    static let customPrimaryText = Color(red: 0.35, green: 0.30, blue: 0.25)
    static let customIconColor = Color(red: 0.5, green: 0.45, blue: 0.38)
    static let customHeaderBackground = Color(red: 0.94, green: 0.96, blue: 0.94)
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environment(\.layoutDirection, .rightToLeft)
    }
}
