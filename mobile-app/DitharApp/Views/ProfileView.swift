import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import PhotosUI
import FirebaseStorage
import UserNotifications

// MARK: - Profile View
struct ProfileView: View {
    @State private var userName: String = "جارٍ التحميل..."
    @State private var currentPhotoURL: String? = nil
    @State private var pickedItem: PhotosPickerItem? = nil
    @State private var pickedImage: UIImage? = nil
    @State private var isUploadingPhoto = false
    @State private var bioText: String = ""
    @State private var originalBio: String = ""
    @State private var isSavingBio = false
    @State private var showBioEditor = false
    @State private var createdAt: Date? = nil
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.accessibilityManager) private var accessibilityManager
    
    // مساعد الصوت المدمج
    private let assistant = DitharVoiceAssistant.shared

    var body: some View {
        ZStack {
            Color.customBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    // MARK: - Header Card (الصورة + الاسم + النبذة)
                    VStack(spacing: 12) {
                        // صورة الملف الشخصي + زر التعديل
                        AvatarView(displayName: userName, urlString: currentPhotoURL, size: 110)
                            .accessibilityLabel("صورة الملف الشخصي للمستخدم \(userName)")
                            .accessibilityHint("اضغط على زر تعديل الصورة لتغيير صورة الملف الشخصي")
                            .overlay(alignment: .bottomTrailing) {
                                PhotosPicker(selection: $pickedItem, matching: .images) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.black.opacity(0.35))
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .labelStyle(.iconOnly)
                                .padding(6)
                                .accessibilityLabel("تغيير صورة الملف الشخصي")
                                .accessibilityHint("يفتح ألبوم الصور لاختيار صورة جديدة")
                                .simultaneousGesture(TapGesture().onEnded {
                                    if assistant.canUseAVSpeech {
                                        assistant.speak("زر تغيير صورة الملف الشخصي")
                                    }
                                })
                            }

                        // اسم المستخدم
                        Text(userName)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.customPrimaryText)
                            .multilineTextAlignment(.center)
                            .accessibilityLabel("اسم المستخدم: \(userName)")
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if assistant.canUseAVSpeech {
                                    assistant.speak("اسم المستخدم: \(userName)")
                                }
                            }

                        // النبذة
                        let trimmedBio = bioText.trimmingCharacters(in: .whitespacesAndNewlines)
                        Text(trimmedBio.isEmpty
                             ? "لا توجد نبذة بعد، اضغط لإضافة نبذة."
                             : trimmedBio)
                            .font(.system(size: 15))
                            .foregroundColor(.customPrimaryText.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 30)
                            .onTapGesture { showBioEditor = true }
                            .simultaneousGesture(TapGesture().onEnded {
                                if assistant.canUseAVSpeech {
                                    assistant.speak("تعديل النبذة الشخصية")
                                }
                            })
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(
                                trimmedBio.isEmpty
                                ? "لا توجد نبذة بعد. اضغط لإضافة نبذة عنك."
                                : "النبذة الشخصية: \(trimmedBio)"
                            )
                            .accessibilityHint("اضغط لتحرير أو تعديل النبذة الشخصية")

                        if isUploadingPhoto {
                            ProgressView()
                                .padding(.top, 6)
                                .accessibilityLabel("جاري رفع صورة الملف الشخصي")
                        }
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(Color.customHeaderBackground)
                            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
                    )
                    .padding(.horizontal, 20)
                    .accessibilityElement(children: .contain)
                    .accessibilityHint("يتضمن صورة الملف الشخصي، اسم المستخدم، والنبذة القصيرة")

                    // MARK: - بطاقة المعلومات الشخصية
                    PersonalInfoInlineCard()
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                        .padding(.horizontal, 20)

                    // MARK: - تاريخ الانضمام
                    if let createdAt = createdAt {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .foregroundColor(Color(red: 0.47, green: 0.58, blue: 0.44))
                                .accessibilityHidden(true)
                            Text("عضو منذ \(formatDate(createdAt))")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 10)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("عضو في دثار منذ \(formatDate(createdAt))")
                    }

                    Spacer().frame(height: 24)
                }
                .padding(.top, 10)
            }
        }
        .navigationTitle("الملف الشخصي")
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
                .accessibilityLabel("رجوع")
                .accessibilityHint("العودة إلى الشاشة السابقة")
                .simultaneousGesture(TapGesture().onEnded {
                    if assistant.canUseAVSpeech {
                        assistant.speak("زر الرجوع")
                    }
                })
            }
        }
        .onAppear {
            fetchUserName()
            fetchCurrentPhotoURL()
            loadBio()
            // ✅ ما عاد فيه نطق تلقائي عند فتح الصفحة
        }
        .onChange(of: pickedItem) { _ in
            Task { await handlePickedPhoto() }
        }
        .sheet(isPresented: $showBioEditor) {
            BioEditorSheet(initialText: bioText, maxChars: 200) { newText in
                saveBio(newText)
                showBioEditor = false
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar_SA")
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func fetchUserName() {
        guard let user = Auth.auth().currentUser else { userName = "زائر"; return }
        Firestore.firestore().collection("users").document(user.uid).getDocument { doc, _ in
            if let d = doc, d.exists {
                self.userName = d.get("fullName") as? String ?? "بدون اسم"
                if let ts = d.get("createdAt") as? Timestamp { self.createdAt = ts.dateValue() }
            } else { self.userName = "غير معروف" }
        }
    }
    
    private func fetchCurrentPhotoURL() {
        guard let user = Auth.auth().currentUser else { return }
        Firestore.firestore().collection("users").document(user.uid).getDocument { doc, _ in
            currentPhotoURL = doc?.get("photoURL") as? String
        }
    }
    
    private func loadBio() {
        guard let user = Auth.auth().currentUser else { return }
        Firestore.firestore().collection("users").document(user.uid).getDocument { doc, _ in
            let bio = (doc?.get("bio") as? String) ?? ""
            self.bioText = bio
            self.originalBio = bio
        }
    }
    
    private func saveBio(_ newText: String) {
        guard let user = Auth.auth().currentUser else { return }
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= 200 else { return }
        isSavingBio = true
        Firestore.firestore().collection("users").document(user.uid)
            .setData(["bio": trimmed, "updatedAt": Timestamp()], merge: true) { err in
                DispatchQueue.main.async {
                    self.isSavingBio = false
                    if err == nil {
                        self.bioText = trimmed
                        self.originalBio = trimmed
                        DitharVoiceAssistant.shared.speak("تم حفظ النبذة الشخصية بنجاح.", interrupt: true)
                    } else {
                        DitharVoiceAssistant.shared.speak("تعذر حفظ النبذة الشخصية. حاول مرة أخرى.", interrupt: true)
                    }
                }
            }
    }
    
    private func handlePickedPhoto() async {
        guard let item = pickedItem else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let ui = UIImage(data: data) {
            await MainActor.run { pickedImage = ui }
            await uploadProfileImage(ui)
        }
    }
    
    private func uploadProfileImage(_ image: UIImage) async {
        guard let user = Auth.auth().currentUser,
              let data = image.jpegData(compressionQuality: 0.85) else { return }
        await MainActor.run { isUploadingPhoto = true }
        do {
            let ref = Storage.storage().reference().child("profiles/\(user.uid).jpg")
            _ = try await ref.putDataAsync(data, metadata: nil)
            let url = try await ref.downloadURL()
            try await Firestore.firestore().collection("users")
                .document(user.uid)
                .setData(["photoURL": url.absoluteString, "updatedAt": Timestamp()], merge: true)
            await MainActor.run {
                currentPhotoURL = url.absoluteString
                DitharVoiceAssistant.shared.speak("تم تحديث صورة الملف الشخصي بنجاح.", interrupt: true)
            }
        } catch {
            await MainActor.run {
                DitharVoiceAssistant.shared.speak("تعذر تحديث صورة الملف الشخصي. حاول مرة أخرى.", interrupt: true)
            }
        }
        await MainActor.run { isUploadingPhoto = false }
    }
}

// MARK: - Bio Editor Sheet
struct BioEditorSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.accessibilityManager) private var accessibilityManager
    @State private var text: String
    let maxChars: Int
    let onSave: (String) -> Void
    
    init(initialText: String, maxChars: Int = 200, onSave: @escaping (String) -> Void) {
        _text = State(initialValue: initialText)
        self.maxChars = maxChars
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.customBackground.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 12) {
                    // عدّاد الأحرف
                    HStack {
                        Text("\(text.count)/\(maxChars)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .accessibilityLabel("عدد الأحرف الحالية \(text.count) من \(maxChars)")
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    // حقل النبذة
                    ZStack(alignment: .topTrailing) {
                        TextEditor(text: $text)
                            .frame(minHeight: 140)
                            .padding(10)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
                            )
                            .onChange(of: text) { newVal in
                                if newVal.count > maxChars {
                                    text = String(newVal.prefix(maxChars))
                                }
                            }
                            .padding(.horizontal, 20)
                            .accessibilityLabel("حقل النبذة الشخصية")
                            .accessibilityHint("اكتب نبذة بسيطة عن نفسك بحد أقصى \(maxChars) حرفاً")

                        if text.isEmpty {
                            Text("اكتب نبذة بسيطة عنك…")
                                .foregroundColor(.gray.opacity(0.7))
                                .padding(.top, 28)
                                .padding(.leading, 34)
                                .accessibilityHidden(true)
                        }
                    }
                    
                    Button {
                        onSave(text.trimmingCharacters(in: .whitespacesAndNewlines))
                    } label: {
                        Text("حفظ")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 0.47, green: 0.58, blue: 0.44))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                    }
                    .accessibilityLabel("حفظ النبذة")
                    .accessibilityHint("اضغط لحفظ النبذة والعودة إلى الملف الشخصي")
                    .simultaneousGesture(TapGesture().onEnded {
                        let assistant = DitharVoiceAssistant.shared
                        if assistant.canUseAVSpeech {
                            assistant.speak("زر حفظ النبذة")
                        }
                    })
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("تحرير النبذة")
            .navigationBarItems(
                leading: Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.customPrimaryText)
                }
                .accessibilityLabel("إغلاق")
                .accessibilityHint("إغلاق محرر النبذة والعودة إلى الملف الشخصي بدون حفظ")
                .simultaneousGesture(TapGesture().onEnded {
                    let assistant = DitharVoiceAssistant.shared
                    if assistant.canUseAVSpeech {
                        assistant.speak("إلغاء التعديل")
                    }
                })
            )
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
}

// MARK: - Personal Info Inline Card
struct PersonalInfoInlineCard: View {
    @State private var fullName = ""
    @State private var username = ""
    @State private var email = ""
    @State private var backupFullName = ""
    @State private var backupUsername = ""
    @State private var backupEmail = ""
    @State private var isEditingName = false
    @State private var isEditingUsername = false
    @State private var isEditingEmail = false
    @State private var originalEmail = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showReauthSheet = false
    @State private var reauthPassword = ""
    @State private var pendingEmailToSave: String? = nil
    @State private var reauthErrorMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("المعلومات الشخصية")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.customPrimaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 14)
                    .padding(.horizontal, 16)
                    .accessibilityAddTraits(.isHeader)
                Divider().padding(.horizontal, 12)
            }

            fieldRow(
                title: "الاسم الكامل",
                value: $fullName,
                isEditing: $isEditingName,
                backupValue: $backupFullName,
                keyboard: .default,
                onSave: saveName
            )

            Divider().padding(.horizontal, 12)

            fieldRow(
                title: "اسم المستخدم",
                value: $username,
                isEditing: $isEditingUsername,
                backupValue: $backupUsername,
                keyboard: .default,
                onSave: saveUsername
            )

            Divider().padding(.horizontal, 12)

            fieldRow(
                title: "البريد الإلكتروني",
                value: $email,
                isEditing: $isEditingEmail,
                backupValue: $backupEmail,
                keyboard: .emailAddress,
                onSave: prepareToSaveEmail
            )

            Spacer(minLength: 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 16)
        .onAppear(perform: loadUserData)
        .sheet(isPresented: $showReauthSheet) {
            ReauthSheetView(
                password: $reauthPassword,
                onConfirm: { reauthAndUpdateEmail() },
                onCancel: {
                    showReauthSheet = false
                    email = backupEmail
                    isEditingEmail = false
                },
                isLoading: $isLoading,
                errorMessage: $reauthErrorMessage
            )
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("تنبيه"),
                message: Text(alertMessage),
                dismissButton: .default(Text("حسنًا"))
            )
        }
        .environment(\.layoutDirection, .rightToLeft)
        .accessibilityElement(children: .contain)
        .accessibilityHint("يتضمن الاسم الكامل، اسم المستخدم، والبريد الإلكتروني مع إمكانية التعديل")
    }

    private func fieldRow(
        title: String,
        value: Binding<String>,
        isEditing: Binding<Bool>,
        backupValue: Binding<String>,
        keyboard: UIKeyboardType,
        onSave: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.customPrimaryText)
                    .accessibilityHidden(true)

                Spacer()

                if isEditing.wrappedValue {
                    HStack(spacing: 16) {
                        Button {
                            onSave()
                        } label: {
                            if isLoading && (isEditing.wrappedValue && title != "البريد الإلكتروني") {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(red: 0.47, green: 0.58, blue: 0.44))
                            }
                        }
                        .disabled(isLoading)
                        .accessibilityLabel("حفظ \(title)")
                        .accessibilityHint("اضغط لحفظ التعديلات على \(title)")
                        .simultaneousGesture(TapGesture().onEnded {
                            let assistant = DitharVoiceAssistant.shared
                            if assistant.canUseAVSpeech {
                                assistant.speak("حفظ \(title)")
                            }
                        })

                        Button {
                            value.wrappedValue = backupValue.wrappedValue
                            isEditing.wrappedValue = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                        .accessibilityLabel("إلغاء تعديل \(title)")
                        .accessibilityHint("اضغط لإلغاء التعديلات والعودة للقيمة السابقة")
                        .simultaneousGesture(TapGesture().onEnded {
                            let assistant = DitharVoiceAssistant.shared
                            if assistant.canUseAVSpeech {
                                assistant.speak("إلغاء تعديل \(title)")
                            }
                        })
                    }
                } else {
                    Button {
                        backupValue.wrappedValue = value.wrappedValue
                        isEditing.wrappedValue = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.customPrimaryText.opacity(0.8))
                    }
                    .accessibilityLabel("تعديل \(title)")
                    .accessibilityHint("اضغط لتعديل حقل \(title)")
                    .simultaneousGesture(TapGesture().onEnded {
                        let assistant = DitharVoiceAssistant.shared
                        if assistant.canUseAVSpeech {
                            assistant.speak("تعديل \(title)")
                        }
                    })
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Group {
                if isEditing.wrappedValue {
                    TextField("", text: value)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .keyboardType(keyboard)
                        .accessibilityLabel(title)
                        .accessibilityHint("أدخل \(title) الجديد")
                } else {
                    Text(value.wrappedValue.isEmpty ? "—" : value.wrappedValue)
                        .foregroundColor(.customPrimaryText.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .accessibilityLabel(
                            "\(title): \(value.wrappedValue.isEmpty ? "غير محدد" : value.wrappedValue)"
                        )
                }
            }
            .padding(.bottom, 12)
        }
    }

    private func loadUserData() {
        guard let user = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { document, _ in
            self.fullName = document?.get("fullName") as? String ?? ""
            self.username = document?.get("username") as? String ?? ""
            let authEmail = user.email ?? (document?.get("email") as? String ?? "")
            self.email = authEmail
            self.originalEmail = authEmail
        }
    }

    private func saveName() {
        let newVal = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newVal.isEmpty else {
            self.alertMessage = "يرجى إدخال الاسم الكامل"
            self.showAlert = true
            return
        }
        updateFirestore(["fullName": newVal]) {
            self.isEditingName = false
            self.alertMessage = "تم حفظ الاسم بنجاح"
            self.showAlert = true
            DitharVoiceAssistant.shared.speak("تم حفظ الاسم الكامل بنجاح.", interrupt: true)
        }
    }

    private func saveUsername() {
        let newVal = username
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !newVal.isEmpty else {
            self.alertMessage = "يرجى إدخال اسم المستخدم"
            self.showAlert = true
            return
        }
        guard newVal.count >= 3 else {
            self.alertMessage = "اسم المستخدم يجب أن يكون 3 أحرف على الأقل"
            self.showAlert = true
            return
        }
        guard newVal.count <= 15 else {
            self.alertMessage = "اسم المستخدم يجب ألا يزيد عن 15 حرف"
            self.showAlert = true
            return
        }
        let usernameRegex = "^[a-zA-Z0-9_]+$"
        guard NSPredicate(format: "SELF MATCHES %@", usernameRegex).evaluate(with: newVal) else {
            self.alertMessage = "اسم المستخدم يجب أن يحتوي على أحرف وأرقام فقط"
            self.showAlert = true
            return
        }
        checkUsernameAvailability(newVal)
    }

    private func prepareToSaveEmail() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmedEmail != originalEmail else {
            self.isEditingEmail = false
            return
        }
        
        guard !trimmedEmail.isEmpty else {
            self.alertMessage = "يرجى إدخال البريد الإلكتروني"
            self.showAlert = true
            return
        }
        
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        guard NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: trimmedEmail) else {
            self.alertMessage = "البريد الإلكتروني غير صحيح"
            self.showAlert = true
            return
        }
        
        self.backupEmail = originalEmail
        self.pendingEmailToSave = trimmedEmail
        self.reauthPassword = ""
        self.reauthErrorMessage = nil
        self.showReauthSheet = true
    }

    private func updateFirestore(_ data: [String: Any], onSuccess: @escaping () -> Void) {
        guard let user = Auth.auth().currentUser else { return }
        
        var payload = data
        payload["updatedAt"] = Timestamp()

        Firestore.firestore().collection("users").document(user.uid).setData(payload, merge: true) { err in
            if let err = err {
                self.isLoading = false
                self.alertMessage = "فشل تحديث البيانات: \(err.localizedDescription)"
                self.showAlert = true
                DitharVoiceAssistant.shared.speak("تعذر تحديث البيانات. حاول مرة أخرى.", interrupt: true)
            } else {
                onSuccess()
            }
        }
    }
    
    private func reauthAndUpdateEmail() {
        guard let user = Auth.auth().currentUser,
              let currentAuthEmail = user.email,
              let newEmail = pendingEmailToSave,
              !reauthPassword.isEmpty else { return }
        
        self.isLoading = true
        self.reauthErrorMessage = nil
        let credential = EmailAuthProvider.credential(withEmail: currentAuthEmail, password: reauthPassword)

        user.reauthenticate(with: credential) { _, error in
            if let _ = error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.reauthErrorMessage = "كلمة المرور الحالية غير صحيحة"
                }
                return
            }
            
            user.updateEmail(to: newEmail) { emailErr in
                if let emailErr = emailErr {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.showReauthSheet = false
                        self.alertMessage = "فشل تغيير البريد: \(emailErr.localizedDescription)"
                        self.showAlert = true
                        DitharVoiceAssistant.shared.speak("تعذر تغيير البريد الإلكتروني. حاول مرة أخرى.", interrupt: true)
                    }
                    return
                }
                
                let db = Firestore.firestore()
                db.collection("users").document(user.uid).updateData(["email": newEmail]) { firestoreError in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.showReauthSheet = false
                        
                        if let firestoreError = firestoreError {
                            self.alertMessage = "فشل تحديث البريد في قاعدة البيانات: \(firestoreError.localizedDescription)"
                            self.showAlert = true
                            DitharVoiceAssistant.shared.speak("تعذر حفظ البريد الإلكتروني الجديد في قاعدة البيانات.", interrupt: true)
                        } else {
                            self.email = newEmail
                            self.originalEmail = newEmail
                            self.isEditingEmail = false
                            self.alertMessage = "تم تحديث البريد الإلكتروني بنجاح."
                            self.showAlert = true
                            DitharVoiceAssistant.shared.speak("تم تحديث البريد الإلكتروني بنجاح.", interrupt: true)
                        }
                    }
                }
            }
        }
    }
    
    private func checkUsernameAvailability(_ newUsername: String) {
        guard let currentUser = Auth.auth().currentUser else { return }
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        Firestore.firestore().collection("users")
            .whereField("username", isEqualTo: newUsername)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    if let error = error {
                        self.alertMessage = "فشل التحقق: \(error.localizedDescription)"
                        self.showAlert = true
                        return
                    }
                    
                    if let docs = snapshot?.documents, !docs.isEmpty {
                        let isOwnUsername = docs.allSatisfy { $0.documentID == currentUser.uid }
                        if !isOwnUsername {
                            self.alertMessage = "اسم المستخدم مستخدم من قبل"
                            self.showAlert = true
                            return
                        }
                    }
                    
                    self.updateFirestore(["username": newUsername]) {
                        self.isEditingUsername = false
                        self.alertMessage = "تم حفظ اسم المستخدم بنجاح"
                        self.showAlert = true
                        DitharVoiceAssistant.shared.speak("تم حفظ اسم المستخدم بنجاح.", interrupt: true)
                    }
                }
            }
    }
}

// MARK: - Reauth Sheet View
struct ReauthSheetView: View {
    @Binding var password: String
    var onConfirm: () -> Void
    var onCancel: () -> Void
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("للتأكيد، يرجى إدخال كلمة المرور الحالية")
                    .font(.system(size: 16))
                    .foregroundColor(.customPrimaryText)
                    .multilineTextAlignment(.center)
                    .padding()
                    .accessibilityLabel("للتأكيد، يرجى إدخال كلمة المرور الحالية لحسابك")

                SecureField("كلمة المرور", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .multilineTextAlignment(.leading)
                    .disabled(isLoading)
                    .accessibilityLabel("كلمة المرور الحالية")
                    .accessibilityHint("أدخل كلمة المرور الحالية لحسابك")

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                        .accessibilityLabel(errorMessage)
                }
                
                if isLoading {
                    ProgressView()
                        .padding()
                        .accessibilityLabel("جاري التحقق من كلمة المرور")
                } else {
                    HStack(spacing: 16) {
                        Button("إلغاء", action: onCancel)
                            .foregroundColor(.red)
                            .accessibilityLabel("إلغاء")
                            .accessibilityHint("إلغاء العملية والعودة بدون تغيير البريد الإلكتروني")
                            .simultaneousGesture(TapGesture().onEnded {
                                let assistant = DitharVoiceAssistant.shared
                                if assistant.canUseAVSpeech {
                                    assistant.speak("إلغاء")
                                }
                            })
                        
                        Button("تأكيد", action: onConfirm)
                            .fontWeight(.bold)
                            .accessibilityLabel("تأكيد")
                            .accessibilityHint("تأكيد كلمة المرور الحالية ومتابعة تغيير البريد الإلكتروني")
                            .simultaneousGesture(TapGesture().onEnded {
                                let assistant = DitharVoiceAssistant.shared
                                if assistant.canUseAVSpeech {
                                    assistant.speak("تأكيد")
                                }
                            })
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("إعادة التحقق")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
}
