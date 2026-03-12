import SwiftUI

struct ForgotPasswordScreen: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var email = ""
    @State private var emailError = "" // للإشارة للخطأ في الحقل

    // MARK: - Colors
    let primaryGreen = Color(red: 0.44, green: 0.6, blue: 0.44)
    let darkText = Color(red: 0.1, green: 0.1, blue: 0.1)

    var body: some View {
        ZStack {
            // 1. الخلفية الخارجية
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
                    .buttonAccessibility(label: "رجوع", hint: "العودة إلى شاشة تسجيل الدخول")
                    
                    Spacer()
                }
                .padding(.top, 50)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                
                // 2. العنوان والعبارة التوضيحية
                VStack(spacing: 10) {
                    Text("إعادة تعيين كلمة المرور")
                        .font(Font.custom("RH-Zak", size: 28))
                        .foregroundColor(.white)
                        .accessibilityAddTraits(.isHeader)
              
                }
                .padding(.bottom, 30)
                
                // 3. الكارد الأبيض
                ZStack {
                    Color.white
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
                        .ignoresSafeArea(.all, edges: .bottom)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 25) {
                            
                            // الحقول
                            VStack(spacing: 20) {
                                ModernTextFieldLight(
                                    icon: "envelope",
                                    placeholder: "البريد الإلكتروني",
                                    text: $email,
                                    errorMessage: $emailError,
                                    keyboardType: .emailAddress
                                )
                                .accessibilityLabel("البريد الإلكتروني")
                            }
                            .padding(.top, 40)
                            
                            // رسائل الحالة
                            if !authManager.errorMessage.isEmpty {
                                Text(authManager.errorMessage)
                                    .font(.footnote)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(authManager.errorMessage.contains("تم إرسال") ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                                    .foregroundColor(authManager.errorMessage.contains("تم إرسال") ? .green : .red)
                                    .cornerRadius(8)
                            }
                            
                            // زر الإرسال
                            Button(action: {
                                sendResetLink()
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
                                        
                                        Text(authManager.isLoading ? "جاري الإرسال..." : "إرسال رابط التعيين")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(height: 55)
                            }
                            .disabled(authManager.isLoading)
                            
                            // زر الإلغاء (نصي أسفل الزر الرئيسي)
                            Button(action: {
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Text("إلغاء")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                            }
                            .padding(.bottom, 20)
                        }
                        .padding(.horizontal, 25)
                    }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft) // الاتجاه عربي
        .onAppear {
            DitharVoiceAssistant.shared.announceScreenChange(
                "شاشة إعادة تعيين كلمة المرور. أدخل بريدك الإلكتروني ثم اضغط على إرسال."
            )
        }
        .onChange(of: authManager.errorMessage) { newValue in
            guard !newValue.isEmpty else { return }
            DitharVoiceAssistant.shared.speak(newValue, interrupt: true)
        }
        // عند الكتابة نمسح رسالة الخطأ
        .onChange(of: email) { _ in
            if !emailError.isEmpty { emailError = "" }
        }
    }
    
    // MARK: - Logic
    private func sendResetLink() {
        // تحقق بسيط
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedEmail.isEmpty {
            emailError = "يرجى إدخال البريد الإلكتروني"
            return
        }
        emailError = ""
        
        Task {
            await authManager.resetPassword(withEmail: trimmedEmail)
        }
    }
}

// تأكد من وجود ModernTextFieldLight في نفس الملف أو المشروع
// (نفس المكون المستخدم في شاشات التسجيل والدخول السابقة)
struct ForgotPasswordScreen_Previews: PreviewProvider {
    static var previews: some View {
        ForgotPasswordScreen()
            .environmentObject(AuthenticationManager())
            .environment(\.layoutDirection, .rightToLeft)
    }
}
