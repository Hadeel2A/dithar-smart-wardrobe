import SwiftUI

// MARK: - اللون الأخضر الزيتوني
extension Color {
    static let oliveGreen = Color(red: 128/255, green: 128/255, blue: 0/255)
}

// MARK: - الحاوية الرئيسية
struct OnboardingContainerView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = true
    @State private var goToCreateAccount = false

    var body: some View {
        ZStack {
            if !hasSeenOnboarding && showOnboarding {
                OnboardingView(
                    showOnboarding: $showOnboarding,
                    onComplete: {
                        // ✅ المستخدم خلّص/تخطى: نحفظ أنه شاف الـ onboarding
                        hasSeenOnboarding = true
                    },
                    onStartCreateAccount: {
                        // ✅ المستخدم ضغط "ابدأ": نحفظ + نوديه لإنشاء حساب
                        hasSeenOnboarding = true
                        goToCreateAccount = true
                    }
                )
                .transition(.opacity)
            } else {
                // ✅ بعد الـ onboarding:
                if goToCreateAccount {
                    CreateAccountScreen()
                } else {
                    WelcomeScreen()
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showOnboarding)
        .animation(.easeInOut(duration: 0.3), value: hasSeenOnboarding)
        .animation(.easeInOut(duration: 0.3), value: goToCreateAccount)
    }
}

// MARK: - صفحة الترحيب الرئيسية
struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var progress: CGFloat = 0
    @Binding var showOnboarding: Bool

    var onComplete: () -> Void
    var onStartCreateAccount: () -> Void

    let imageNames = ["onboarding1", "onboarding2", "onboarding3", "onboarding4", "onboarding5", "onboarding6"]

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)

                    Spacer()

                    Button(action: {
                        skipOnboarding()
                    }) {
                        Text("تخطي")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(Color.black.opacity(0.5))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                TabView(selection: $currentPage) {
                    ForEach(0..<imageNames.count, id: \.self) { index in
                        Image(imageNames[index])
                            .resizable()
                            .scaledToFit()
                            .padding(.horizontal, 20)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .onChange(of: currentPage) { _ in
                    updateProgress()
                }

                Spacer()

                CircularProgressButton(
                    progress: progress,
                    isLastPage: currentPage == imageNames.count - 1,
                    action: {
                        if currentPage == imageNames.count - 1 {
                            // ✅ "ابدأ" -> يوديه لصفحة إنشاء الحساب
                            startCreateAccount()
                        } else {
                            nextPage()
                        }
                    }
                )
                .padding(.bottom, 60)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            updateProgress()
        }
    }

    private func nextPage() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if currentPage < imageNames.count - 1 {
                currentPage += 1
            }
        }
    }

    private func skipOnboarding() {
        completeOnboardingToWelcome()
    }

    private func startCreateAccount() {
        showOnboarding = false
        onStartCreateAccount()
    }

    private func completeOnboardingToWelcome() {
        showOnboarding = false
        onComplete()
    }

    private func updateProgress() {
        withAnimation(.easeInOut(duration: 0.5)) {
            progress = CGFloat(currentPage + 1) / CGFloat(imageNames.count)
        }
    }
}

// MARK: - زر التقدم الدائري
struct CircularProgressButton: View {
    let progress: CGFloat
    let isLastPage: Bool
    let action: () -> Void

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                .frame(width: 70, height: 70)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.oliveGreen,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 70, height: 70)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)

            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(isLastPage ? Color.oliveGreen : Color.white)
                        .frame(width: 56, height: 56)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)

                    if isLastPage {
                        Text("ابدأ")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.oliveGreen)
                    }
                }
            }
        }
    }
}

// MARK: - معاينة
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(showOnboarding: .constant(true), onComplete: {}, onStartCreateAccount: {})
    }
}
