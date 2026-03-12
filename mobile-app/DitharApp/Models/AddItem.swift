import SwiftUI
import PhotosUI
import SwiftUI
import PhotosUI
import FirebaseCore
import FirebaseFirestore
import FirebaseStorage
import Vision
import CoreML
import AVKit
import UIKit
import AVFoundation // ✅ الإضافة الجديدة للنطق الصوتي


// =============================================================================
// MARK: - Background Removal Service (Rembg)
// =============================================================================




enum RembgError: Error, LocalizedError {
    case emptyData, badResponse(Int), serverMessage(String)
    var errorDescription: String? {
        switch self {
        case .emptyData: return "لم تُرسل/تُستقبل بيانات."
        case .badResponse(let code): return "استجابة غير متوقعة من السيرفر (\(code))."
        case .serverMessage(let msg): return "خطأ من السيرفر: \(msg)"
        }
    }
}

final class RembgService {

    // رابط Space
    private let endpoint = URL(string: "https://rahaf1-rembg-server.hf.space/api/remove")!

    // ✳️ إذا Space = Private ضعي التوكِن هنا. لو Public اتركيه فارغ.
    private let hfToken: String? = "" // مثال: "hf_XXXXXXXXXXXXXXXXXXXXXXXX"

    // يرسل الصورة ويستقبل PNG شفافة
    func removeBackground(image: UIImage) async throws -> Data {
        guard let imgData = image.jpegData(compressionQuality: 0.98) else {
            throw RembgError.emptyData
        }

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 60

        // هيدر الـ Authorization عند كون الـSpace Private
        if let token = hfToken, !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func append(_ s: String) { body.append(s.data(using: .utf8)!) }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"in.jpg\"\r\n")
        append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imgData)
        append("\r\n--\(boundary)--\r\n")
        req.httpBody = body

        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1

        guard code == 200 else {
            // اطبعي رسالة السيرفر لو فيه نص
            if let msg = String(data: data, encoding: .utf8), !msg.isEmpty {
                print("rembg server said:", msg)
                throw RembgError.serverMessage(msg)
            } else {
                throw RembgError.badResponse(code)
            }
        }
        guard !data.isEmpty else { throw RembgError.emptyData }
        return data
    }
}

// =============================================================================
// MARK: - Custom Speech Service (AVSpeechSynthesizer)
// =============================================================================




// ===== Models =====
struct CLIPResponse: Codable {
    let category: String
    let color: String
    let color_hex: String?
    let pattern: String
    let scores: Scores?
    let device: String?
    let model: String?

    struct Scores: Codable {
        let category: Double?
        let pattern: Double?
    }
}

// MARK: - ملاحظة: نموذج بيانات القطعة الجديدة
struct AddItem {
    var image: UIImage?
    var processedImage: UIImage? // الصورة بعد قص الخلفية
    var category: String = ""     // مملوءة من التحليل
    var color: String = ""        // مملوءة من التحليل
    var pattern: String = ""      // مملوءة من التحليل
    var season: String = ""       // فارغة - يعبيها المستخدم
    var brand: String = ""        // فارغة - يعبيها المستخدم
    var size: String = ""         // فارغة - يعبيها المستخدم
    var description: String = ""  // فارغة - يعبيها المستخدم
    var rfidLinked: Bool = false
    var rfidId: String = ""
    var occasion: String = ""   // المناسبة: رسمي/سهرة/يومي/منزل
    
    
    // انا اضفتهم جدد
    var imageUrl: String = ""   // رابط الصورة على Storage
        var docId: String = ""      // معرف وثيقة Firestore
}

// MARK: - نموذج بيانات القطعة القديمة المرتبطة بـ RFID
struct ExistingClothingItem {
    var docId: String
    var imageUrl: String
    var category: String
    var epc: String
}


// MARK: - ملاحظة: المراحل الأربع
enum AddItemStep: Int, CaseIterable {
    case uploadImage = 0
    case aiAnalysis = 1
    case rfidLink = 2
    case confirmation = 3
    
    var title: String {
        switch self {
        case .uploadImage: return "رفع الصورة"
        case .aiAnalysis: return "تحليل ذكي"
        case .rfidLink: return "ربط المعرف"
        case .confirmation: return "التأكيد"
        }
    }
    
    var icon: String {
        switch self {
        case .uploadImage: return "camera"
        case .aiAnalysis: return "photo.on.rectangle.angled"
        case .rfidLink: return "barcode.viewfinder"
        case .confirmation: return "checkmark"
        }
    }
    
    var voiceOverAnnouncement: String {
        switch self {
        case .uploadImage:
            return " رفع الصورة"
        case .aiAnalysis:
            return " التحليل الذكي "
        case .rfidLink:
            return " ربط المعرف"
        case .confirmation:
            return " التأكيد"
        }
    }

}



// MARK: - ملاحظة: الشاشة الرئيسية لرحلة إضافة القطعة
struct AddItemFlowView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthenticationManager
    
    // Callback لإضافة القطعة للخزانة
    var onItemAdded: ((ClothingItem) -> Void)? = nil
    
    @State private var currentStep: AddItemStep = .uploadImage
    @State private var itemData = AddItem()
    @State private var navigateToDetails = false
    
    // MARK: - وصف الخطوة الحالية للفويس أوفر + المساعد الصوتي
    private var stepAccessibilityLabel: String {
        let totalSteps = AddItemStep.allCases.count
        let stepIndex = currentStep.rawValue + 1
        
        let stepName: String
        switch currentStep {
        case .uploadImage:
            stepName = "رفع صورة القطعة"
        case .aiAnalysis:
            stepName = "مراجعة تفاصيل القطعة بعد التحليل الذكي"
        case .rfidLink:
            stepName = "ربط القطعة بتاق التعرّف"
        case .confirmation:
            stepName = "تأكيد إضافة القطعة إلى الخزانة"
        }
        
        return "خطوة \(stepIndex) من \(totalSteps): \(stepName)"
    }
    

    
    var body: some View {
        NavigationView {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // MARK: - شريط التقدم
                    ProgressStepBar(currentStep: currentStep)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 16)

                    Divider()
                        .background(Color(red: 0.91, green: 0.90, blue: 0.89))
                        .accessibilityHidden(true)
                    
                    // MARK: - محتوى الشاشة حسب المرحلة الحالية
                    Group {
                        switch currentStep {
                        case .uploadImage:
                            UploadImageView(
                                itemData: $itemData,
                                currentStep: $currentStep
                            )
                            
                        case .aiAnalysis:
                            AIAnalysisView(
                                itemData: $itemData,
                                currentStep: $currentStep
                            )
                            
                        case .rfidLink:
                            RFIDLinkView(
                                itemData: $itemData,
                                currentStep: $currentStep
                            )
                            
                        case .confirmation:
                            ConfirmationSuccessView(
                                itemData: $itemData,
                                navigateToDetails: $navigateToDetails,
                                presentationMode: presentationMode,
                                onItemAdded: onItemAdded
                            )
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading:
                    Button(action: {
                        if currentStep.rawValue > 0 {
                            // ارجع للخطوة السابقة
                            if let previous = AddItemStep(rawValue: currentStep.rawValue - 1) {
                                currentStep = previous
                            } else {
                                currentStep = .uploadImage
                            }
                            // ما نحتاج ننطق هنا، onChange(currentStep) بيتكفّل
                        } else {
                            // إذا كنا في أول خطوة -> نغلق رحلة الإضافة
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) {
                        Image(systemName: "arrow.right")
                            .foregroundColor(.black)
                            .font(.system(size: 20))
                            .accessibilityHidden(true)
                    }
                    .accessibilityLabel(
                        currentStep.rawValue > 0
                        ? "رجوع "
                        : "إغلاق إضافة القطعة"
                    )
                    .accessibilityHint(
                        currentStep.rawValue > 0
                        ? stepAccessibilityLabel   // يقول وصف الخطوة الجديدة
                        : "العودة إلى الخزانة"
                    )
                    .accessibilityAddTraits(.isButton)
            )
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("إضافة قطعة جديدة")
                        .font(.system(size: 18, weight: .semibold))
                        .accessibilityLabel("شاشة إضافة قطعة جديدة")
                        .accessibilityAddTraits(.isHeader)
                }
            }
            .sheet(isPresented: $navigateToDetails) {
                ItemDetailsView(
                    itemData: $itemData,
                    onRequestRFIDLink: {
                        navigateToDetails = false
                        currentStep = .rfidLink
                    },
                    onDone: {
                        navigateToDetails = false
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
   
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}



// MARK: - ملاحظة: شريط التقدم (4 مراحل)
struct ProgressStepBar: View  {
    let currentStep: AddItemStep
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(AddItemStep.allCases.enumerated()), id: \.element) { index, step in
                VStack(spacing: 8) {
                    // الأيقونة
                    ZStack {
                        Circle()
                            .fill(stepColor(for: step))
                            .frame(width: 44, height: 44)
                            .accessibilityHidden(true) // لا تتكرر للـ VoiceOver
                        
                        if step.rawValue < currentStep.rawValue {
                            Image(systemName: "checkmark")
                                .foregroundColor(.white)
                                .font(.system(size: 18, weight: .bold))
                                .accessibilityHidden(true)
                        } else {
                            Image(systemName: step.icon)
                                .foregroundColor(step == currentStep ? .white : Color.gray.opacity(0.5))
                                .font(.system(size: 18))
                                .accessibilityHidden(true)
                        }
                    }
                    
                    // العنوان تحت الأيقونة
                    Text(step.title)
                        .font(.system(size: 11))
                        .foregroundColor(step == currentStep ? Color(red: 0.47, green: 0.58, blue: 0.44) : Color.gray.opacity(0.6))
                        .accessibilityHidden(true)
                }
                // ✅ هنا نخلي كل خطوة عنصر وصول مستقل
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(step.title) // اللي بينطق أول شيء: "رفع الصورة" أو "تحليل ذكي"
                .accessibilityValue(
                    step.rawValue < currentStep.rawValue
                    ? "مكتملة"
                    : (step == currentStep ? "الخطوة الحالية" : "لم تبدأ بعد")
                )
                .accessibilityHint("جزء من خطوات إضافة القطعة")
                
                if step != AddItemStep.allCases.last {
                    Rectangle()
                        .fill(step.rawValue < currentStep.rawValue ? Color(red: 0.47, green: 0.58, blue: 0.44) : Color.gray.opacity(0.3))
                        .frame(height: 2)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 30)
                        .accessibilityHidden(true)
                }
            }
        }
        // ❌ نحذف هذه:
        // .accessibilityElement(children: .contain)
    }
    
    func stepColor(for step: AddItemStep) -> Color {
        if step.rawValue < currentStep.rawValue {
            return Color(red: 0.47, green: 0.58, blue: 0.44) // منجز
        } else if step == currentStep {
            return Color(red: 0.47, green: 0.58, blue: 0.44) // نشط
        } else {
            return Color.gray.opacity(0.3) // لاحق
        }
    }
}



// MARK: - ملاحظة: الشاشة 1 - رفع الصورة (نفس التصميم بالضبط)
struct UploadImageView: View{
    @Binding var itemData: AddItem
    @Binding var currentStep: AddItemStep
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // بطاقة إضافة صورة
            Button(action: {
                // ✅ هنا نشرح الشروط صوتياً
                DitharVoiceAssistant.shared.speak(
                    "ارفع صورة واضحة لملابسك في إضاءة جيدة، ثم اختر التالي بعد الانتهاء."
                )
                showImagePicker = true
            }) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 326, height: 350)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color(red: 0.91, green: 0.90, blue: 0.89), lineWidth: 1)
                        )
                        .accessibilityLabel("الصورة المختارة، اضغط لتغيير الصورة")
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "plus")
                            .font(.system(size: 50, weight: .medium))
                            .foregroundColor(Color(red: 0.47, green: 0.58, blue: 0.44))
                            .accessibilityHidden(true)
                        
                        Text("إضافة صورة")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(Color.gray.opacity(0.7))
                            .accessibilityHidden(true)
                    }
                    .frame(width: 326, height: 350)
                    .background(Color(red: 0.96, green: 0.96, blue: 0.96))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(red: 0.91, green: 0.90, blue: 0.89), lineWidth: 1)
                    )
                }
            }
            .accessibilityLabel(selectedImage != nil ? "زر تغيير الصورة" : "زر إضافة صورة")
            .accessibilityHint("يفتح معرض الصور لاختيار القطعة المراد إضافتها.")
            
            // نص إرشادي
            Text("ارفع صورة واضحة لملابسك في إضاءة جيدة")
                .font(.system(size: 13))
                .foregroundColor(Color.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.top, 20)
                .padding(.horizontal, 40)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("ارفع صورة واضحة لملابسك في إضاءة جيدة")
            
            Spacer()
            
            // زر التالي (نفس المنطق السابق)
            Button(action: {
                guard let image = selectedImage else { return }
                itemData.image = image
                currentStep = .aiAnalysis
            }) {
                Text("التالي")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(selectedImage != nil ? Color(red: 0.47, green: 0.58, blue: 0.44) : Color.gray.opacity(0.4))
                    .cornerRadius(12)
            }
            .disabled(selectedImage == nil)
            .accessibilityLabel("زر التالي")
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
    }
}






// MARK: - ملاحظة: الشاشة 2 - تحليل ذكي (3 مراحل في شاشة واحدة)


struct AIAnalysisView: View {
    @Binding var itemData: AddItem
    @Binding var currentStep: AddItemStep
    @State private var analysisPhase = 0 // 0: قص الخلفية، 1: اكتشاف، 2: عرض النتائج
    @State private var didRun = false

    // ✅ MODIFIED: إضافة RembgService
    private let rembgService = RembgService()
    let apiURL = URL(string: "https://rahaf1-dithar-api.hf.space/classify")!
    
    // ✅ الإضافة الجديدة: خدمة النطق
    private let speechService = CustomSpeechService()
    
    @Environment(\.accessibilityManager) private var accessibilityManager

    private var analysisStatusText: String {
        analysisPhase == 0 ? "جار قص الخلفية" : "جار اكتشاف محتويات القطعة"
    }
    
    private func spokenSize(from code: String) -> String {
        switch code {
        case "XS": return "X Small"
        case "S":  return "Small"
        case "M":  return "Medium"
        case "L":  return "Large"
        case "XL": return "X Large"
        default:   return "غير محدد"
        }
    }

    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if analysisPhase < 2 {
                    // MARK: - مرحلة التحليل (قص الخلفية + اكتشاف)
                    Spacer().frame(height: 40)

                    if let image = itemData.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 250, height: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .accessibilityLabel("الصورة قيد التحليل")
                    }

                    ProgressView()
                        .scaleEffect(1.5)
                        .padding(.top, 20)
                        .accessibilityLabel("جاري معالجة الصورة")

                    Text(analysisStatusText + "…")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.top, 10)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(analysisStatusText)
                        .accessibilityHint("حالة خطوة التحليل الحالية")

                    Spacer()
      
                } else {
                    // MARK: - عرض النتائج
                    VStack(spacing: 0) {
                        if let image = itemData.processedImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 0))
                                .accessibilityLabel("القطعة بعد إزالة الخلفية")
                        } else if let image = itemData.image {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 0))
                                .accessibilityLabel("صورة القطعة الأصلية (فشل إزالة الخلفية)")
                        }




                        // الحقول
                        VStack(spacing: 0) {

                            // MARK: - الفئة
                            FormFieldRow(title: "") {
                                Menu {
                                    if !itemData.category.isEmpty {
                                        Button(role: .destructive) {
                                            itemData.category = ""
                                        } label: {
                                            Label("مسح الفئة", systemImage: "xmark.circle")
                                        }
                                    }
                                    Menu("قطع علوية") {
                                        Button("قميص")   { itemData.category = "قميص" }
                                        Button("بلوزة")  { itemData.category = "بلوزة" }
                                        Button("كنزة")   { itemData.category = "كنزة" }
                                        Button("معطف")   { itemData.category = "معطف" }
                                        Button("تيشيرت") { itemData.category = "تيشيرت" }
                                    }
                                    Menu("قطع سفلية") {
                                        Button("بنطال")  { itemData.category = "بنطال" }
                                        Button("تنورة")  { itemData.category = "تنورة" }
                                        Button("شورت")   { itemData.category = "شورت" }
                                    }
                                    
                                    Menu("قطع كاملة") {
                                        Button("فستان")  { itemData.category = "فستان" }
                                        Button("شيال")   { itemData.category = "شيال" }
                                        Button("ثوب")    { itemData.category = "ثوب" }
                                        Button("عباية")  { itemData.category = "عباية" }
                                    }
                                    
                                    Menu("أحذية") {
                                        Button("حذاء رياضي") { itemData.category = "حذاء رياضي" }
                                        Button("حذاء رسمي")  { itemData.category = "حذاء رسمي" }
                                        Button("صندل")       { itemData.category = "صندل" }
                                        Button("كعب")        { itemData.category = "كعب" }
                                        Button("بوت")        { itemData.category = "بوت" }
                                    }
                                    
                                    Menu("إكسسوارات") {
                                        Button("سلسال")  { itemData.category = "سلسال" }
                                        Button("اسورة")  { itemData.category = "اسورة" }
                                        Button("حلق")    { itemData.category = "حلق" }
                                        Button("خاتم")   { itemData.category = "خاتم" }
                                        Button("ساعة")   { itemData.category = "ساعة" }
                                        Button("نظارة")  { itemData.category = "نظارة" }
                                        Button("حقيبة")  { itemData.category = "حقيبة" }
                                        Button("حزام")   { itemData.category = "حزام" }
                                        Button("قبعة")   { itemData.category = "قبعة" }
                                        Button("وشاح")   { itemData.category = "وشاح" }
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Text("الفئة").foregroundColor(.black)
                                        Text(itemData.category.isEmpty ? "اختر الفئة" : itemData.category)
                                            .foregroundColor(itemData.category.isEmpty ? .gray : .black)
                                        Spacer(minLength: 0)
                                    }
                                    .frame(height: 48)
                                    .frame(maxWidth: .infinity)
                                    .padding(.trailing, 28)
                                    .contentShape(Rectangle())
                                    .overlay(
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                            .padding(.trailing, 12),
                                        alignment: .trailing
                                    )
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("الفئة")
                                .accessibilityValue(itemData.category.isEmpty ? "غير محدد" : itemData.category)
                            }


                            // MARK: - اللون
                            FormFieldRow(title: "") {
                                Menu {
                                    if !itemData.color.isEmpty {
                                        Button(role: .destructive) {
                                            itemData.color = ""
                                        } label: {
                                            Label("مسح اللون", systemImage: "xmark.circle")
                                        }
                                    }
                                    ForEach([
                                        "أبيض","أسود","رمادي","بني","بيج",
                                        "أحمر","وردي","بنفسجي","برتقالي","أصفر",
                                        "أخضر","سماوي","أزرق","ذهبي","فضي"
                                    ], id: \.self) { c in
                                        Button(c) { itemData.color = c }
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Text("اللون").foregroundColor(.black)
                                        Text(itemData.color.isEmpty ? "اختر اللون" : itemData.color)
                                            .foregroundColor(itemData.color.isEmpty ? .gray : .black)
                                        Spacer(minLength: 0)
                                    }
                                    .frame(height: 48)
                                    .frame(maxWidth: .infinity)
                                    .padding(.trailing, 28)
                                    .contentShape(Rectangle())
                                    .overlay(
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                            .padding(.trailing, 12),
                                        alignment: .trailing
                                    )
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("اللون")
                                .accessibilityValue(itemData.color.isEmpty ? "غير محدد" : itemData.color)
                            }




                            // MARK: - النقش
                            FormFieldRow(title: "") {
                                Menu {
                                    if !itemData.pattern.isEmpty {
                                        Button(role: .destructive) {
                                            itemData.pattern = ""
                                        } label: {
                                            Label("مسح النقش", systemImage: "xmark.circle")
                                        }
                                    }
                                    ForEach([
                                        "سادة","مخطط","مورد","كاروهات","مربعات",
                                        "منقط","اشكال هندسية","دانتيل"
                                    ], id: \.self) { p in
                                        Button(p) { itemData.pattern = p }
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Text("النقش").foregroundColor(.black)
                                        Text(itemData.pattern.isEmpty ? "اختر النقش" : itemData.pattern)
                                            .foregroundColor(itemData.pattern.isEmpty ? .gray : .black)
                                        Spacer(minLength: 0)
                                    }
                                    .frame(height: 48)
                                    .frame(maxWidth: .infinity)
                                    .padding(.trailing, 28)
                                    .contentShape(Rectangle())
                                    .overlay(
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                            .padding(.trailing, 12),
                                        alignment: .trailing
                                    )
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("النقش")
                                .accessibilityValue(itemData.pattern.isEmpty ? "غير محدد" : itemData.pattern)
                            }


                            // MARK: - الموسم
                            FormFieldRow(title: "") {
                                Menu {
                                    Button("شتاء") { itemData.season = "شتاء" }
                                    Button("صيف")  { itemData.season = "صيف"  }
                                    Button("ربيع") { itemData.season = "ربيع" }
                                    Button("خريف") { itemData.season = "خريف" }
                                } label: {
                                    HStack(spacing: 8) {
                                        Text("الموسم")
                                            .foregroundColor(.black)
                                        Text(itemData.season.isEmpty ? "اختر الموسم" : itemData.season)
                                            .foregroundColor(itemData.season.isEmpty ? .gray : .black)
                                        Spacer(minLength: 0)
                                    }
                                    .frame(height: 48)
                                    .frame(maxWidth: .infinity)
                                    .padding(.trailing, 28)
                                    .contentShape(Rectangle())
                                    .overlay(
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                            .padding(.trailing, 12),
                                        alignment: .trailing
                                    )
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("الموسم")
                                .accessibilityValue(itemData.season.isEmpty ? "غير محدد" : itemData.season)
                            }



                            // MARK: - المقاس
                            FormFieldRow(title: "") {
                                Menu {
                                    Button {
                                        itemData.size = "XS"
                                    } label: {
                                        Text("XS")
                                    }
                                    .accessibilityLabel(spokenSize(from: "XS"))

                                    Button {
                                        itemData.size = "S"
                                    } label: {
                                        Text("S")
                                    }
                                    .accessibilityLabel(spokenSize(from: "S"))

                                    Button {
                                        itemData.size = "M"
                                    } label: {
                                        Text("M")
                                    }
                                    .accessibilityLabel(spokenSize(from: "M"))

                                    Button {
                                        itemData.size = "L"
                                    } label: {
                                        Text("L")
                                    }
                                    .accessibilityLabel(spokenSize(from: "L"))

                                    Button {
                                        itemData.size = "XL"
                                    } label: {
                                        Text("XL")
                                    }
                                    .accessibilityLabel(spokenSize(from: "XL"))
                                } label: {
                                    HStack(spacing: 8) {
                                        Text("المقاس")
                                            .foregroundColor(.black)
                                        Text(itemData.size.isEmpty ? "اختر المقاس" : itemData.size)
                                            .foregroundColor(itemData.size.isEmpty ? .gray : .black)
                                        Spacer(minLength: 0)
                                    }
                                    .frame(height: 48)
                                    .frame(maxWidth: .infinity)
                                    .padding(.trailing, 28)
                                    .contentShape(Rectangle())
                                    .overlay(
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                            .padding(.trailing, 12),
                                        alignment: .trailing
                                    )
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("المقاس")
                                .accessibilityValue(
                                    itemData.size.isEmpty
                                    ? "غير محدد"
                                    : spokenSize(from: itemData.size)
                                )
                            }



                            
                            // MARK: - المناسبة
                            FormFieldRow(title: "") {
                                Menu {
                                    Button("رسمي") { itemData.occasion = "رسمي" }
                                    Button("سهرة") { itemData.occasion = "سهرة" }
                                    Button("يومي")  { itemData.occasion = "يومي"  }
                                    Button("منزل") { itemData.occasion = "منزل" }
                                } label: {
                                    HStack(spacing: 8) {
                                        Text("المناسبة")
                                            .foregroundColor(.black)
                                        Text(itemData.occasion.isEmpty ? "اختر المناسبة" : itemData.occasion)
                                            .foregroundColor(itemData.occasion.isEmpty ? .gray : .black)
                                        Spacer(minLength: 0)
                                    }
                                    .frame(height: 48)
                                    .frame(maxWidth: .infinity)
                                    .padding(.trailing, 28)
                                    .contentShape(Rectangle())
                                    .overlay(
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                            .padding(.trailing, 12),
                                        alignment: .trailing
                                    )
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("المناسبة")
                                .accessibilityValue(itemData.occasion.isEmpty ? "غير محدد" : itemData.occasion)
                            }


                            // MARK: - الماركة (يدخلها المستخدم)
                            FormFieldRow(title: "") {
                                HStack(spacing: 8) {
                                    Text("الماركة")
                                        .foregroundColor(.black)
                                    // حقل نصي للماركة
                                    TextField("اكتب اسم الماركة", text: $itemData.brand)
                                        .multilineTextAlignment(.trailing)
                                        .textInputAutocapitalization(.never)
                                        .disableAutocorrection(true)
                                        .accessibilityLabel("حقل الماركة") // ✅ VoiceOver
                                    Spacer(minLength: 0)
                                }
                                .frame(height: 48)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 12)
                            }



                            // الوصف
                            VStack(alignment: .trailing, spacing: 8) {
                                HStack(spacing: 8) {
                                    Text("الوصف")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.black)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 16)

                                ZStack(alignment: .topTrailing) {
                                    TextEditor(text: $itemData.description)
                                        .frame(height: 80)
                                        .padding(12)
                                        .background(Color(red: 0.96, green: 0.96, blue: 0.96))
                                        .cornerRadius(10)
                                        .multilineTextAlignment(.trailing)
                                        .accessibilityLabel("حقل إدخال الوصف") // ✅ VoiceOver

                                    if itemData.description.isEmpty {
                                        Text("أضف تفاصيل إضافية...")
                                            .foregroundColor(.gray)
                                            .padding(.top, 20)
                                            .padding(.trailing, 20)
                                            .allowsHitTesting(false)
                                            .accessibilityHidden(true) // ✅ VoiceOver
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .padding(.vertical, 12)
                        }

                        // زر التالي
                        Button(action: {
                            currentStep = .rfidLink
                        }) {
                            Text("التالي")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color(red: 0.47, green: 0.58, blue: 0.44))
                                .cornerRadius(12)
                                .accessibilityLabel("زر التالي")
                                .accessibilityHint("الانتقال إلى مرحلة ربط المعرف")
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 30)

                        Spacer().frame(height: 150)
                    }
                    .padding(.horizontal, 16)
                    .environment(\.layoutDirection, .rightToLeft)
                    // تم حذف onChange لأن الحفظ سيتم في النهاية فقط
                }
            }
            .padding(.top, 1) // لتفادي تحذير ScrollView overlay-safe-area أحيانًا
        }

        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            guard !didRun, let originalImage = itemData.image else { return }
            didRun = true

            // ✅ MODIFIED: بدء عملية قص الخلفية الفعلية
            Task {
                // Phase 0: قص الخلفية
                await MainActor.run {
                    analysisPhase = 0
                    speechService.speak(text: "بدء التحليل. جار قص خلفية الصورة.") // 🗣️ AVSpeech
                }
                
                do {
                    let processedData = try await rembgService.removeBackground(image: originalImage)
                    if let processedImage = UIImage(data: processedData) {
                        await MainActor.run {
                            itemData.processedImage = processedImage
                            print("✅ تم قص الخلفية بنجاح.")
                        }
                    }
                } catch {
                    // إذا فشل قص الخلفية، نستخدم الصورة الأصلية
                    await MainActor.run {
                        itemData.processedImage = originalImage
                        print("⚠️ فشل قص الخلفية: \(error.localizedDescription). سيتم استخدام الصورة الأصلية.")
                    }
                }

                // Phase 1: بدء التحليل الذكي
                await MainActor.run {
                    analysisPhase = 1
                    speechService.speak(text: "جاري اكتشاف محتويات القطعة وتحديد الفئة واللون والنقش.") // 🗣️ AVSpeech
                }

                if let classificationResult = await analyzeOnServer(originalImage) {
                    await MainActor.run {
                        itemData.category = classificationResult.category
                        itemData.color = classificationResult.color
                        itemData.pattern = classificationResult.pattern
                        print("✅ تم التحليل بنجاح.")
                    }
                } else {
                    print("⚠️ لم تصل نتيجة من سيرفر التحليل.")
                }

                // Phase 2: عرض النتائج
                await MainActor.run {
                    analysisPhase = 2
                    
                    // ✅ إعلان صوتي تفصيلي بنتائج التحليل
                    let categoryText = itemData.category.isEmpty ? "غير محدد" : itemData.category
                    let colorText = itemData.color.isEmpty ? "غير محدد" : itemData.color
                    let patternText = itemData.pattern.isEmpty ? "غير محدد" : itemData.pattern
                    
                    let announcement = "اكتمل التحليل. نوع القطعة \(categoryText)، لونها \(colorText)، والنقش \(patternText). يمكنك الآن مراجعة النتائج وتعديلها إذا رغبت."
                    
                    // استخدام DitharVoiceAssistant للإعلان (يتحقق من VoiceOver تلقائياً)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        DitharVoiceAssistant.shared.announceScreenChange(announcement)
                    }
                }
            }
        }


    }
    private func analyzeOnServer(_ image: UIImage) async -> CLIPResponse? {
        guard let jpg = image.jpegData(compressionQuality: 0.9) else { return nil }

        var req = URLRequest(url: apiURL)
        req.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(jpg)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(CLIPResponse.self, from: data)
        } catch {
            print("❌ analyzeOnServer error:", error.localizedDescription)
            return nil
        }
    }

}


// MARK: - دوال فارغة للتوافق مع الكود القديم (لا تفعل شيء)
// كل البيانات تُحفظ مرة واحدة في النهاية عبر saveToFirestore

func updateClotheAnalysis(docId: String, category: String?, color: String?, pattern: String?, completion: ((Bool)->Void)? = nil) {
    // دالة فارغة - الحفظ يتم في النهاية فقط
    completion?(true)
}

func updateClotheAttrs(docId: String, season: String?, brand: String?, size: String?, description: String?, completion: ((Bool)->Void)? = nil) {
    // دالة فارغة - الحفظ يتم في النهاية فقط
    completion?(true)
}


// MARK: - ملاحظة: مكون صف الحقل
struct FormFieldRow<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        HStack(spacing: 12) {
            content
                .font(.system(size: 14))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(red: 0.96, green: 0.96, blue: 0.96))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// MARK: - ملاحظة: الشاشة 3 - ربط المعرف RFID (نفس التصميم بالضبط)

// حالة المسح + اللون + النص المطلوبين
import SwiftUI
import Firebase
import FirebaseFirestore
import AVKit

// حالة المسح + اللون + النص المطلوبين
fileprivate enum ScanState {
    case idle        // بداية: رمادي "انتظار المسح"
    case waiting     // بعد الضغط: برتقالي "جاهز لربط المعرف"
    case capturing   // أثناء الالتقاط: برتقالي "جاري المسح…"
    case done        // نجاح: أخضر "تم ربط المعرف"
    case timeout     // فشل: أحمر "فشل ربط المعرف"

    var dotColor: Color {
        switch self {
        case .idle:                    return .gray.opacity(0.6)
        case .waiting, .capturing:     return .orange
        case .done:                    return .green
        case .timeout:                 return .red
        }
    }

    /// النص الظاهر على الشاشة
    var label: String {
        switch self {
        case .idle:        return "انتظار المسح"
        case .waiting:     return "جاهز لربط المعرف"
        case .capturing:   return "جاري المسح…"
        case .done:        return "تم ربط المعرف"
        case .timeout:     return "فشل ربط المعرف"
        }
    }

    /// وصف منطوق واضح للوصف الصوتي (AVSpeech) لما VoiceOver مو شغال
    var spokenDescription: String {
        switch self {
        case .idle:
            return "الحالة الحالية انتظار المسح. يمكنك الضغط على زر بدء المسح لبدء الربط."
        case .waiting:
            return "الحالة الحالية جاهز لربط المعرّف. قرّبي القطعة من القارئ ."
        case .capturing:
            return "الحالة الحالية جاري المسح. ثبّتي القطعة بالقرب من القارئ حتى يكتمل الربط."
        case .done:
            return "تم ربط المعرّف بنجاح. يمكنك المتابعة إلى خطوة التأكيد."
        case .timeout:
            return "فشل ربط المعرّف. انتهت مهلة الانتظار، يمكنك إعادة المحاولة."
        }
    }
}

// يبدأ طلب ربط EPC ويراقب حالته
fileprivate func startEnrollmentRequest(
    clotheId: String,
    userName: String,
    // ✅ خدمة النطق
    speechService: CustomSpeechService,
    onStatus: @escaping (_ status: String, _ epc: String?) -> Void
) -> ListenerRegistration {
    let db  = Firestore.firestore()
    let ref = db.collection("EnrollRequests").document()

    ref.setData([
        "status": "waiting",
        "clotheId": clotheId,
        "userName": userName,
        "createdAt": FieldValue.serverTimestamp(),
        "capturingAt": NSNull()
    ], merge: true)

    return ref.addSnapshotListener { snap, err in
        guard let data = snap?.data(), err == nil else { return }
        let status = data["status"] as? String ?? ""
        let epc    = data["epc"] as? String

        // 🗣️ نطق عند بدء الالتقاط (AVSpeech مستقل عن VoiceOver)
        if status == "capturing" && ref.documentID == snap?.documentID {
            if (snap?.metadata.hasPendingWrites == false) && (data["capturingAt"] as? NSNull == nil) {
                speechService.speak(text: "جاري المسح. يرجى تثبيت القطعة بالقرب من القارئ.")
            }
        }

        onStatus(status, epc)
    }
}

struct RFIDLinkView: View {
    @Environment(\.accessibilityManager) private var accessibilityManager
    @Binding var itemData: AddItem
    @Binding var currentStep: AddItemStep
    @State private var player: AVPlayer? = nil

    // خدمة النطق داخل الـ View
    private let speechService = CustomSpeechService()

    @State private var isScanning = false
    @State private var scanSuccess = false
    @State private var listener: ListenerRegistration? = nil
    @State private var scanState: ScanState = .idle   // يبدأ رمادي "انتظار المسح"
    
    @State private var showFullscreenVideo = false
    @State private var isPlaying = false
    @State private var showHowTo = false

    // حالات التنبيه للقطعة المرتبطة سابقًا
    @State private var showReplacementAlert = false
    @State private var existingItem: ExistingClothingItem? = nil
    @State private var pendingEPC: String = ""
    
    @State private var demoPlayer: AVPlayer? = {
        if let url = Bundle.main.url(forResource: "demo", withExtension: "mp4") {
            return AVPlayer(url: url)
        }
        if let url = Bundle.main.url(forResource: "demo", withExtension: "mov") {
            return AVPlayer(url: url)
        }
        return nil
    }()

    private func stopVideo() {
        player?.pause()
        player?.seek(to: .zero)
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                // ===== بطاقة الفيديو =====
                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.06))

                        if let p = demoPlayer {
                            VideoPlayer(player: p)
                                .aspectRatio(16/9, contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .frame(maxHeight: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                // مثلث التشغيل قبل البدء/عند الإيقاف
                                .overlay(
                                    Group {
                                        if !isPlaying {
                                            ZStack {
                                                Circle().fill(Color.black.opacity(0.35))
                                                    .frame(width: 64, height: 64)
                                                Image(systemName: "play.fill")
                                                    .font(.system(size: 28, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                    },
                                    alignment: .center
                                )
                                // زر تكبير (مخفي عن VoiceOver)
                                .overlay(
                                    Button(action: { showFullscreenVideo = true }) {
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(10)
                                            .background(Color.black.opacity(0.35))
                                            .clipShape(Circle())
                                    }
                                    .padding(10)
                                    .accessibilityHidden(true),   // 👈 مهم
                                    alignment: .topLeading
                                )
                                // تشغيل/إيقاف باللمس
                                .onTapGesture {
                                    if isPlaying {
                                        p.pause()
                                        // لا نتكلم لو VoiceOver شغال
                                        if !accessibilityManager.isVoiceOverRunning && accessibilityManager.canUseAVSpeech {
                                            DitharVoiceAssistant.shared.speak("تم إيقاف الفيديو التوضيحي.")
                                        }
                                    } else {
                                        p.play()
                                        if !accessibilityManager.isVoiceOverRunning && accessibilityManager.canUseAVSpeech {
                                            DitharVoiceAssistant.shared.speak("بدء تشغيل الفيديو التوضيحي لخطوات ربط المعرّف.")
                                        }
                                    }
                                    isPlaying.toggle()
                                }
                                .onDisappear {
                                    p.pause()
                                    isPlaying = false
                                }
                                .accessibilityHidden(true)   // 👈 نخفي VideoPlayer نفسه عن VoiceOver
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.black.opacity(0.06))
                                Image(systemName: "play.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(Color(red: 0.47, green: 0.58, blue: 0.44))
                                    .accessibilityHidden(true)
                            }
                            .frame(height: 180)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    // 👇 نخلي المربع كامل عنصر واحد لِـ VoiceOver
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("فيديو توضيحي لخطوات ربط المعرّف")
                    .accessibilityAddTraits([.isButton, .startsMediaSession])
                    // startsMediaSession 👆 تقول لــ VoiceOver: في وسائط صوتية بتبدأ، اسكت الحين

                    // النص تحت الفيديو – يخليه VoiceOver يقرأ الكلام نفسه
                    Text("قرّب المعرّف من القارئ لربطه بالقطعة. ")
                        .font(.system(size: 13))
                        .foregroundColor(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .accessibilityLabel("قرّب المعرّف من القارئ لربطه بالقطعة")


                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .padding(.horizontal, 20)
                .background(Color(red: 0.96, green: 0.96, blue: 0.96))
                .cornerRadius(16)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .onDisappear { demoPlayer?.pause(); isPlaying = false }

                // ===== مربع الحالة =====
                HStack(spacing: 12) {
                    Spacer()
                    Text(scanState.label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                        .accessibilityHidden(true)
                    Circle()
                        .fill(scanState.dotColor)
                        .frame(width: 10, height: 10)
                        .accessibilityHidden(true)
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(Color(red: 0.96, green: 0.96, blue: 0.96))
                .cornerRadius(10)
                .padding(.horizontal, 24)
                .accessibilityElement(children: .ignore)
                // ينطق فقط نص الحالة بدون مقدمة ولا كولن
                .accessibilityLabel(scanState.label)

                Spacer().frame(height: 20)

                Image(systemName: "wifi")
                    .font(.system(size: 60))
                    .foregroundColor(Color(red: 0.47, green: 0.58, blue: 0.44))
                    .padding(.vertical, 30)
                    .accessibilityHidden(true) // 👈 مرة وحدة وبس
                Spacer()

                // ===== الأزرار =====
                VStack(spacing: 12) {
                    Button(action: onPrimaryTapped) {
                        Text(scanSuccess ? "تأكيد" : (isScanning ? "جاري المسح..." : "بدء المسح"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(red: 0.47, green: 0.58, blue: 0.44))
                            .cornerRadius(12)
                    }
                    .disabled(scanState == .capturing)
                    .accessibilityLabel(scanSuccess ? " تأكيد" : (isScanning ? "جاري المسح" : " بدء المسح"))
                    .accessibilityValue(scanState.label)
                    .accessibilityHint(scanSuccess ? "الانتقال إلى مرحلة التأكيد" : "بدء عملية ربط المعرف، قرّب القطعة من القارئ")

                    Button(action: {
                        listener?.remove(); listener = nil
                        currentStep = .confirmation
                    }) {
                        Text("تخطي الربط")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .accessibilityLabel(" تخطي الربط")
                    .accessibilityHint("الانتقال إلى مرحلة التأكيد بدون ربط المعرف")
                }
                .padding(.horizontal, 24)

                Text("يمكنك دائمًا ربط المعرف لاحقًا من صفحة تفاصيل القطعة.")
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("يمكنك دائمًا ربط المعرف لاحقًا من صفحة تفاصيل القطعة")
            }
            .onDisappear {
                listener?.remove(); listener = nil
            }
            .onAppear {
                listener?.remove(); listener = nil
                isScanning = false
                scanSuccess = false
                scanState = .idle

                // نضمن وجود معرّف مؤقت للقطعة إذا لم يكن موجوداً
                if itemData.docId.isEmpty {
                    itemData.docId = UUID().uuidString
                }

                // إعلان صوتي عند فتح شاشة ربط المعرّف (AVSpeech فقط لو VoiceOver مو شغال)
                if !accessibilityManager.isVoiceOverRunning && accessibilityManager.canUseAVSpeech {
                    DitharVoiceAssistant.shared.announceScreenChange(
                        "خطوة ربط معرّف القطعة. في أعلى الشاشة فيديو يشرح طريقة الربط، وأسفل الشاشة زر لبدء المسح وحالة الربط."
                    )
                    DitharVoiceAssistant.shared.speak(
                        "للبدء، يمكنك تشغيل الفيديو التوضيحي، ثم الضغط على زر بدء المسح وتقريب القطعة من قارئ آر إف آي دي."
                    )
                }
            }
            // نطق تغيّر الحالة عبر AVSpeech فقط لما VoiceOver مو شغال
            .onChange(of: scanState) { newValue in
                if !accessibilityManager.isVoiceOverRunning && accessibilityManager.canUseAVSpeech {
                    DitharVoiceAssistant.shared.speak(newValue.spokenDescription)
                }
            }

            // MARK: - تنبيه استبدال RFID
            if showReplacementAlert, let existing = existingItem {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { }
                
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                        .padding(.top, 20)
                        .accessibilityHidden(true)
                    
                    Text("المعرف مرتبط بقطعة أخرى")
                        .font(.system(size: 18, weight: .bold))
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("هذا المعرف مرتبط بالفعل بـ \(existing.category). هل تريد استبدال الربط؟")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    if !existing.imageUrl.isEmpty {
                        AsyncImage(url: URL(string: existing.imageUrl)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 200, height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .accessibilityLabel("صورة القطعة القديمة المرتبطة بالمعرف، فئة \(existing.category)")
                            case .failure(_):
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 200, height: 200)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                    )
                                    .accessibilityLabel("صورة القطعة القديمة غير متوفرة")
                            case .empty:
                                ProgressView()
                                    .frame(width: 200, height: 200)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                    
                    VStack(spacing: 12) {
                        Button(action: {
                            confirmReplacement()
                        }) {
                            Text("تأكيد الاستبدال")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color(red: 0.47, green: 0.58, blue: 0.44))
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            cancelReplacement()
                        }) {
                            Text("إلغاء")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
                .frame(maxWidth: 350)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(radius: 20)
                .padding(.horizontal, 30)
            }
        }
        .fullScreenCover(isPresented: $showFullscreenVideo) {
            ZStack {
                Color.black.ignoresSafeArea()
                if let p = demoPlayer {
                    VideoPlayer(player: p)
                        .edgesIgnoringSafeArea(.all)
                        .onAppear { p.play(); isPlaying = true }
                        .onDisappear { p.pause(); isPlaying = false }
                }
                // زر إغلاق
                VStack {
                    HStack {
                        Button(action: { showFullscreenVideo = false }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.black.opacity(0.35))
                                .clipShape(Circle())
                        }
                        .padding()
                        .accessibilityLabel(" إغلاق الفيديو")
                        .accessibilityHint("يغلق مشغل الفيديو بملء الشاشة")
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showHowTo) {
            VStack(alignment: .trailing, spacing: 14) {
                Text("خطوات ربط معرّف RFID")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text("1) ألصق المعرّف على القطعة في مكان ثابت وغير مرئي.")
                Text("2) اضغط «بدء المسح» في التطبيق.")
                Text("3) قرّب القطعة من القارئ حتى تسمعين أو تشاهدين تأكيد الربط.")
                Text("4) بعد التأكيد، اضغطي «التالي» لإكمال الإضافة.")
                Spacer()
                Button("تم") { showHowTo = false }
                    .font(.body.bold())
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            }
            .padding()
            .presentationDetents([.medium])
        }
    }
    

    // MARK: - Actions
    private func onPrimaryTapped() {
        if scanSuccess {
            currentStep = .confirmation
            return
        }
        demoPlayer?.pause()
        demoPlayer?.seek(to: .zero)
        
        guard !itemData.docId.isEmpty else { return }

        // الضغط على بدء المسح
        isScanning = true
        scanState = .waiting

        // نطق عبر AVSpeech فقط لو VoiceOver مو شغال
        if !accessibilityManager.isVoiceOverRunning && accessibilityManager.canUseAVSpeech {
            DitharVoiceAssistant.shared.speak("تم بدء عملية ربط المعرّف. \(scanState.spokenDescription)")
        }

        listener = startEnrollmentRequest(
            clotheId: itemData.docId,
            userName: "hadeel", // بدّليها بالمستخدم الفعلي
            speechService: speechService
        ) { status, epc in
            switch status {
            case "capturing":
                scanState = .capturing

            case "done":
                if let epc = epc, !epc.isEmpty {
                    pendingEPC = epc
                    checkExistingEPC(epc: epc, currentClotheId: itemData.docId) { existing in
                        if let existing = existing {
                            self.speechService.speak(text: "تم اكتشاف معرّف مرتبط بقطعة أخرى. يرجى مراجعة التنبيه واتخاذ القرار.")
                            self.existingItem = existing
                            self.showReplacementAlert = true
                            self.isScanning = false
                            self.scanSuccess = false
                            self.scanState = .waiting
                            self.listener?.remove(); self.listener = nil
                        } else {
                            self.completeRFIDLink(epc: epc)
                        }
                    }
                } else {
                    self.speechService.speak(text: "فشل ربط المعرّف. لم يتم استلام بيانات المعرّف.")
                    isScanning = false
                    scanSuccess = false
                    scanState = .timeout
                    listener?.remove(); listener = nil
                }

            case "timeout":
                self.speechService.speak(text: "فشل ربط المعرّف. انتهت مهلة الانتظار.")
                isScanning = false
                scanSuccess = false
                scanState = .timeout
                listener?.remove(); listener = nil

            default:
                break
            }
        }
    }
       
    private func completeRFIDLink(epc: String) {
        isScanning = false
        scanSuccess = true
        scanState = .done
        itemData.rfidLinked = true
        itemData.rfidId = epc
        listener?.remove(); listener = nil
        speechService.speak(text: "تم ربط المعرّف بنجاح. يمكنك الآن الضغط على تأكيد للمتابعة.")
    }

    private func confirmReplacement() {
        guard !pendingEPC.isEmpty else { return }
        moveEPCToCurrent(epc: pendingEPC, keepClotheId: itemData.docId) { _ in
            self.showReplacementAlert = false
            self.existingItem = nil
            self.completeRFIDLink(epc: self.pendingEPC)
            self.pendingEPC = ""
        }
    }

    private func cancelReplacement() {
        showReplacementAlert = false
        existingItem = nil
        pendingEPC = ""
        isScanning = false
        scanSuccess = false
        scanState = .idle
        speechService.speak(text: "تم إلغاء الربط. يمكنك بدء المسح مرة أخرى أو تخطي الربط.")
    }
}

// MARK: - فحص إذا كان EPC مرتبط بقطعة أخرى
fileprivate func checkExistingEPC(
    epc: String,
    currentClotheId: String,
    completion: @escaping (ExistingClothingItem?) -> Void
) {
    let db = Firestore.firestore()
    
    db.collection("Clothes")
        .whereField("meta.epc", isEqualTo: epc)
        .getDocuments { snapshot, error in
            guard let documents = snapshot?.documents, error == nil else {
                completion(nil)
                return
            }
            for doc in documents {
                let docId = doc.documentID
                if docId != currentClotheId {
                    let data = doc.data()
                    let imageUrl = (data["image"] as? [String: Any])?["originalUrl"] as? String ?? ""
                    let category = (data["analysis"] as? [String: Any])?["category"] as? String ?? "قطعة"
                    let existingItem = ExistingClothingItem(
                        docId: docId,
                        imageUrl: imageUrl,
                        category: category,
                        epc: epc
                    )
                    completion(existingItem)
                    return
                }
            }
            completion(nil)
        }
}

// MARK: - نقل الـEPC للجديدة وجعل القديمة null (Batch واحد)
fileprivate func moveEPCToCurrent(
    epc: String,
    keepClotheId: String, // هذا هو الـ docId المؤقت للقطعة الجديدة (لا نحتاجه هنا)
    completion: @escaping (Bool) -> Void
) {
    let db = Firestore.firestore()
    
    // 1. ابحث عن كل القطع التي تحمل هذا الـ EPC
    db.collection("Clothes")
        .whereField("meta.epc", isEqualTo: epc)
        .getDocuments { snapshot, error in
            guard let documents = snapshot?.documents, error == nil else {
                print("❌ فشل البحث عن القطعة القديمة: \(error?.localizedDescription ?? "خطأ")")
                completion(false)
                return
            }
            
            // إذا لم نجد أي قطعة، فهذا يعني أن التاغ متاح.
            if documents.isEmpty {
                completion(true)
                return
            }
            
            let batch = db.batch()
            
            // 2. مر على كل القطع القديمة واجعل الـ epc فيها null
            for doc in documents {
                batch.updateData(["meta.epc": NSNull()], forDocument: doc.reference)
            }
            
            // 3. نفّذ التحديث
            batch.commit { err in
                if let err = err {
                    print("❌ فشل فك ارتباط المعرف من القطعة القديمة: \(err.localizedDescription)")
                    completion(false)
                } else {
                    print("✅ تم فك ارتباط المعرف من \(documents.count) قطعة قديمة بنجاح.")
                    completion(true)
                }
            }
        }
}

// MARK: - شاشة التأكيد (النجاح مباشرة)
struct ConfirmationSuccessView: View  {
    @Binding var itemData: AddItem
    @Binding var navigateToDetails: Bool
    let presentationMode: Binding<PresentationMode>
    var onItemAdded: ((ClothingItem) -> Void)? = nil
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // ✅ علامة الصح بدون قراءة من VoiceOver
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(Color(red: 0.47, green: 0.58, blue: 0.44))
                .accessibilityHidden(true)
            
            // النص اللي نبيه ينطق في الأخير
            VStack(spacing: 10) {
                Text(itemData.rfidLinked ? "تم ربط القطعة بنجاح" : "تم إضافة القطعة")
                    .font(.system(size: 22, weight: .bold))
                
                if !itemData.rfidLinked {
                    Text("يمكنك ربطها بالمعرف لاحقًا من صفحة التفاصيل")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            .accessibilityElement(children: .combine)
            
            if itemData.rfidLinked {
                HStack(spacing: 8) {
                    Image(systemName: "tag.fill")
                        .accessibilityHidden(true)
                    Text("تم ربط القطعة بنجاح")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(red: 0.47, green: 0.58, blue: 0.44))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(red: 0.47, green: 0.58, blue: 0.44).opacity(0.1))
                .cornerRadius(20)
                .accessibilityElement(children: .combine)
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                // 🔹 زر الحفظ (فوق - أخضر)
                Button(action: {
                    saveItemToWardrobe()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                                .accessibilityHidden(true)
                        }
                        Text(isSaving ? "جاري الحفظ" : "حفظ")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        isSaving
                        ? Color(red: 0.47, green: 0.58, blue: 0.44).opacity(0.7)
                        : Color(red: 0.47, green: 0.58, blue: 0.44)
                    )
                    .cornerRadius(12)
                }
                .disabled(isSaving)
                .accessibilityLabel(isSaving ? "جاري الحفظ" : " حفظ")
                .accessibilityHint("حفظ القطعة في خزانة الملابس والرجوع للقائمة الرئيسية")
                
                // 🔹 زر عرض التفاصيل (تحت - أبيض)
                Button(action: {
                    navigateToDetails = true
                }) {
                    Text("عرض تفاصيل القطعة")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .accessibilityLabel("عرض تفاصيل القطعة")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    private func saveItemToWardrobe() {
        guard !isSaving else { return }
        
        let imageToUpload = itemData.processedImage ?? itemData.image
        let isProcessed = (itemData.processedImage != nil)

        guard let image = imageToUpload else {
            errorMessage = "لم يتم اختيار صورة"
            showError = true
            return
        }
        
        isSaving = true
        
        FirebaseStorageManager.shared.uploadPNG(image: image) { result in
            switch result {
            case .success(let imageUrlString):
                self.saveToFirestore(imageUrl: imageUrlString, isProcessed: isProcessed)
            case .failure(let error):
                self.isSaving = false
                self.errorMessage = "فشل رفع الصورة: \(error.localizedDescription)"
                self.showError = true
                print("❌ فشل رفع الصورة: \(error.localizedDescription)")
            }
        }
    }
    
    private func saveToFirestore(imageUrl: String, isProcessed: Bool) {
        let db = Firestore.firestore()
        let finalDocId = itemData.docId
        
        itemData.imageUrl = imageUrl
        
        var metaDict: [String: Any] = [
            "createdAt": FieldValue.serverTimestamp(),
            "lastWearingDate": NSNull(),
            "wearingCount": 0,
            "isOutside": false,
            "isFavorite": false
        ]
        metaDict["epc"] = itemData.rfidLinked ? itemData.rfidId : NSNull()
        
        var attrsDict: [String: Any] = [:]
        attrsDict["season"]      = itemData.season.isEmpty      ? NSNull() : itemData.season
        attrsDict["brand"]       = itemData.brand.isEmpty       ? NSNull() : itemData.brand
        attrsDict["size"]        = itemData.size.isEmpty        ? NSNull() : itemData.size
        attrsDict["description"] = itemData.description.isEmpty ? NSNull() : itemData.description
        attrsDict["occasion"]    = itemData.occasion.isEmpty    ? NSNull() : itemData.occasion
        
        let payload: [String: Any] = [
            "image": [
                "originalUrl": imageUrl,
                "processedUrl": NSNull()
            ],
            "analysis": [
                "category": itemData.category,
                "color": itemData.color,
                "pattern": itemData.pattern
            ],
            "meta": metaDict,
            "attrs": attrsDict,
            "userId": authManager.user?.uid as Any
        ]
        
        db.collection("Clothes").document(finalDocId).setData(payload, merge: true) { error in
            self.isSaving = false
            
            if let error = error {
                self.errorMessage = "فشل حفظ البيانات: \(error.localizedDescription)"
                self.showError = true
                print("❌ Firestore error: \(error.localizedDescription)")
            } else {
                print("✅ تم حفظ القطعة بنجاح في Firestore بالـ ID الفريد: \(finalDocId)")
                
                let newItem = ClothingItem(
                    id: finalDocId,
                    name: itemData.category.isEmpty ? "قطعة جديدة" : itemData.category,
                    category: itemData.category,
                    color: itemData.color.isEmpty ? nil : itemData.color,
                    occasion: itemData.occasion.isEmpty ? nil : itemData.occasion,
                    brand: itemData.brand.isEmpty ? nil : itemData.brand,
                    pattern: itemData.pattern.isEmpty ? nil : itemData.pattern,
                    isFavorite: false,
                    isOutside: false,
                    localImageURLString: imageUrl.isEmpty ? nil : imageUrl
                )

                self.onItemAdded?(newItem)
            }
        }
    }
}
// MARK: - ملاحظة: صفحة تفاصيل القطعة (3 أقسام بالضبط)
// MARK: - صفحة تفاصيل القطعة (3 أقسام)
struct ItemDetailsView: View {
    @Binding var itemData: AddItem
    let onRequestRFIDLink: () -> Void   // يستدعى لنقل خطوة الربط
    let onDone: () -> Void              // يستدعى للرجوع للدولاب

    @Environment(\.presentationMode) var presentationMode
    @Environment(\.accessibilityManager) private var accessibilityManager

    @State private var isEditing = false
    @State private var showDeleteAlert = false

    // متغيرات مؤقتة للتعديل
    @State private var editedCategory: String = ""
    @State private var editedColor: String = ""
    @State private var editedPattern: String = ""
    @State private var editedSeason: String = ""
    @State private var editedBrand: String = ""
    @State private var editedSize: String = ""
    @State private var editedDescription: String = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {

                    // ===== القسم 1: الصورة الكبيرة =====
                    if let image = itemData.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 300)
                            .clipped()
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(
                                "صورة \(itemData.category.isEmpty ? "قطعة ملابس" : itemData.category) " +
                                "\(itemData.color.isEmpty ? "" : "بلون \(itemData.color)")"
                            )
                    }

                    // ===== القسم 2: تفاصيل القطعة =====
                    VStack(alignment: .trailing, spacing: 16) {
                        HStack {
                            Spacer()
                            Text("تفاصيل القطعة")
                                .font(.system(size: 18, weight: .bold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .multilineTextAlignment(.leading)
                                .accessibilityAddTraits(.isHeader)
                        }

                        // زر ربط / حالة ربط المعرف
                        if !itemData.rfidLinked {
                            Button(action: { onRequestRFIDLink() }) {
                                HStack(spacing: 6) {
                                    Text("اربطها بالمعرف")
                                    Image(systemName: "tag")
                                        .accessibilityHidden(true)
                                }
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.47, green: 0.58, blue: 0.44))
                                .cornerRadius(16)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("ربط القطعة بمعرف")
                            .accessibilityHint("الانتقال إلى خطوة ربط المعرف")
                        } else {
                            HStack(spacing: 6) {
                                Text("مرتبطة بالمعرف")
                                Image(systemName: "checkmark.circle.fill")
                                    .accessibilityHidden(true)
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(red: 0.47, green: 0.58, blue: 0.44))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(red: 0.47, green: 0.58, blue: 0.44).opacity(0.1))
                            .cornerRadius(16)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("القطعة مرتبطة بمعرف")
                        }

                        // ===== الحقول =====
                        VStack(spacing: 12) {
                            if isEditing {
                                // ===== وضع التعديل (نستخدم ClothingItemEditingFieldRow) =====
                                ClothingItemEditingFieldRow(
                                    title: "النوع",
                                    value: $editedCategory,
                                    options: [],
                                    groups: CATEGORY_GROUPS
                                )

                                ClothingItemEditingFieldRow(
                                    title: "اللون",
                                    value: $editedColor,
                                    options: [
                                        "أبيض", "أسود", "رمادي", "بني", "بيج",
                                        "أحمر", "وردي", "بنفسجي", "برتقالي", "أصفر",
                                        "أخضر", "سماوي", "أزرق", "ذهبي", "فضي"
                                    ]
                                )

                                ClothingItemEditingFieldRow(
                                    title: "النقش",
                                    value: $editedPattern,
                                    options: [
                                        "سادة", "مخطط", "مورد", "مربعات", "كاروهات",
                                        "منقط", "اشكال هندسية", "دانتيل"
                                    ]
                                )

                                ClothingItemEditingFieldRow(
                                    title: "الموسم",
                                    value: $editedSeason,
                                    options: ["شتاء", "صيف", "ربيع", "خريف", "كل المواسم"]
                                )

                                HStack {
                                    Text("الماركة")
                                        .font(.system(size: 14, weight: .medium))
                                    Spacer()
                                    TextField("أدخل اسم الماركة", text: $editedBrand)
                                        .multilineTextAlignment(.leading)
                                        .textFieldStyle(.plain)
                                }
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("الماركة")
                                .accessibilityValue(editedBrand.isEmpty ? "غير محددة" : editedBrand)

                                ClothingItemEditingFieldRow(
                                    title: "المقاس",
                                    value: $editedSize,
                                    options: ["XS", "S", "M", "L", "XL", "XXL"]
                                )

                                VStack(alignment: .trailing, spacing: 8) {
                                    Text("وصف القطعة")
                                        .font(.system(size: 14, weight: .medium))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .accessibilityHidden(true)

                                    TextEditor(text: $editedDescription)
                                        .frame(height: 80)
                                        .padding(8)
                                        .background(Color(red: 0.96, green: 0.96, blue: 0.96))
                                        .cornerRadius(8)
                                        .accessibilityLabel("وصف القطعة")
                                }

                            } else {
                                // ===== وضع العرض (نستخدم ClothingItemDetailRow) =====
                                ClothingItemDetailRow(title: "النوع",   value: itemData.category)
                                ClothingItemDetailRow(title: "اللون",   value: itemData.color)
                                ClothingItemDetailRow(title: "النقش",   value: itemData.pattern)
                                ClothingItemDetailRow(title: "الموسم",  value: itemData.season)
                                ClothingItemDetailRow(title: "الماركة", value: itemData.brand)
                                ClothingItemDetailRow(title: "المقاس",  value: itemData.size)

                                if !itemData.description.isEmpty {
                                    VStack(alignment: .trailing, spacing: 8) {
                                        Text("وصف القطعة")
                                            .font(.system(size: 14, weight: .medium))
                                        Text(itemData.description)
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                            .multilineTextAlignment(.trailing)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel("وصف القطعة")
                                    .accessibilityValue(itemData.description)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(red: 0.91, green: 0.90, blue: 0.89), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                    // ===== القسم 3: سجل الاستخدام (بنفس تنسيق ClothingItemDetailsView) =====
                    VStack(alignment: .trailing, spacing: 16) {
                        HStack {
                            Spacer()
                            Text("سجل الاستخدام")
                                .font(.system(size: 18, weight: .bold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .multilineTextAlignment(.leading)
                                .accessibilityAddTraits(.isHeader)
                        }

                        VStack(spacing: 16) {
                            // تاريخ الإضافة
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(Color(red: 0.47, green: 0.58, blue: 0.44))
                                    .accessibilityHidden(true)
                                Text("تاريخ الإضافة")
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                                Text(Date().formatted(date: .abbreviated, time: .omitted))
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("تاريخ الإضافة")
                            .accessibilityValue(Date().formatted(date: .abbreviated, time: .omitted))

                            // تاريخ آخر لبس
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(Color(red: 0.47, green: 0.58, blue: 0.44))
                                    .accessibilityHidden(true)
                                Text("تاريخ آخر لبس")
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                                Text("لم تُلبس بعد")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("تاريخ آخر لبس")
                            .accessibilityValue("لم تُلبس بعد")

                            // عدد مرات اللبس
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .foregroundColor(Color(red: 0.47, green: 0.58, blue: 0.44))
                                    .accessibilityHidden(true)
                                Text("عدد مرات اللبس")
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                                Text("0")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("عدد مرات اللبس")
                            .accessibilityValue("صفر")
                        }
                    }
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(red: 0.91, green: 0.90, blue: 0.89), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 30)

                    Spacer().frame(height: 50)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "arrow.right").foregroundColor(.black)
                }
                .accessibilityLabel("رجوع"),

                trailing: HStack(spacing: 16) {
                    if isEditing {
                        Button(action: {
                            // حفظ محلي في itemData
                            itemData.category    = editedCategory
                            itemData.color       = editedColor
                            itemData.pattern     = editedPattern
                            itemData.season      = editedSeason
                            itemData.brand       = editedBrand
                            itemData.size        = editedSize
                            itemData.description = editedDescription

                            // تحديث Firestore لو عندك docId
                            if !itemData.docId.isEmpty {
                                updateClotheAnalysis(
                                    docId: itemData.docId,
                                    category: itemData.category,
                                    color: itemData.color,
                                    pattern: itemData.pattern
                                )
                                updateClotheAttrs(
                                    docId: itemData.docId,
                                    season: itemData.season,
                                    brand: itemData.brand,
                                    size: itemData.size,
                                    description: itemData.description
                                )
                            }
                            isEditing = false
                            announceItemSummary()
                        }) {
                            HStack(spacing: 6) {
                                Text("حفظ").font(.system(size: 14, weight: .semibold))
                                Image(systemName: "checkmark")
                                    .accessibilityHidden(true)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.47, green: 0.58, blue: 0.44))
                            .cornerRadius(8)
                        }
                        .accessibilityLabel("حفظ التعديلات")

                        Button(action: { isEditing = false }) {
                            Text("إلغاء")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(red: 0.96, green: 0.96, blue: 0.96))
                                .cornerRadius(8)
                        }
                        .accessibilityLabel("إلغاء التعديلات")

                    } else {
                        Button(action: {
                            editedCategory    = itemData.category
                            editedColor       = itemData.color
                            editedPattern     = itemData.pattern
                            editedSeason      = itemData.season
                            editedBrand       = itemData.brand
                            editedSize        = itemData.size
                            editedDescription = itemData.description
                            isEditing = true
                        }) {
                            HStack(spacing: 6) {
                                Text("تعديل").font(.system(size: 14))
                                Image(systemName: "pencil")
                                    .accessibilityHidden(true)
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.96, green: 0.96, blue: 0.96))
                            .cornerRadius(8)
                        }
                        .accessibilityLabel("تعديل بيانات القطعة")
                    }

                    Button(action: { showDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .padding(8)
                            .background(Color(red: 1, green: 0.89, blue: 0.89))
                            .cornerRadius(8)
                    }
                    .accessibilityLabel("حذف القطعة")
                }
            )
        }
        .environment(\.layoutDirection, .rightToLeft)
        .alert("حذف القطعة", isPresented: $showDeleteAlert) {
            Button("إلغاء", role: .cancel) { }
            Button("حذف", role: .destructive) {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("هل أنت متأكد من حذف هذه القطعة؟")
        }
        .onAppear {
            announceItemSummary()
        }
    }

    // ===== نطق ملخص تفاصيل القطعة بالصوت (مع عدم إزعاج VoiceOver) =====
    private func announceItemSummary() {
        let categoryText = itemData.category.isEmpty ? "غير محدد" : itemData.category
        let colorText    = itemData.color.isEmpty    ? "غير محدد" : itemData.color
        let patternText  = itemData.pattern.isEmpty  ? "غير محدد" : itemData.pattern
        let seasonText   = itemData.season.isEmpty   ? "غير محدد" : itemData.season
        let brandText    = itemData.brand.isEmpty    ? "غير محددة" : itemData.brand
        let sizeText     = itemData.size.isEmpty     ? "غير محدد" : itemData.size

        let message = """
        تفاصيل القطعة. النوع \(categoryText)، اللون \(colorText)، النقش \(patternText)، الموسم \(seasonText)، الماركة \(brandText)، المقاس \(sizeText).
        """

        if accessibilityManager.canUseAVSpeech && !accessibilityManager.isVoiceOverRunning {
            DitharVoiceAssistant.shared.announceScreenChange(message)
        }
    }
}


//
// MARK: - صف تفاصيل قابل للقراءة من VoiceOver
//
private struct ItemDetailRow: View {
    let title: String
    let value: String

    var body: some View {
        let displayText = value.isEmpty ? "-" : value
        let accessibilityValueText = value.isEmpty ? "غير محدد" : value

        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
            Spacer(minLength: 0)
            Text(displayText)
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(accessibilityValueText)")
    }
}

//
// MARK: - صف تعديل عام (العنوان + محتوى مخصص)
//
private struct ItemEditableFieldRow<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack {
            content()
            Spacer()
            Text(title)
                .font(.system(size: 14, weight: .medium))
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

// MARK: - ملاحظة: Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
    

}


// MARK: - ملاحظة: Preview
struct AddItemFlowView_Previews: PreviewProvider {
    static var previews: some View {
        AddItemFlowView()
            .environment(\.layoutDirection, .rightToLeft)
            .previewDevice(PreviewDevice(rawValue: "iPhone 16 Pro"))
    }
}
