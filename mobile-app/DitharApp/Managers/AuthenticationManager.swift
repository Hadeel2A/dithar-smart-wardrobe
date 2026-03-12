import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore
@MainActor
class AuthenticationManager: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    init() {
        auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
            }
        }
    }
    
// sign in with username or email
    func signInWithUsernameOrEmail(usernameOrEmail: String, password: String) async {
        isLoading = true
        errorMessage = ""
        defer { isLoading = false }

        do {
            try? Auth.auth().signOut()

            let input = usernameOrEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let p = password.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !input.isEmpty else { errorMessage = "يرجى إدخال البريد أو اسم المستخدم"; return }
            guard !p.isEmpty else { errorMessage = "يرجى إدخال كلمة المرور"; return }

            let email: String
            if isValidEmail(input) {
                // if input is email
                email = input
            } else {
                // if input is username, look for the associated email
                email = try await getEmailFromUsername(input)
            }
            
            guard !email.isEmpty else { errorMessage = "لا يوجد بريد مرتبط بهذا الحساب"; return }
            
            // sign in using email and password
            let result = try await Auth.auth().signIn(withEmail: email, password: p)

            await updateUserLastLogin(for: result.user)
            errorMessage = ""
        } catch {
            handleAuthError(error)
        }
    }

    // find email using provided username
    private func getEmailFromUsername(_ username: String) async throws -> String {
        let clean = username
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let qs = try await db.collection("users")
            .whereField("username", isEqualTo: clean)
            .limit(to: 1)
            .getDocuments()

        guard let doc = qs.documents.first else {
            throw NSError(domain: "AuthError", code: 1001,
                          userInfo: [NSLocalizedDescriptionKey: "الحساب غير مسجل لدينا"])
        }

        let emailFS = (doc.data()["email"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !emailFS.isEmpty else {
            throw NSError(domain: "AuthError", code: 1002,
                          userInfo: [NSLocalizedDescriptionKey: "لا يوجد بريد مرتبط بهذا الاسم"])
        }
        return emailFS
    }

    // check if username exist
    func checkUsernameAvailability(_ username: String) async -> Bool {
        do {
            let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            
            // check if username is valid
            guard isValidUsername(cleanUsername) else {
                return false
            }
            
            let querySnapshot = try await db.collection("users")
                .whereField("username", isEqualTo: cleanUsername)
                .limit(to: 1)
                .getDocuments()
            
            return querySnapshot.documents.isEmpty
        } catch {
            print("خطأ في التحقق من توفر اسم المستخدم: \(error.localizedDescription)")
            return false
        }
    }
    
    // create new account
    func signUp(email: String, password: String, fullName: String, username: String, hasVisualImpairment: Bool) async {
        isLoading = true
        errorMessage = ""
        do {
            let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            // check if there is empty fields, then show error message
            guard !cleanEmail.isEmpty else { errorMessage = "يرجى إدخال البريد الإلكتروني"; isLoading = false; return }
            guard !cleanPassword.isEmpty else { errorMessage = "يرجى إدخال كلمة المرور"; isLoading = false; return }
            guard !cleanName.isEmpty else { errorMessage = "يرجى إدخال الاسم الكامل"; isLoading = false; return }
            guard !cleanUsername.isEmpty else { errorMessage = "يرجى إدخال اسم المستخدم"; isLoading = false; return }
            
            // check if email is valid
            guard isValidEmail(cleanEmail) else { errorMessage = "البريد الإلكتروني غير صحيح"; isLoading = false; return }
            
            // check if password is valid: must have 8 characters, upper case and lower case letters, number, special character
            guard cleanPassword.count >= 8 else { errorMessage = "كلمة المرور يجب أن تكون 8 أحرف على الأقل"; isLoading = false; return }
            guard isValidPassword(cleanPassword) else {
                errorMessage = "كلمة المرور يجب أن تحتوي على حرف كبير وصغير ورقم ورمز خاص"
                isLoading = false
                return
            }
            
            // name must have 20 character at most
            guard cleanName.count <= 20 else { errorMessage = "الاسم يجب ألا يزيد عن 20 حرف"; isLoading = false; return }
            
            // user must range from 3 to 15 characters
            guard cleanUsername.count >= 3 else { errorMessage = "اسم المستخدم يجب أن يكون 3 أحرف على الأقل"; isLoading = false; return }
            guard cleanUsername.count <= 15 else { errorMessage = "اسم المستخدم يجب ألا يزيد عن 15 حرف"; isLoading = false; return }
            guard isValidUsername(cleanUsername) else { errorMessage = "اسم المستخدم يجب أن يحتوي على أحرف وأرقام فقط"; isLoading = false; return }

            // username must be unique
            let isUsernameAvailable = await checkUsernameAvailability(cleanUsername)
            guard isUsernameAvailable else { errorMessage = "اسم المستخدم مستخدم بالفعل"; isLoading = false; return }

            let result = try await auth.createUser(withEmail: cleanEmail, password: cleanPassword)

            // save data
            let userData: [String: Any] = [
                "uid": result.user.uid,
                "email": cleanEmail,
                "fullName": cleanName,
                "username": cleanUsername,
                "hasVisualImpairment": hasVisualImpairment,
                "createdAt": Timestamp(),
                "lastLoginAt": Timestamp(),
                "isActive": true
            ]
            try await db.collection("users").document(result.user.uid).setData(userData)

            errorMessage = "تم إنشاء الحساب بنجاح!"
        } catch {
            handleAuthError(error)
        }
        isLoading = false
    }

    
    // sign out
    func signOut() {
        do {
            try auth.signOut()
            user = nil
            errorMessage = ""
        } catch {
            errorMessage = "حدث خطأ أثناء تسجيل الخروج"
        }
    }
    
    // reset password via email
    func resetPassword(withEmail email: String) async {
        await MainActor.run { isLoading = true; errorMessage = "" }
        do {
            let clean = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !clean.isEmpty else {
                errorMessage = "يرجى إدخال البريد الإلكتروني"
                isLoading = false
                return
            }

            let s = ActionCodeSettings()
            s.url = URL(string: "https://dithar-950c1.web.app/reset")!
            s.handleCodeInApp = false
            try await Auth.auth().sendPasswordReset(withEmail: clean, actionCodeSettings: s)

            errorMessage = "تم إرسال رابط إعادة التعيين إلى بريدك الإلكتروني"
        } catch {
            handleAuthError(error)
        }
        isLoading = false
    }

    
    // update last logIn
    private func updateUserLastLogin(for user: User) async {
        do {
            let userDoc = db.collection("users").document(user.uid)
            try await userDoc.updateData([
                "lastLoginAt": Timestamp()
            ])
        } catch {
            print("خطأ في تحديث آخر تسجيل دخول: \(error.localizedDescription)")
        }
    }
    
    // check if email os valid
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
    
    // check if password is valid: must have 8 characters, upper case and lower case letters, number, special character
    private func isValidPassword(_ password: String) -> Bool {
        let hasUpperCase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLowerCase = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasNumber = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSpecialChar = password.range(of: "[!@#$%^&*(),.?\":{}|<>]", options: .regularExpression) != nil
        
        return hasUpperCase && hasLowerCase && hasNumber && hasSpecialChar
    }
    
    // check username if valid
    private func isValidUsername(_ username: String) -> Bool {
        
        let usernameRegex = "^[a-zA-Z0-9_]+$"
        return NSPredicate(format: "SELF MATCHES %@", usernameRegex).evaluate(with: username)
    }
    
    // error messages for each case
    private func handleAuthError(_ error: Error) {
        let ns = error as NSError
        if let authErr = AuthErrorCode(rawValue: ns.code) {
            switch authErr.code {
            case .wrongPassword:
                errorMessage = "كلمة المرور غير صحيحة، حاول مجددًا"
            case .userNotFound:
                errorMessage = "الحساب غير مسجل لدينا"
            case .invalidEmail:
                errorMessage = "البريد الإلكتروني غير صالح"
            case .emailAlreadyInUse:
                errorMessage = "البريد الإلكتروني مستخدم بالفعل"
            case .invalidCredential:
                errorMessage = "بيانات الدخول غير صحيحة."
            case .tooManyRequests:
                errorMessage = "محاولات كثيرة جدًا. انتظر قليلًا ثم أعد المحاولة"
            case .networkError:
                errorMessage = "مشكلة اتصال. تحقّق من الشبكة"
            case .userDisabled:
                errorMessage = "تم تعطيل هذا الحساب"
            case .unauthorizedDomain:
                errorMessage = "النطاق غير مصرّح به في Firebase (Authorized domains)"
            case .invalidContinueURI:
                errorMessage = "رابط المتابعة غير صالح"
            case .missingContinueURI:
                errorMessage = "لم يتم تحديد رابط المتابعة"
            default:
                errorMessage = "رمز الخطأ: \(ns.code) — \(ns.localizedDescription)"
            }
        } else {
            
            errorMessage = ns.localizedDescription
        }
    }


    // fetch user data from firebase
    func getUserData() async -> [String: Any]? {
        guard let user = user else { return nil }
        
        do {
            let document = try await db.collection("users").document(user.uid).getDocument()
            return document.data()
        } catch {
            print("خطأ في جلب بيانات المستخدم: \(error.localizedDescription)")
            return nil
        }
    }
    
    // get cuurent user's username
    func getCurrentUsername() async -> String? {
        guard let userData = await getUserData() else { return nil }
        return userData["username"] as? String
    }
    
    // update user data
    func updateUserProfile(fullName: String? = nil, hasVisualImpairment: Bool? = nil) async -> Bool {
        guard let user = user else { return false }
        
        do {
            var updateData: [String: Any] = [:]
            
            if let fullName = fullName {
                updateData["fullName"] = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            if let hasVisualImpairment = hasVisualImpairment {
                updateData["hasVisualImpairment"] = hasVisualImpairment
            }
            
            updateData["updatedAt"] = Timestamp()
            
            try await db.collection("users").document(user.uid).updateData(updateData)
            return true
        } catch {
            print("خطأ في تحديث بيانات المستخدم: \(error.localizedDescription)")
            return false
        }
    }
}



