import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Namespace private var animation
    
    // الألوان
    private let mainGreenColor = Color(red: 0.47, green: 0.58, blue: 0.44)
    private let lightGreenBackground = Color(red: 0.91, green: 0.93, blue: 0.88)
    
    var body: some View {
        GeometryReader { geometry in
            let tabWidth = geometry.size.width / 3
            
            ZStack(alignment: .leading) {
                // الخلفية الخضراء
                RoundedRectangle(cornerRadius: 35)
                    .fill(mainGreenColor)
                    .frame(height: 70)
                
                // الدائرة البيضاء المتحركة
                Circle()
                    .fill(Color.white)
                    .frame(width: 60, height: 60)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .offset(x: calculateCircleOffset(tabWidth: tabWidth, selectedTab: selectedTab))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0), value: selectedTab)
                
                // الأيقونات
                HStack(spacing: 0) {
                    // زر المجتمع (يمين)
                    Button(action: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            selectedTab = 0
                            DitharVoiceAssistant.shared.speak("المجتمع")
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(selectedTab == 0 ? mainGreenColor : .white.opacity(0.7))
                        }
                        .frame(width: tabWidth, height: 70)
                    }
                    .accessibilityLabel("المجتمع")
                    .accessibilityAddTraits(.isButton)
                    
                    // زر خزانة الملابس (وسط)
                    Button(action: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            selectedTab = 1
                            DitharVoiceAssistant.shared.speak("خزانة الملابس")
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "cabinet.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(selectedTab == 1 ? mainGreenColor : .white.opacity(0.7))
                        }
                        .frame(width: tabWidth, height: 70)
                    }
                    .accessibilityLabel("خزانة الملابس")
                    .accessibilityAddTraits(.isButton)
                    
                    // زر الإطلالات (يسار) ✅ (تم التعديل هنا فقط)
                    Button(action: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            selectedTab = 2
                            DitharVoiceAssistant.shared.speak("الإطلالات")
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(selectedTab == 2 ? "Mannequin2" : "Mannequin1")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 36)
                                .scaleEffect(x: 1.3, y: 1.0) // تحكم بالعرض
                        }
                        .frame(width: tabWidth, height: 70)
                    }
                    .accessibilityLabel("الإطلالات")
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
        .frame(height: 70)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    // حساب موضع الدائرة البيضاء بناءً على التاب المختار
    private func calculateCircleOffset(tabWidth: CGFloat, selectedTab: Int) -> CGFloat {
        let baseOffset = tabWidth / 2 - 30 // 30 هو نصف قطر الدائرة
        
        switch selectedTab {
        case 0: // المجتمع (يمين)
            return baseOffset
        case 1: // الخزانة (وسط)
            return baseOffset + tabWidth
        case 2: // الإطلالات (يسار)
            return baseOffset + (tabWidth * 2)
        default:
            return baseOffset + tabWidth
        }
    }
}

struct CustomTabBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            CustomTabBar(selectedTab: .constant(1))
        }
        .background(Color.gray.opacity(0.1))
        .environment(\.layoutDirection, .rightToLeft)
    }
}
