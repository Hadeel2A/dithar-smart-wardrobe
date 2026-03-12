import SwiftUI
import Firebase

@main
struct DitharApp: App {
    @StateObject private var authManager = AuthenticationManager()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environment(\.layoutDirection, .rightToLeft)
        }
    }
}

// MARK: - Root Content View
struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        Group {
            if authManager.user != nil {
                NavigationBAR()
            } else {
                UnauthenticatedRootView(hasSeenOnboarding: hasSeenOnboarding)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.user != nil)
    }
}

// MARK: - Unauthenticated Root (Splash → Onboarding OR Welcome)
struct UnauthenticatedRootView: View {
    let hasSeenOnboarding: Bool
    @State private var showSplash = true
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            if showSplash {
                AppSplashView()
                    .transition(.opacity)
            } else {
                if hasSeenOnboarding {
                    AuthEntryView()
                } else {
                    OnboardingEntryView()
                }
            }
        }
        .onAppear { playSplash() }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                // ✅ كل ما رجع المستخدم للتطبيق
                playSplash()
            }
        }
    }

    private func playSplash() {
        showSplash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeInOut(duration: 0.25)) {
                showSplash = false
            }
        }
    }
}


// MARK: - Splash Screen
struct AppSplashView: View {
    @State private var animate = false
    @State private var shimmer = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 14) {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .scaleEffect(animate ? 1.0 : 0.92)
                    .opacity(animate ? 1 : 0)
                    .overlay(shimmerOverlay.mask(
                        Image("logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 150)
                    ))

                Text("دِثار")
                    .font(.custom("RH-Zak", size: 46))
                    .foregroundColor(Color(red: 0.44, green: 0.6, blue: 0.44))
                    .opacity(animate ? 1 : 0)
                    .offset(y: animate ? 0 : 6)
                    .overlay(shimmerOverlay.mask(
                        Text("دِثار")
                            .font(.custom("RH-Zak", size: 46))
                    ))

                Text("أناقة تُدار بذكاء")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.black.opacity(0.45))
                    .opacity(animate ? 1 : 0)
                    .offset(y: animate ? 0 : 10)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                animate = true
            }
            // لمعان بسيط
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                shimmer = true
            }
        }
    }

    private var shimmerOverlay: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                .clear,
                Color.white.opacity(0.55),
                .clear
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .rotationEffect(.degrees(20))
        .offset(x: shimmer ? 220 : -220)
    }
}


// MARK: - Auth Entry (Welcome)
struct AuthEntryView: View {
    var body: some View {
        NavigationStack {
            WelcomeScreen()
                .navigationBarHidden(true)
        }
    }
}

// MARK: - Welcome Screen (اختيار)
struct WelcomeScreen: View {
    var body: some View {
        ZStack {
            Color(red: 0.44, green: 0.6, blue: 0.44)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 30) {
                    Image("DitharLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)

                    VStack(spacing: 15) {
                        Text("دِثار")
                            .font(.custom("RH-Zak", size: 48))
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("أناقة تُدار بذكاء !")
                            .font(.custom("RH-Zak", size: 24))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }

                Spacer()

                VStack(spacing: 20) {
                    NavigationLink {
                        CreateAccountScreen()
                    } label: {
                        Text("إنشاء حساب جديد")
                            .font(.headline)
                            .foregroundColor(Color(red: 0.44, green: 0.6, blue: 0.44))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(14)
                    }

                    NavigationLink {
                        LoginScreen()
                    } label: {
                        Text("تسجيل الدخول")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white, lineWidth: 2)
                            )
                    }
                }
                .padding(.horizontal, 40)

                Spacer()
            }
        }
    }
}

// MARK: - Onboarding Entry
struct OnboardingEntryView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = true
    @State private var goToCreateAccount = false

    var body: some View {
        NavigationStack {
            ZStack {
                // ✅ نستخدم نفس توقيع OnboardingView اللي عندك
                OnboardingView(
                    showOnboarding: $showOnboarding,
                    onComplete: {
                        hasSeenOnboarding = true
                        // بعد التخطي/الاكمال نطلع لصفحة الاختيار (Welcome) لأن showOnboarding يصير false داخل OnboardingView
                    },
                    onStartCreateAccount: {
                        hasSeenOnboarding = true
                        goToCreateAccount = true
                    }
                )

                // ✅ يودّي لإنشاء الحساب لما المستخدم يضغط "ابدأ"
                NavigationLink("", isActive: $goToCreateAccount) {
                    CreateAccountScreen()
                }
                .hidden()
            }
        }
    }
}

// MARK: - Logged-in Navigation Bar
struct NavigationBAR: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var selectedTab = 1

    var body: some View {
        ZStack {
            Group {
                switch selectedTab {
                case 0:
                    CommunityView()
                case 1:
                    WardrobeView()
                case 2:
                    OutfitsView()
                default:
                    WardrobeView()
                }
            }

            VStack {
                Spacer()
                CustomTabBar(selectedTab: $selectedTab)
            }
        }
        .ignoresSafeArea(.keyboard)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthenticationManager())
            .previewDevice(PreviewDevice(rawValue: "iPhone 16 Pro"))
    }
}
