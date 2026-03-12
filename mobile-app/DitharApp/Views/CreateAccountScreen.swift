import SwiftUI

struct CreateAccountScreen: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.presentationMode) var presentationMode
    
    // MARK: - State Variables
    @State private var fullName = ""
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    @State private var hasVisualImpairment = false
        
    @State private var nameError = ""
    @State private var usernameError = ""
    @State private var emailError = ""
    @State private var passwordError = ""
    @State private var confirmPasswordError = ""
    
    @State private var isCheckingUsername = false
    @State private var usernameAvailable: Bool? = nil
    @State private var usernameCheckTask: Task<Void, Never>?

    // MARK: - Colors
    let primaryGreen = Color(red: 0.44, green: 0.6, blue: 0.44)
    let darkText = Color(red: 0.1, green: 0.1, blue: 0.1)
    
    var body: some View {
        ZStack {
            // 1. الخلفية الخارجية
            primaryGreen
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // زر الرجوع
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "arrow.right")
                            .font(.title2)
                            .padding(10)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding(.top, 50)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

                // 2. العبارة الترحيبية
                Text("ابدأ رحلتك مع دثار خزانتك الذكية")
                    .font(Font.custom("RH-Zak", size: 28))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                    .accessibilityAddTraits(.isHeader)

                // 3. الكارد الأبيض
                ZStack {
                    Color.white
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
                        .ignoresSafeArea(.all, edges: .bottom)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            
                            // الحقول
                            VStack(spacing: 16) {
                                
                                ModernTextFieldLight(
                                    icon: "person",
                                    placeholder: "الاسم الكامل",
                                    text: $fullName,
                                    errorMessage: $nameError
                                )

                                // حقل اسم المستخدم
                                VStack(alignment: .trailing, spacing: 5) {
                                    ModernTextFieldLight(
                                        icon: "at",
                                        placeholder: "اسم المستخدم",
                                        text: $username,
                                        errorMessage: $usernameError,
                                        trailingView: AnyView(usernameStatusView)
                                    )
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    
                                    if let available = usernameAvailable, !available, usernameError.isEmpty {
                                        Text("اسم المستخدم مستخدم بالفعل")
                                            .font(.caption2)
                                            .foregroundColor(.red)
                                    } else if let available = usernameAvailable, available, usernameError.isEmpty {
                                        Text("اسم المستخدم متاح")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                    }
                                }

                                ModernTextFieldLight(
                                    icon: "envelope",
                                    placeholder: "البريد الإلكتروني",
                                    text: $email,
                                    errorMessage: $emailError,
                                    keyboardType: .emailAddress
                                )

                                ModernSecureFieldLight(
                                    icon: "lock",
                                    placeholder: "كلمة المرور",
                                    text: $password,
                                    isVisible: $isPasswordVisible,
                                    errorMessage: $passwordError
                                )

                                ModernSecureFieldLight(
                                    icon: "lock.shield",
                                    placeholder: "تأكيد كلمة المرور",
                                    text: $confirmPassword,
                                    isVisible: $isConfirmPasswordVisible,
                                    errorMessage: $confirmPasswordError
                                )
                            }
                            .padding(.top, 30)

                            // خيار الإعاقة البصرية
                            Toggle(isOn: $hasVisualImpairment) {
                                Text("هل لديك إعاقة بصرية ؟")
                                    .foregroundColor(darkText)
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .toggleStyle(SwitchToggleStyle(tint: primaryGreen))
                            .padding(.vertical, 5)

                            // رسائل الخطأ العامة
                            if !authManager.errorMessage.isEmpty {
                                Text(authManager.errorMessage)
                                    .font(.footnote)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(authManager.errorMessage.contains("بنجاح") ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                                    .foregroundColor(authManager.errorMessage.contains("بنجاح") ? .green : .red)
                                    .cornerRadius(8)
                            }

                            // زر إنشاء الحساب
                            Button(action: {
                                createAccount()
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(primaryGreen)
                                    
                                    HStack {
                                        if authManager.isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        }
                                        
                                        Text(authManager.isLoading ? "جاري الإنشاء..." : "إنشاء حساب")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(height: 55)
                            }
                            .disabled(authManager.isLoading || usernameAvailable == false)
                            .padding(.top, 10)
                            .padding(.bottom, 40)
                        }
                        .padding(.horizontal, 25)
                    }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .navigationBarHidden(true)
        .onAppear {
            DitharVoiceAssistant.shared.announceScreenChange("شاشة إنشاء حساب جديد...")
        }
        .onChange(of: authManager.errorMessage) { newValue in
            guard !newValue.isEmpty else { return }
            DitharVoiceAssistant.shared.speak(newValue, interrupt: true)
        }
        .onChange(of: fullName) { _ in validateName() }
        .onChange(of: username) { _ in
            validateUsername()
            checkUsernameAvailability()
        }
        .onChange(of: email) { _ in validateEmail() }
        .onChange(of: password) { _ in validatePassword() }
        .onChange(of: confirmPassword) { _ in validateConfirmPassword() }
    }
    
    var usernameStatusView: some View {
        Group {
            if isCheckingUsername {
                ProgressView()
                    .scaleEffect(0.6)
            } else if let available = usernameAvailable {
                Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(available ? .green : .red)
            }
        }
    }

    // MARK: - Validation Logic (Updated)
    
    private func createAccount() {
        clearErrors()
        let isValid = validateAllFields()
        if isValid && usernameAvailable == true {
            Task {
                await authManager.signUp(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password,
                    fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                    username: username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                    hasVisualImpairment: hasVisualImpairment
                )
            }
        }
    }
    
    private func checkUsernameAvailability() {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        usernameCheckTask?.cancel()
        guard trimmedUsername.count >= 3 else {
            usernameAvailable = nil; isCheckingUsername = false; return
        }
        let usernameRegex = "^[a-zA-Z0-9_]+$"
        guard NSPredicate(format: "SELF MATCHES %@", usernameRegex).evaluate(with: trimmedUsername) else {
            usernameAvailable = nil; isCheckingUsername = false; return
        }
        isCheckingUsername = true; usernameAvailable = nil
        usernameCheckTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            guard trimmedUsername == username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
                await MainActor.run { isCheckingUsername = false }; return
            }
            let available = await authManager.checkUsernameAvailability(trimmedUsername)
            await MainActor.run { isCheckingUsername = false; usernameAvailable = available }
        }
    }
    
    private func validateAllFields() -> Bool {
        return validateName() && validateUsername() && validateEmail() && validatePassword() && validateConfirmPassword()
    }
    
    @discardableResult private func validateName() -> Bool {
        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty { nameError = "يرجى إدخال الاسم الكامل"; return false }
        if trimmedName.count > 20 { nameError = "الاسم يجب ألا يزيد عن 20 حرف"; return false }
        let nameRegex = "^[a-zA-Zأ-ي\\s]+$"
        if !NSPredicate(format: "SELF MATCHES %@", nameRegex).evaluate(with: trimmedName) { nameError = "أحرف فقط"; return false }
        nameError = ""; return true
    }
    
    @discardableResult private func validateUsername() -> Bool {
        let trimmed = username.replacingOccurrences(of: " ", with: "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty { usernameError = "يرجى إدخال اسم المستخدم"; return false }
        if trimmed.count < 3 { usernameError = "3 أحرف على الأقل"; return false }
        if trimmed.count > 15 { usernameError = "15 حرف كحد أقصى"; return false }
        let regex = "^[a-zA-Z0-9_]+$"
        if !NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: trimmed) { usernameError = "أحرف وأرقام إنجليزية فقط"; return false }
        usernameError = ""; return true
    }
    
    @discardableResult private func validateEmail() -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { emailError = "مطلوب"; return false }
        let regex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        if !NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: trimmed) { emailError = "بريد غير صحيح"; return false }
        emailError = ""; return true
    }
    
    // *** دالة التحقق من كلمة المرور المحدثة ***
    @discardableResult private func validatePassword() -> Bool {
        if password.isEmpty {
            passwordError = "مطلوب"
            return false
        }
        
        // 1. التحقق من الطول (8 أحرف)
        if password.count < 8 {
            passwordError = "8 أحرف على الأقل"
            return false
        }
        
        // 2. التحقق من الحرف الكبير
        let hasUpperCase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        if !hasUpperCase {
            passwordError = "حرف كبير واحد على الأقل"
            return false
        }
        
        // 3. التحقق من الأرقام
        let hasNumber = password.range(of: "[0-9]", options: .regularExpression) != nil
        if !hasNumber {
            passwordError = "رقم واحد على الأقل"
            return false
        }
        
        // 4. التحقق من الرموز الخاصة
        let hasSpecialChar = password.range(of: "[!@#$%^&*(),.?\":{}|<>]", options: .regularExpression) != nil
        if !hasSpecialChar {
            passwordError = "رمز خاص واحد على الأقل"
            return false
        }
        
        passwordError = ""
        return true
    }
    
    @discardableResult private func validateConfirmPassword() -> Bool {
        if confirmPassword.isEmpty { confirmPasswordError = "مطلوب"; return false }
        if password != confirmPassword { confirmPasswordError = "غير متطابقة"; return false }
        confirmPasswordError = ""; return true
    }
    
    private func clearErrors() {
        nameError = ""; usernameError = ""; emailError = ""; passwordError = ""; confirmPasswordError = ""
    }
}

// MARK: - Light Theme Components

struct ModernTextFieldLight: View {
    var icon: String
    var placeholder: String
    @Binding var text: String
    @Binding var errorMessage: String
    var trailingView: AnyView? = nil
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Color(red: 0.44, green: 0.6, blue: 0.44))
                    .frame(width: 20)
                
                TextField(placeholder, text: $text)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.black)
                    .font(.system(size: 16, weight: .medium))
                    .keyboardType(keyboardType)
                
                if let trailing = trailingView {
                    trailing
                }
            }
            .padding()
            .background(Color(red: 0.96, green: 0.96, blue: 0.96))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(errorMessage.isEmpty ? Color.clear : Color.red, lineWidth: 1)
            )

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .padding(.leading, 5)
            }
        }
    }
}

struct ModernSecureFieldLight: View {
    var icon: String
    var placeholder: String
    @Binding var text: String
    @Binding var isVisible: Bool
    @Binding var errorMessage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Color(red: 0.44, green: 0.6, blue: 0.44))
                    .frame(width: 20)

                if isVisible {
                    TextField(placeholder, text: $text)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.black)
                        .font(.system(size: 16, weight: .medium))
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                } else {
                    SecureField(placeholder, text: $text)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.black)
                        .font(.system(size: 16, weight: .medium))
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                }
                
                Button(action: { isVisible.toggle() }) {
                    Image(systemName: isVisible ? "eye.fill" : "eye.slash.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
            }
            .padding()
            .background(Color(red: 0.96, green: 0.96, blue: 0.96))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(errorMessage.isEmpty ? Color.clear : Color.red, lineWidth: 1)
            )

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .padding(.leading, 5)
            }
        }
    }
}
