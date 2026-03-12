import SwiftUI

struct LoginScreen: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var usernameOrEmail = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var showForgotPassword = false
    @State private var rememberMe = false
    
    // check if input data is correct and valid
    @State private var usernameOrEmailError = ""
    @State private var passwordError = ""

    // MARK: - Colors
    let primaryGreen = Color(red: 0.44, green: 0.6, blue: 0.44)
    let darkText = Color(red: 0.1, green: 0.1, blue: 0.1)

    var body: some View {
        ZStack {
            // 1. الخلفية الخارجية (نفس لون التطبيق)
            primaryGreen
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Bar (زر الرجوع)
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
                    .buttonAccessibility(label: "رجوع", hint: "العودة إلى الشاشة السابقة")
                    Spacer()
                }
                .padding(.top, 50)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                // 2. العنوان الترحيبي (خارج الكارد)
                Text("أهلاً بعودتك!")
                    .font(Font.custom("RH-Zak", size: 30))
                    .foregroundColor(.white)
                    .padding(.bottom, 30)
                    .accessibilityAddTraits(.isHeader)

                // 3. الكارد الأبيض (The White Card)
                ZStack {
                    Color.white
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
                        .ignoresSafeArea(.all, edges: .bottom)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 25) {
                            
                            // الحقول
                            VStack(spacing: 20) {
                                
                                LoginCustomTextField(
                                    icon: "person",
                                    placeholder: "اسم المستخدم أو البريد",
                                    text: $usernameOrEmail,
                                    errorMessage: $usernameOrEmailError,
                                    keyboardType: .emailAddress
                                )
                                .accessibilityLabel("اسم المستخدم أو البريد الإلكتروني")

                                LoginCustomSecureField(
                                    icon: "lock",
                                    placeholder: "كلمة المرور",
                                    text: $password,
                                    isVisible: $isPasswordVisible,
                                    errorMessage: $passwordError
                                )
                                .accessibilityLabel("كلمة المرور")
                            }
                            .padding(.top, 40)
                            
                            // خيارات (تذكرني + نسيت كلمة المرور)
                            HStack {
                                // زر نسيت كلمة المرور (يسار)
                                Button(action: {
                                    showForgotPassword = true
                                }) {
                                    Text("نسيت كلمة السر؟")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(primaryGreen)
                                }
                                
                                Spacer()
                                
                                // زر تذكرني (يمين)
                                Button(action: { rememberMe.toggle() }) {
                                    HStack(spacing: 8) {
                                        Text("تذكرني")
                                            .font(.system(size: 14))
                                            .foregroundColor(darkText)
                                        
                                        Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                                            .foregroundColor(rememberMe ? primaryGreen : .gray)
                                            .font(.system(size: 20))
                                    }
                                }
                                .accessibilityLabel("تذكرني")
                                .accessibilityValue(rememberMe ? "مفعل" : "غير مفعل")
                            }
                            .padding(.horizontal, 5)
                            
                            Spacer(minLength: 20)
                            
                            // رسائل الخطأ/النجاح
                            if !authManager.errorMessage.isEmpty {
                                Text(authManager.errorMessage)
                                    .font(.footnote)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(authManager.errorMessage.contains("بنجاح") ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                                    .foregroundColor(authManager.errorMessage.contains("بنجاح") ? .green : .red)
                                    .cornerRadius(8)
                            }
                            
                            // زر تسجيل الدخول
                            Button(action: {
                                signIn()
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(primaryGreen)
                                    
                                    HStack {
                                        if authManager.isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.8)
                                        }
                                        
                                        Text(authManager.isLoading ? "جاري الدخول..." : "تسجيل دخول")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(height: 55)
                            }
                            .disabled(authManager.isLoading)
                            .padding(.bottom, 40)
                        }
                        .padding(.horizontal, 25)
                    }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft) // الاتجاه عربي
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .navigationBarHidden(true)
        .onChange(of: usernameOrEmail) { _ in validateUsernameOrEmail() }
        .onChange(of: password) { _ in validatePassword() }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordScreen()
                .environmentObject(authManager)
        }
        .onAppear {
            loadRememberMe()
            DitharVoiceAssistant.shared.announceScreenChange("شاشة تسجيل الدخول...")
        }
        .onChange(of: authManager.errorMessage) { newValue in
            guard !newValue.isEmpty else { return }
            DitharVoiceAssistant.shared.speak(newValue, interrupt: true)
        }
    }
    
    // MARK: - Logic
    private func signIn() {
        clearErrors()
        let isValid = validateAllFields()
        guard isValid else { return }

        Task {
            let cleanInput = usernameOrEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

            await authManager.signInWithUsernameOrEmail(usernameOrEmail: cleanInput, password: cleanPassword)
            
            if authManager.errorMessage.isEmpty || authManager.errorMessage.contains("بنجاح") {
                saveRememberMe()
            }
        }
    }

    private func validateAllFields() -> Bool {
        return validateUsernameOrEmail() && validatePassword()
    }
    
    @discardableResult private func validateUsernameOrEmail() -> Bool {
        let trimmedInput = usernameOrEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedInput.isEmpty { usernameOrEmailError = "يرجى إدخال البريد أو اسم المستخدم"; return false }
        usernameOrEmailError = ""; return true
    }
    
    @discardableResult private func validatePassword() -> Bool {
        if password.isEmpty { passwordError = "يرجى إدخال كلمة المرور"; return false }
        passwordError = ""; return true
    }
    
    private func clearErrors() {
        usernameOrEmailError = ""; passwordError = ""
    }
        
    private func saveRememberMe() {
        UserDefaults.standard.set(rememberMe, forKey: "rememberMe")
        if rememberMe {
            UserDefaults.standard.set(usernameOrEmail, forKey: "savedUsername")
        } else {
            UserDefaults.standard.removeObject(forKey: "savedUsername")
        }
    }
    
    private func loadRememberMe() {
        rememberMe = UserDefaults.standard.bool(forKey: "rememberMe")
        if rememberMe {
            usernameOrEmail = UserDefaults.standard.string(forKey: "savedUsername") ?? ""
        }
    }
}

// MARK: - Modern Login Components (Consistent Style)

struct LoginCustomTextField: View {
    var icon: String // Added Icon
    var placeholder: String
    @Binding var text: String
    @Binding var errorMessage: String
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
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
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

struct LoginCustomSecureField: View {
    var icon: String // Added Icon
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

struct LoginScreen_Previews: PreviewProvider {
    static var previews: some View {
        LoginScreen()
            .environmentObject(AuthenticationManager())
            .environment(\.layoutDirection, .rightToLeft)
    }
}
