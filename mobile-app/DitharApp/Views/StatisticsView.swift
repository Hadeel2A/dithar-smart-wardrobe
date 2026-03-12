//
//  StatisticsView.swift
//  DitharApp
//
//  Created by Rahaf AlFantoukh on 07/08/1447 AH.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import Charts

// MARK: - Soft Theme Constants
struct SoftTheme {
    static let background = Color.white
    static let cardWhite = Color.white

    static let pastelGreen  = Color(red: 0.64, green: 0.82, blue: 0.61)
    static let pastelOrange = Color(red: 0.94, green: 0.73, blue: 0.55)
    static let pastelPurple = Color(red: 0.72, green: 0.62, blue: 0.68)
    static let pastelRed    = Color(red: 0.95, green: 0.58, blue: 0.55)

    static let textPrimary = Color(red: 0.2, green: 0.2, blue: 0.25)
    static let textSecondary = Color.secondary.opacity(0.8)

    static let shadow = Color.black.opacity(0.08)
    static let cornerRadius: CGFloat = 28
}


// MARK: - Top Decorative Background
struct TopGreenDecor: View {
    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 60, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            SoftTheme.pastelGreen.opacity(0.55),
                            SoftTheme.pastelGreen.opacity(0.15),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: geo.size.height * 0.42)
                .frame(maxWidth: .infinity)
                .offset(y: -geo.size.height * 0.08)

            Circle()
                .fill(SoftTheme.pastelGreen.opacity(0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 2)
                .offset(x: -80, y: -120)

            Circle()
                .fill(SoftTheme.pastelGreen.opacity(0.12))
                .frame(width: 180, height: 180)
                .blur(radius: 2)
                .offset(x: 120, y: -70)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}


// MARK: - Master Subcategories (للفئات فقط)
private let SUBCATEGORY_MASTER: [String: [String]] = [
    "قطع علوية": ["قميص", "بلوزة", "كنزة", "معطف", "تيشيرت"],
    "قطع سفلية": ["بنطال", "تنورة", "شورت"],
    "قطع كاملة": ["فستان", "شيال", "ثوب", "عباية"],
    "أحذية": ["حذاء رياضي", "حذاء رسمي", "صندل", "كعب", "بوت"],
    "إكسسوارات": ["سلسال", "اسورة", "حلق", "خاتم", "ساعة", "نظارة", "حقيبة", "حزام", "قبعة", "وشاح"]
]

// MARK: - Helpers (Patterns)
private func patternAssetName(_ name: String) -> String? {
    let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let map: [String: String] = [
        "منقط": "dot",
        "مخطط": "striped",
        "مورد": "floral",
        "مربعات": "checkered",
        "كاروهات": "plaid",
        "اشكال هندسية": "geometric",
        "دانتيل": "lace"
    ]
    return map[n]
}

@available(iOS 16.0, *)
private func patternShapeStyle(for name: String) -> AnyShapeStyle {
    let n = name.trimmingCharacters(in: .whitespacesAndNewlines)

    // ✅ "سادة" دائمًا أخضر فاتح
    if n.isEmpty || n == "سادة" {
        return AnyShapeStyle(SoftTheme.pastelGreen.opacity(0.55))
    }

    if let asset = patternAssetName(n) {
        return AnyShapeStyle(ImagePaint(image: Image(asset), scale: 0.18))
    } else {
        return AnyShapeStyle(SoftTheme.pastelGreen.opacity(0.55))
    }
}

// MARK: - Main View
struct WardrobeStatisticsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    @State private var totalItems: Int = 0

    // ✅ الجديد: داخل/خارج الخزانة حسب isOutside
    @State private var insideClosetCount: Int = 0
    @State private var outsideClosetCount: Int = 0

    @State private var mainCategoryCounts: [(String, Int)] = []
    @State private var colorCounts: [(String, Int)] = []
    @State private var patternCounts: [(String, Int)] = []

    @State private var topUsed: [StatsClothingItem] = []
    @State private var neglected: [StatsClothingItem] = []

    @State private var cachedItems: [StatsClothingItem] = []
    @State private var showCategoryDrilldown = false
    @State private var showColorDrilldown = false
    @State private var showPatternDrilldown = false

    @State private var neglectedVisibleCount: Int = 3

    var body: some View {
        NavigationStack {
            ZStack {

                SoftTheme.background.ignoresSafeArea()

                TopGreenDecor()
                    .zIndex(0)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {

                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("الإحصائيات")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(SoftTheme.textPrimary)
                                    .padding(.top, 6)   // 👈 ينزلها شوي

                                Text("نظرة على خزانتك اليوم")
                                    .font(.subheadline)
                                    .foregroundStyle(SoftTheme.textSecondary)
                            }

                            Spacer()

                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(SoftTheme.textPrimary)
                                    .padding(12)
                                    .background(Circle().fill(SoftTheme.cardWhite))
                                    .shadow(color: SoftTheme.shadow, radius: 10)
                            }
                            .padding(.top, -20)   // ⬆️ يرفعه فوق شوي
                        }
                        .padding(.horizontal)
                        .padding(.top, 30)

                        // ✅ Top Cards (NEW LAYOUT)
                        // يمين: إجمالي القطع
                        // يسار: مستطيلين فوق بعض (داخل/خارج الخزانة)
                        // ✅ Top Cards (UPDATED)
                        // ✅ Top Cards (FINAL FIX)
                        // ✅ Top Cards — الحل النظيف
                        // ✅ Top Cards — إجمالي يمين + تصغير ارتفاع داخل/خارج
                        let topCardsContainerHeight: CGFloat = 150
                        let miniSpacing: CGFloat = 23
                        let miniCardHeight: CGFloat = 58

                        // ✅ هذا الارتفاع يمثل مجموع ارتفاع البطاقتين الصغيرتين والمسافة بينهما
                        let leftStackHeight: CGFloat = (miniCardHeight * 2) + miniSpacing

                        // ✅ هنا قمنا بتغيير ارتفاع البطاقة الكبيرة ليصبح ضعف ارتفاع الـ Stack الأيسر
                        let bigCardHeight: CGFloat = leftStackHeight + 20

                        HStack(spacing: 16) {

                            // ✅ إجمالي القطع (يصير يمين لأنكِ RTL)
                            StatCardColored(
                                title: "إجمالي القطع",
                                value: "\(totalItems)",
                                subtitle: "قطعة ملابس",
                                color: SoftTheme.pastelPurple,
                                icon: "tshirt"
                            )
                            .frame(height: bigCardHeight)

                            // ✅ داخل/خارج (يسار)
                            VStack(spacing: miniSpacing) {

                                StatCardColoredCompact(
                                    title: "داخل الخزانة",
                                    value: "\(insideClosetCount)",
                                    subtitle: "قطعة",
                                    color: SoftTheme.pastelGreen,
                                    icon: "house.fill"
                                )
                                .frame(height: miniCardHeight)

                                StatCardColoredCompact(
                                    title: "خارج الخزانة",
                                    value: "\(outsideClosetCount)",
                                    subtitle: "قطعة",
                                    color: SoftTheme.pastelOrange,
                                    icon: "arrow.up.right.square"
                                )
                                .frame(height: miniCardHeight)
                            }
                            .frame(height: leftStackHeight, alignment: .top)
                        }
                        // ❌ لا تحدد ارتفاعًا ثابتًا هنا، اتركه يتمدد مع المحتوى
                        // .frame(height: topCardsContainerHeight, alignment: .top)
                        .padding(.horizontal)
                        .padding(.top, 6)
                        .padding(.bottom, 10)


                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView().tint(SoftTheme.pastelGreen)
                                Spacer()
                            }
                            .padding(.vertical, 20)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal)
                        }

                        // Distribution Section
                        VStack(alignment: .leading, spacing: 16) {


                            if #available(iOS 16.0, *) {
                                CategoryDonutWithLegendCard(
                                    items: mainCategoryCounts.map { DonutSlice(name: $0.0, value: $0.1) },
                                    onOpen: { showCategoryDrilldown = true }
                                )
                                .padding(.horizontal)

                                HStack(spacing: 16) {
                                    DonutCardSoft(title: "النقشات") {
                                        DonutPatternChart(items: patternCounts.map { DonutSlice(name: $0.0, value: $0.1) })
                                    }
                                    .contentShape(RoundedRectangle(cornerRadius: SoftTheme.cornerRadius))
                                    .onTapGesture { showPatternDrilldown = true }

                                    DonutCardSoft(title: "الألوان") {
                                        DonutColorChart(items: colorCounts.map { DonutSlice(name: $0.0, value: $0.1) })
                                    }
                                    .contentShape(RoundedRectangle(cornerRadius: SoftTheme.cornerRadius))
                                    .onTapGesture { showColorDrilldown = true }
                                }
                                .padding(.horizontal)

                            } else {
                                Text("يتطلب iOS 16 لعرض الرسوم البيانية.")
                                    .font(.caption)
                                    .foregroundStyle(SoftTheme.textSecondary)
                                    .padding(.horizontal)
                            }
                        }

                        // Usage Section
                        VStack(alignment: .leading, spacing: 16) {


                            // Most Used
                            // Most Used



                            // Neglected
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .firstTextBaseline) {

                                    // العنوان + (منذ سنة)
                                    VStack(spacing: 2) {

                                        Text("القطع المهملة")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(SoftTheme.textSecondary)
                                            .frame(maxWidth: .infinity, alignment: .trailing)   // العنوان يمين

                                        Text("منذ سنة")
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundStyle(SoftTheme.textSecondary.opacity(0.75))
                                            .frame(maxWidth: .infinity, alignment: .center)     // "منذ سنة" بالنص
                                    }
                                    .fixedSize(horizontal: true, vertical: false)               // ✅ يخلي العرض على قد العنوان


                                    Spacer()

                                    // العدد بأقصى اليسار
                                    Text("(\(neglected.count) قطع)")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(SoftTheme.textSecondary.opacity(0.85))
                                }



                                ZStack(alignment: .bottomTrailing) {
                                    ThreeImagesGridSoft(
                                        items: Array(neglected.prefix(neglectedVisibleCount)),
                                        emptyText: "لا توجد قطع مهملة"
                                    )

                                    if neglectedVisibleCount < neglected.count {
                                        Button {
                                            neglectedVisibleCount = min(neglectedVisibleCount + 3, neglected.count)
                                        } label: {
                                            Image(systemName: "plus")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(SoftTheme.textPrimary.opacity(0.9))
                                                .frame(width: 34, height: 34)
                                                .background(Circle().fill(SoftTheme.pastelGreen.opacity(0.35)))
                                                .overlay(Circle().stroke(SoftTheme.pastelGreen.opacity(0.45), lineWidth: 1))
                                                .shadow(color: SoftTheme.shadow, radius: 8, x: 0, y: 6)
                                        }
                                        .padding(.leading, 14)
                                        .padding(.bottom, 1)
                                    }
                                }

                                if let url = URL(string: "https://kesa.sa/") {
                                    Link(destination: url) {
                                        Text("تبرع الآن")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundStyle(SoftTheme.textPrimary)
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 18)
                                            .background(
                                                Capsule().fill(SoftTheme.pastelGreen.opacity(0.25))
                                            )
                                            .overlay(
                                                Capsule().stroke(SoftTheme.pastelGreen.opacity(0.40), lineWidth: 1)
                                            )
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, 6)
                                }
                            }
                            .padding(20)
                            .background(SoftTheme.cardWhite)
                            .cornerRadius(SoftTheme.cornerRadius)
                            .shadow(color: SoftTheme.shadow, radius: 22, x: 0, y: 14)
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
            .task { await loadStats() }

            // Sheet: Category
            .sheet(isPresented: $showCategoryDrilldown) {
                if #available(iOS 16.0, *) {
                    CategoryDrilldownSheet(
                        allItems: cachedItems,
                        mainCategoryResolver: mainCategory(forSubcategory:)
                    )
                    .presentationDetents([.fraction(0.80), .large])
                    .presentationDragIndicator(.visible)
                } else { Text("يتطلب iOS 16") }
            }

            // Sheet: Color
            .sheet(isPresented: $showColorDrilldown) {
                if #available(iOS 16.0, *) {
                    ColorDrilldownSheet(
                        allItems: cachedItems,
                        mainCategoryResolver: mainCategory(forSubcategory:)
                    )
                    .presentationDetents([.fraction(0.80), .large])
                    .presentationDragIndicator(.visible)
                } else { Text("يتطلب iOS 16") }
            }

            // Sheet: Pattern
            .sheet(isPresented: $showPatternDrilldown) {
                if #available(iOS 16.0, *) {
                    PatternDrilldownSheet(
                        allItems: cachedItems,
                        mainCategoryResolver: mainCategory(forSubcategory:)
                    )
                    .presentationDetents([.fraction(0.80), .large])
                    .presentationDragIndicator(.visible)
                } else { Text("يتطلب iOS 16") }
            }
        }
    }

    // MARK: - Data Loading
    private func loadStats() async {
        guard let uid = authManager.user?.uid else { return }
        isLoading = true
        errorMessage = nil
        do {
            let items = try await fetchAllClothes(uid: uid)
            cachedItems = items

            totalItems = items.count

            // ✅ داخل/خارج حسب isOutside
            insideClosetCount = items.filter { !$0.isOutside }.count
            outsideClosetCount = items.filter { $0.isOutside }.count

            mainCategoryCounts = computeMainCategoryDistribution(items)

            colorCounts = computeColorDistributionStable(items)
            patternCounts = computePatternDistributionStable(items)

            topUsed = computeTopUsed(items, top: 3)
            neglected = computeNeglected(items)
            neglectedVisibleCount = min(3, neglected.count)

            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    private func computeMainCategoryDistribution(_ items: [StatsClothingItem]) -> [(String, Int)] {
        let grouped = Dictionary(grouping: items, by: { mainCategory(forSubcategory: $0.subcategory) })
        return grouped.map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }
    }

    private func fetchAllClothes(uid: String) async throws -> [StatsClothingItem] {
        let snap = try await Firestore.firestore()
            .collection("Clothes")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()
        return snap.documents.compactMap { StatsClothingItem.from(doc: $0) }
    }

    private func computeNeglected(_ items: [StatsClothingItem]) -> [StatsClothingItem] {
        let cutoff = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()

        return items.filter { item in
            guard item.hasTag else { return false }

            if let last = item.lastWearingDate {
                return last <= cutoff
            } else {
                return (item.createdAt ?? Date.distantFuture) <= cutoff
            }
        }
        .sorted {
            let d0 = $0.lastWearingDate ?? $0.createdAt ?? .distantPast
            let d1 = $1.lastWearingDate ?? $1.createdAt ?? .distantPast
            return d0 < d1
        }
    }

    private func computeColorDistributionStable(_ items: [StatsClothingItem]) -> [(String, Int)] {
        let grouped = Dictionary(grouping: items, by: { $0.color.isEmpty ? "غير محدد" : $0.color })
            .mapValues { $0.count }

        var arr = grouped.map { ($0.key, $0.value) }
        arr.sort {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            return $0.0 < $1.0
        }
        return arr
    }

    private func computePatternDistributionStable(_ items: [StatsClothingItem]) -> [(String, Int)] {
        let grouped = Dictionary(grouping: items, by: { $0.pattern.isEmpty ? "سادة" : $0.pattern })
            .mapValues { $0.count }

        var arr = grouped.map { ($0.key, $0.value) }
        arr.sort {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            return $0.0 < $1.0
        }
        return arr
    }

    private func computeTopUsed(_ items: [StatsClothingItem], top: Int) -> [StatsClothingItem] {
        Array(
            items.sorted {
                if $0.wearingCount != $1.wearingCount { return $0.wearingCount > $1.wearingCount }
                let d0 = $0.lastWearingDate ?? $0.createdAt ?? .distantPast
                let d1 = $1.lastWearingDate ?? $1.createdAt ?? .distantPast
                return d0 > d1
            }
            .prefix(top)
        )
    }

    private func mainCategory(forSubcategory sub: String) -> String {
        let s = sub.trimmingCharacters(in: .whitespacesAndNewlines)
        if ["قميص", "بلوزة", "كنزة", "معطف", "تيشيرت", "توب", "جاكيت", "هودي", "بليزر"].contains(s) { return "قطع علوية" }
        if ["بنطال", "تنورة", "شورت", "جينز", "ليقنز"].contains(s) { return "قطع سفلية" }
        if ["فستان", "ثوب", "عباية", "جمبسوت", "بدلة", "شيال"].contains(s) { return "قطع كاملة" }
        if ["حذاء رياضي", "حذاء رسمي", "صندل", "كعب", "بوت", "حذاء"].contains(s) { return "أحذية" }
        return "إكسسوارات"
    }
}

// MARK: - Components
struct StatCardColored: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.8))
            }
            
            // ✅ --- الإضافة السحرية هنا --- ✅
            // هذا الـ Spacer سيجبر الـ VStack على التمدد ليملأ الإطار
            Spacer()
            // ✅ --------------------------- ✅
        }
        .padding(20)
        // ❌ لا تضع .frame هنا، بل في مكان استدعاء الكرت
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: SoftTheme.cornerRadius).fill(color))
        .shadow(color: color.opacity(0.3), radius: 15, x: 0, y: 10)
    }
}

// ✅ كرت أصغر (للمستطيلين يسار فوق بعض)
// ✅ كرت أصغر (داخل/خارج + نستخدمه كمان لإجمالي القطع)
// ✅ للكرتين فقط (داخل/خارج): كلمة "قطعة" جنب الرقم لتقليل الطول
struct StatCardColoredCompact: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)

                Spacer()

                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.75))
            }

            // ✅ الرقم + "قطعة" جنب بعض
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))

                Spacer()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: SoftTheme.cornerRadius).fill(color))
        .shadow(color: color.opacity(0.22), radius: 10, x: 0, y: 8)
    }
}

struct DonutCardSoft<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(SoftTheme.textSecondary)

            content
                .frame(height: 160)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(SoftTheme.cardWhite)
        .cornerRadius(SoftTheme.cornerRadius)
        .shadow(color: SoftTheme.shadow, radius: 22, x: 0, y: 14)
    }
}

@available(iOS 16.0, *)
struct CategoryDonutWithLegendCard: View {
    let items: [DonutSlice]
    let onOpen: () -> Void

    private let colorMap: [String: Color] = [
        "قطع علوية": SoftTheme.pastelGreen,
        "قطع سفلية": SoftTheme.pastelOrange,
        "قطع كاملة": SoftTheme.pastelPurple,
        "أحذية": SoftTheme.pastelRed,
        "إكسسوارات": Color.gray.opacity(0.35)
    ]

    var body: some View {
        let total = max(items.reduce(0) { $0 + $1.value }, 1)

        VStack(spacing: 12) {
            Text("الفئات")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(SoftTheme.textSecondary)

            HStack(spacing: 50) {
                legendColumn(items: items)
                donut(total: total)
            }
            .environment(\.layoutDirection, .leftToRight)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(SoftTheme.cardWhite)
        .cornerRadius(SoftTheme.cornerRadius)
        .shadow(color: SoftTheme.shadow, radius: 22, x: 0, y: 14)
        .contentShape(RoundedRectangle(cornerRadius: SoftTheme.cornerRadius))
        .onTapGesture { onOpen() }
    }

    private func donut(total: Int) -> some View {
        ZStack {
            Chart(items) { item in
                SectorMark(
                    angle: .value("Count", item.value),
                    innerRadius: .ratio(0.65),
                    angularInset: 2
                )
                .cornerRadius(6)
                .foregroundStyle(colorMap[item.name] ?? Color.gray.opacity(0.3))
            }
            .chartLegend(.hidden)
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Text("\(total)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(SoftTheme.textPrimary)
                Text("قطعة")
                    .font(.system(size: 10))
                    .foregroundStyle(SoftTheme.textSecondary)
            }
        }
        .frame(width: 170, height: 170)
    }

    private func legendColumn(items: [DonutSlice]) -> some View {
        let total = max(items.reduce(0) { $0 + $1.value }, 1)

        return VStack(alignment: .leading, spacing: 14) {
            ForEach(items) { item in
                let percent = Int(round(Double(item.value) / Double(total) * 100))

                HStack(spacing: 10) {

                    Text(" \(item.name) \(percent)٪")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(SoftTheme.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    Circle()
                        .fill(colorMap[item.name] ?? .gray)
                        .frame(width: 10, height: 10)
                        .frame(width: 14, alignment: .center)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
    }

}

// MARK: - Donut Color (الصفحة الرئيسية)
@available(iOS 16.0, *)
struct DonutColorChart: View {
    let items: [DonutSlice]

    var body: some View {
        let colorsCount = items.count
        ZStack {
            
            Chart(items) { item in
                SectorMark(
                    angle: .value("Count", item.value),
                    innerRadius: .ratio(0.65),
                    outerRadius: .ratio(1.0),
                    angularInset: 2.0
                )
                .cornerRadius(6)
                .foregroundStyle(Color.gray.opacity(0.5))
            }

            Chart(items) { item in
                SectorMark(
                    angle: .value("Count", item.value),
                    innerRadius: .ratio(0.66),
                    outerRadius: .ratio(0.99),
                    angularInset: 2.8
                )
                .cornerRadius(5)
                .foregroundStyle(colorForName(item.name))
            }
            
            VStack(spacing: 0) {
                Text("\(colorsCount)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(SoftTheme.textPrimary)
                Text("لون")
                    .font(.system(size: 10))
                    .foregroundStyle(SoftTheme.textSecondary)
            }
            .allowsHitTesting(false)
        }
        .allowsHitTesting(false)
    }


    private func colorForName(_ name: String) -> Color {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        switch n {
        case "أسود": return .black
        case "أبيض": return .white
        case "أحمر": return SoftTheme.pastelRed
        case "أزرق": return Color.blue.opacity(0.6)
        case "أخضر": return SoftTheme.pastelGreen
        case "أصفر": return Color.yellow.opacity(0.6)
        case "بيج": return Color(red: 0.95, green: 0.9, blue: 0.8)
        case "رمادي": return .gray.opacity(0.6)
        case "بني": return .brown.opacity(0.6)
        case "وردي": return .pink.opacity(0.6)
        case "بنفسجي": return SoftTheme.pastelPurple
        case "برتقالي": return SoftTheme.pastelOrange
        case "ذهبي": return Color(red: 0.93, green: 0.84, blue: 0.45)
        default: return SoftTheme.pastelGreen.opacity(0.5)
        }
    }
}

// MARK: - Donut Pattern (الصفحة الرئيسية)
@available(iOS 16.0, *)
struct DonutPatternChart: View {
    let items: [DonutSlice]

    var body: some View {
        ZStack {
            Chart(items) { item in
                SectorMark(
                    angle: .value("Count", item.value),
                    innerRadius: .ratio(0.65),
                    angularInset: 2
                )
                .cornerRadius(6)
                .foregroundStyle(patternShapeStyle(for: item.name))
            }
            .chartLegend(.hidden)
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Text("\(items.count)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(SoftTheme.textPrimary)
                Text("نقشات")
                    .font(.system(size: 10))
                    .foregroundStyle(SoftTheme.textSecondary)
            }
        }
    }
}

// MARK: - Images Row
struct ThreeImagesRowSoft: View {
    let items: [StatsClothingItem]
    let emptyText: String
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        if items.isEmpty {
            Text(emptyText)
                .font(.caption)
                .foregroundStyle(SoftTheme.textSecondary)
        } else {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(items.prefix(3)) { item in
                    NavigationLink {
                        ClothingItemDetailsView(clothingItemId: item.id)
                            .environment(\.layoutDirection, .rightToLeft)

                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20).fill(SoftTheme.background)

                            if let urlString = item.imageUrl, let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFit().padding(10)
                                    } else {
                                        Image(systemName: "photo")
                                            .foregroundStyle(SoftTheme.textSecondary)
                                    }
                                }
                            } else {
                                Image(systemName: "photo")
                                    .foregroundStyle(SoftTheme.textSecondary)
                            }
                        }
                        .aspectRatio(0.85, contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.plain) // مهم
                }
            }
        }
    }
}

struct ThreeImagesGridSoft: View {
    let items: [StatsClothingItem]
    let emptyText: String

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        if items.isEmpty {
            Text(emptyText)
                .font(.caption)
                .foregroundStyle(SoftTheme.textSecondary)
        } else {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(items) { item in
                    NavigationLink {
                        ClothingItemDetailsView(clothingItemId: item.id)
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20).fill(SoftTheme.background)

                            if let urlString = item.imageUrl, let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFit().padding(10)
                                    } else {
                                        Image(systemName: "photo")
                                            .foregroundStyle(SoftTheme.textSecondary)
                                    }
                                }
                            } else {
                                Image(systemName: "photo")
                                    .foregroundStyle(SoftTheme.textSecondary)
                            }
                        }
                        .aspectRatio(0.85, contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}


// MARK: - Drilldown Sheet (Category)
@available(iOS 16.0, *)
struct CategoryDrilldownSheet: View {
    let allItems: [StatsClothingItem]
    let mainCategoryResolver: (String) -> String

    @State private var selectedMainCategory: String = "قطع علوية"

    private let colorMap: [String: Color] = [
        "قطع علوية": SoftTheme.pastelGreen,
        "قطع سفلية": SoftTheme.pastelOrange,
        "قطع كاملة": SoftTheme.pastelPurple,
        "أحذية": SoftTheme.pastelRed,
        "إكسسوارات": Color.gray.opacity(0.35)
    ]

    var body: some View {
        let mainCounts = computeMainCategoryDistribution(allItems)
        let donutItems = mainCounts.map { DonutSlice(name: $0.0, value: $0.1) }

        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {

                Text("تفاصيل الفئات")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(SoftTheme.textPrimary)
                    .padding(.top, 28)

                InteractiveCategoryCard(
                    items: donutItems,
                    selected: $selectedMainCategory,
                    colorMap: colorMap
                )
                .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 12) {

                    Text(selectedMainCategory)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(SoftTheme.textPrimary)

                    let subCounts = computeSubcategoryDistribution(for: selectedMainCategory)
                    let chartData = subCounts.filter { $0.1 > 0 }.map { (name: $0.0, count: $0.1) }

                    if chartData.isEmpty {
                        Text("لا توجد عناصر ضمن هذه الفئة.")
                            .font(.system(size: 12))
                            .foregroundStyle(SoftTheme.textSecondary)
                            .padding(.bottom, 6)
                    } else {
                        SubcategoryVerticalBarChart(
                            data: chartData,
                            barStyle: AnyShapeStyle((colorMap[selectedMainCategory] ?? SoftTheme.pastelGreen).opacity(0.65))
                        )
                        .frame(maxWidth: 320)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 6)
                    }
                }
                .padding(16)
                .background(SoftTheme.cardWhite)
                .cornerRadius(SoftTheme.cornerRadius)
                .shadow(color: Color.black.opacity(0.1), radius: 14, x: 0, y: 10)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

                Spacer(minLength: 16)
            }
        }
        .background(SoftTheme.background)
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            if let first = donutItems.sorted(by: { $0.value > $1.value }).first?.name {
                selectedMainCategory = first
            }
        }
    }

    private func computeMainCategoryDistribution(_ items: [StatsClothingItem]) -> [(String, Int)] {
        let grouped = Dictionary(grouping: items, by: { mainCategoryResolver($0.subcategory) })
        let allMain = ["قطع علوية", "قطع سفلية", "قطع كاملة", "أحذية", "إكسسوارات"]
        return allMain.map { main in (main, grouped[main]?.count ?? 0) }
            .sorted { $0.1 > $1.1 }
    }

    private func computeSubcategoryDistribution(for main: String) -> [(String, Int)] {
        let filtered = allItems.filter { mainCategoryResolver($0.subcategory) == main }
        let grouped = Dictionary(grouping: filtered, by: { $0.subcategory.trimmingCharacters(in: .whitespacesAndNewlines) })
            .mapValues { $0.count }

        let master = SUBCATEGORY_MASTER[main] ?? []
        var result: [(String, Int)] = []

        for sub in master { result.append((sub, grouped[sub] ?? 0)) }

        let extras = grouped.keys.filter { !master.contains($0) && !$0.isEmpty }
        for e in extras.sorted() { result.append((e, grouped[e] ?? 0)) }

        return result
    }
}

// MARK: - Interactive Donut Card (Category)
@available(iOS 16.0, *)
struct InteractiveCategoryCard: View {
    let items: [DonutSlice]
    @Binding var selected: String
    let colorMap: [String: Color]

    var body: some View {
        let total = max(items.reduce(0) { $0 + $1.value }, 1)

        VStack(spacing: 12) {
            Text("الفئات")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(SoftTheme.textSecondary)

            HStack(spacing: 50) {
                legendColumn(items: items)

                ZStack {
                    Chart(items) { item in
                        SectorMark(
                            angle: .value("Count", item.value),
                            innerRadius: .ratio(0.65),
                            angularInset: 2
                        )
                        .cornerRadius(6)
                        .foregroundStyle(colorMap[item.name] ?? Color.gray.opacity(0.3))
                        .opacity(selected.isEmpty || item.name == selected ? 1.0 : 0.55)
                    }
                    .chartLegend(.hidden)
                    .chartOverlay { _ in
                        GeometryReader { geo in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .onTapGesture { location in
                                    let picked = pickSlice(from: location, in: geo.size, items: items, total: total)
                                    if let picked { selected = picked }
                                }
                        }
                    }

                    VStack(spacing: 0) {
                        Text("\(total)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(SoftTheme.textPrimary)
                        Text("قطعة")
                            .font(.system(size: 10))
                            .foregroundStyle(SoftTheme.textSecondary)
                    }
                }
                .frame(width: 170, height: 170)
            }
            .environment(\.layoutDirection, .leftToRight)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(SoftTheme.cardWhite)
        .cornerRadius(SoftTheme.cornerRadius)
        .shadow(color: Color.black.opacity(0.1), radius: 14, x: 0, y: 10)
    }

    private func legendColumn(items: [DonutSlice]) -> some View {
        let total = max(items.reduce(0) { $0 + $1.value }, 1)

        return VStack(alignment: .leading, spacing: 14) {
            ForEach(items) { item in
                let percent = Int(round(Double(item.value) / Double(total) * 100))

                HStack(spacing: 10) {

                    // ✅ النص: "20٪ قطع علوية"
                    Text(" \(item.name) \(percent)٪")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(SoftTheme.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    Circle()
                        .fill(colorMap[item.name] ?? .gray)
                        .frame(width: 10, height: 10)
                        .frame(width: 14, alignment: .center)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
    }


    private func pickSlice(from location: CGPoint, in size: CGSize, items: [DonutSlice], total: Int) -> String? {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y

        var angle = atan2(dy, dx) * 180 / .pi
        if angle < 0 { angle += 360 }
        angle = (angle + 90).truncatingRemainder(dividingBy: 360)

        let target = angle / 360 * Double(total)
        var running = 0.0
        for it in items {
            running += Double(it.value)
            if target <= running { return it.name }
        }
        return nil
    }
}

// MARK: - Bar Chart
@available(iOS 16.0, *)
struct SubcategoryVerticalBarChart: View {
    let data: [(name: String, count: Int)]
    let barStyle: AnyShapeStyle

    var body: some View {
        Chart(data, id: \.name) { item in
            BarMark(
                x: .value("الفئة", item.name),
                y: .value("العدد", item.count),
                width: .fixed(12)
            )
            .foregroundStyle(barStyle)
            .cornerRadius(6)
            .annotation(position: .overlay) {
                GeometryReader { geo in
                    TopRoundedRect(radius: 6)
                        .stroke(Color.gray.opacity(0.45), lineWidth: 1)
                        .frame(
                            width: geo.size.width + 8,   // نفس التوسيع اللي سويتيه
                            height: geo.size.height + 8
                        )
                        .position(
                            x: geo.size.width / 2,
                            y: geo.size.height / 2
                        )
                }
            }


        }
        .frame(height: 220)

    }
}

// MARK: - ✅ Color Drilldown Sheet
@available(iOS 16.0, *)
struct ColorDrilldownSheet: View {
    let allItems: [StatsClothingItem]
    let mainCategoryResolver: (String) -> String

    @State private var selectedColor: String = ""
    private let mainCats = ["قطع علوية", "قطع سفلية", "قطع كاملة", "أحذية", "إكسسوارات"]

    var body: some View {
        let donutItems = computeColorDistributionStable(allItems)

        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {

                Text("تفاصيل الألوان")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(SoftTheme.textPrimary)
                    .padding(.top, 28)

                InteractiveColorCardStable(items: donutItems, selected: $selectedColor)
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 12) {

                    Text(selectedColor.isEmpty ? "اختر لون" : selectedColor)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(SoftTheme.textPrimary)

                    let chartData = computeMainCategoryForColor(selectedColor).filter { $0.1 > 0 }

                    if selectedColor.isEmpty {
                        Text("اضغط على لون في الدونت لعرض التفاصيل.")
                            .font(.system(size: 12))
                            .foregroundStyle(SoftTheme.textSecondary)
                    } else if chartData.isEmpty {
                        Text("لا توجد عناصر بهذا اللون ضمن الفئات الرئيسية.")
                            .font(.system(size: 12))
                            .foregroundStyle(SoftTheme.textSecondary)
                    } else {
                        SubcategoryVerticalBarChart(
                            data: chartData,
                            barStyle: AnyShapeStyle(colorForName(selectedColor).opacity(0.65))
                        )
                        .frame(maxWidth: 320)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(16)
                .background(SoftTheme.cardWhite)
                .cornerRadius(SoftTheme.cornerRadius)
                .shadow(color: Color.black.opacity(0.1), radius: 14, x: 0, y: 10)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

                Spacer(minLength: 16)
            }
        }
        .background(SoftTheme.background)
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            if selectedColor.isEmpty {
                selectedColor = donutItems.first?.name ?? ""
            }
        }
    }

    private func computeColorDistributionStable(_ items: [StatsClothingItem]) -> [DonutSlice] {
        let grouped = Dictionary(grouping: items) { $0.color.isEmpty ? "غير محدد" : $0.color }
            .mapValues { $0.count }

        var arr = grouped.map { DonutSlice(name: $0.key, value: $0.value) }
        arr.sort {
            if $0.value != $1.value { return $0.value > $1.value }
            return $0.name < $1.name
        }
        return arr
    }

    private func computeMainCategoryForColor(_ color: String) -> [(String, Int)] {
        guard !color.isEmpty else { return [] }
        let filtered = allItems.filter { ($0.color.isEmpty ? "غير محدد" : $0.color) == color }
        let grouped = Dictionary(grouping: filtered, by: { mainCategoryResolver($0.subcategory) })
        return mainCats.map { ($0, grouped[$0]?.count ?? 0) }
    }

    private func colorForName(_ name: String) -> Color {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        switch n {
        case "أسود": return .black
        case "أبيض": return .white
        case "أحمر": return SoftTheme.pastelRed
        case "أزرق": return Color.blue.opacity(0.6)
        case "أخضر": return SoftTheme.pastelGreen
        case "أصفر": return Color.yellow.opacity(0.6)
        case "بيج": return Color(red: 0.95, green: 0.9, blue: 0.8)
        case "رمادي": return .gray.opacity(0.6)
        case "بني": return .brown.opacity(0.6)
        case "وردي": return .pink.opacity(0.6)
        case "بنفسجي": return SoftTheme.pastelPurple
        case "برتقالي": return SoftTheme.pastelOrange
        case "ذهبي": return Color(red: 0.93, green: 0.84, blue: 0.45)
        default: return SoftTheme.pastelGreen.opacity(0.5)
        }
    }
}

// MARK: - ✅ Pattern Drilldown Sheet
@available(iOS 16.0, *)
struct PatternDrilldownSheet: View {
    let allItems: [StatsClothingItem]
    let mainCategoryResolver: (String) -> String

    @State private var selectedPattern: String = ""
    private let mainCats = ["قطع علوية", "قطع سفلية", "قطع كاملة", "أحذية", "إكسسوارات"]

    var body: some View {
        let donutItems = computePatternDistributionStable(allItems)

        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {

                Text("تفاصيل النقشات")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(SoftTheme.textPrimary)
                    .padding(.top, 28)

                InteractivePatternCardStable(items: donutItems, selected: $selectedPattern)
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 12) {

                    Text(selectedPattern.isEmpty ? "اختر نقش" : selectedPattern)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(SoftTheme.textPrimary)

                    let chartData = computeMainCategoryForPattern(selectedPattern).filter { $0.1 > 0 }

                    if selectedPattern.isEmpty {
                        Text("اضغط على نقش في الدونت لعرض التفاصيل.")
                            .font(.system(size: 12))
                            .foregroundStyle(SoftTheme.textSecondary)
                    } else if chartData.isEmpty {
                        Text("لا توجد عناصر بهذه النقشة ضمن الفئات الرئيسية.")
                            .font(.system(size: 12))
                            .foregroundStyle(SoftTheme.textSecondary)
                    } else {
                        SubcategoryVerticalBarChart(
                            data: chartData,
                            barStyle: patternShapeStyle(for: selectedPattern)
                        )
                        .frame(maxWidth: 320)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(16)
                .background(SoftTheme.cardWhite)
                .cornerRadius(SoftTheme.cornerRadius)
                .shadow(color: Color.black.opacity(0.1), radius: 14, x: 0, y: 10)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

                Spacer(minLength: 16)
            }
        }
        .background(SoftTheme.background)
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            if selectedPattern.isEmpty {
                selectedPattern = donutItems.first?.name ?? ""
            }
        }
    }

    private func computePatternDistributionStable(_ items: [StatsClothingItem]) -> [DonutSlice] {
        let grouped = Dictionary(grouping: items) { $0.pattern.isEmpty ? "سادة" : $0.pattern }
            .mapValues { $0.count }

        var arr = grouped.map { DonutSlice(name: $0.key, value: $0.value) }
        arr.sort {
            if $0.value != $1.value { return $0.value > $1.value }
            return $0.name < $1.name
        }
        return arr
    }

    private func computeMainCategoryForPattern(_ pattern: String) -> [(String, Int)] {
        guard !pattern.isEmpty else { return [] }
        let filtered = allItems.filter { ($0.pattern.isEmpty ? "سادة" : $0.pattern) == pattern }
        let grouped = Dictionary(grouping: filtered, by: { mainCategoryResolver($0.subcategory) })
        return mainCats.map { ($0, grouped[$0]?.count ?? 0) }
    }
}

@available(iOS 16.0, *)
struct InteractiveColorCardStable: View {
    let items: [DonutSlice]
    @Binding var selected: String

    var body: some View {
        let total = max(items.reduce(0) { $0 + $1.value }, 1)

        VStack(spacing: 12) {
            Text("الألوان")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(SoftTheme.textSecondary)

            HStack(spacing: 60) {

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(items) { item in
                        HStack(spacing: 10) {
                            let pct = Int(round(Double(item.value) / Double(total) * 100))

                            Text("\(item.name) \(pct)% ")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(SoftTheme.textPrimary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .trailing)


                            Circle()
                                .fill(colorForName(item.name))
                                .frame(width: 10, height: 10)
                                .frame(width: 14, alignment: .center)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)

                ZStack {
                    Chart(items) { item in
                        SectorMark(
                            angle: .value("Count", item.value),
                            innerRadius: .ratio(0.65),
                            outerRadius: .ratio(1.0),
                            angularInset: 2.0
                        )
                        .cornerRadius(6)
                        .foregroundStyle(Color.gray.opacity(0.5))
                    }
                    .chartLegend(.hidden)
                    .allowsHitTesting(false)   // ✅

                    Chart(items) { item in
                        SectorMark(
                            angle: .value("Count", item.value),
                            innerRadius: .ratio(0.66),
                            outerRadius: .ratio(0.99),
                            angularInset: 2.8
                        )
                        .cornerRadius(5)
                        .foregroundStyle(colorForName(item.name))
                    }
                    .chartLegend(.hidden)
                    .allowsHitTesting(false)   // ✅ (مهم)

                    VStack(spacing: 0) {
                        Text("\(total)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Text("قطعة")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .allowsHitTesting(false)
                }
                .frame(width: 170, height: 170)
                .contentShape(Rectangle())    // ✅ عشان يمسك كامل المساحة
                .overlay {
                    GeometryReader { geo in
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                let picked = pickSlice(from: location, in: geo.size, items: items, total: total)
                                if let picked { selected = picked }
                            }
                    }
                }




            }
            .environment(\.layoutDirection, .leftToRight)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(SoftTheme.cardWhite)
        .cornerRadius(SoftTheme.cornerRadius)
        .shadow(color: Color.black.opacity(0.1), radius: 14, x: 0, y: 10)
        .onAppear {
            if selected.isEmpty {
                selected = items.first?.name ?? ""
            }
        }
    }

    private func colorForName(_ name: String) -> Color {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        switch n {
        case "أسود": return .black
        case "أبيض": return .white
        case "أحمر": return SoftTheme.pastelRed
        case "أزرق": return Color.blue.opacity(0.6)
        case "أخضر": return SoftTheme.pastelGreen
        case "أصفر": return Color.yellow.opacity(0.6)
        case "بيج": return Color(red: 0.95, green: 0.9, blue: 0.8)
        case "رمادي": return .gray.opacity(0.6)
        case "بني": return .brown.opacity(0.6)
        case "وردي": return .pink.opacity(0.6)
        case "بنفسجي": return SoftTheme.pastelPurple
        case "برتقالي": return SoftTheme.pastelOrange
        default: return SoftTheme.pastelGreen.opacity(0.5)
        }
    }

    private func pickSlice(from location: CGPoint, in size: CGSize, items: [DonutSlice], total: Int) -> String? {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y

        var angle = atan2(dy, dx) * 180 / .pi
        if angle < 0 { angle += 360 }
        angle = (angle + 90).truncatingRemainder(dividingBy: 360)

        let target = angle / 360 * Double(total)
        var running = 0.0
        for it in items {
            running += Double(it.value)
            if target <= running { return it.name }
        }
        return nil
    }
}

@available(iOS 16.0, *)
struct InteractivePatternCardStable: View {
    let items: [DonutSlice]
    @Binding var selected: String

    var body: some View {
        let total = max(items.reduce(0) { $0 + $1.value }, 1)

        VStack(spacing: 12) {
            Text("النقشات")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(SoftTheme.textSecondary)

            HStack(spacing: 40) {

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(items) { item in
                        HStack(spacing: 10) {
                            let pct = Int(round(Double(item.value) / Double(total) * 100))

                            Text(" \(item.name) \(pct)%")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(SoftTheme.textPrimary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .trailing)

                            Circle()
                                .fill(patternShapeStyle(for: item.name))
                                .frame(width: 10, height: 10)
                                .frame(width: 14, alignment: .center)
                                .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 0.7))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)

                ZStack {
                    Chart(items) { item in
                        SectorMark(
                            angle: .value("Count", item.value),
                            innerRadius: .ratio(0.65),
                            angularInset: 2
                        )
                        .cornerRadius(6)
                        .foregroundStyle(patternShapeStyle(for: item.name))
                        .opacity(selected.isEmpty || item.name == selected ? 1.0 : 0.55)
                    }
                    .chartLegend(.hidden)
                    .chartOverlay { _ in
                        GeometryReader { geo in
                            Rectangle().fill(.clear).contentShape(Rectangle())
                                .onTapGesture { location in
                                    let picked = pickSlice(from: location, in: geo.size, items: items, total: total)
                                    if let picked { selected = picked }
                                }
                        }
                    }

                    VStack(spacing: 0) {
                        Text("\(total)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(SoftTheme.textPrimary)
                        Text("قطعة")
                            .font(.system(size: 10))
                            .foregroundStyle(SoftTheme.textSecondary)
                    }
                }
                .frame(width: 170, height: 170)
            }
            .environment(\.layoutDirection, .leftToRight)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(SoftTheme.cardWhite)
        .cornerRadius(SoftTheme.cornerRadius)
        .shadow(color: Color.black.opacity(0.1), radius: 14, x: 0, y: 10)
        .onAppear {
            if selected.isEmpty {
                selected = items.first?.name ?? ""
            }
        }
    }

    private func pickSlice(from location: CGPoint, in size: CGSize, items: [DonutSlice], total: Int) -> String? {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y

        var angle = atan2(dy, dx) * 180 / .pi
        if angle < 0 { angle += 360 }
        angle = (angle + 90).truncatingRemainder(dividingBy: 360)

        let target = angle / 360 * Double(total)
        var running = 0.0
        for it in items {
            running += Double(it.value)
            if target <= running { return it.name }
        }
        return nil
    }
}

// MARK: - Models
struct StatsClothingItem: Identifiable {
    let id: String
    let subcategory: String
    let color: String
    let pattern: String
    let imageUrl: String?
    let wearingCount: Int
    let epc: String?
    let createdAt: Date?
    let lastWearingDate: Date?

    // ✅ الجديد
    let isOutside: Bool

    var hasTag: Bool { !(epc?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) }

    static func from(doc: QueryDocumentSnapshot) -> StatsClothingItem? {
        let data = doc.data()
        let analysis = data["analysis"] as? [String: Any]
        let image = data["image"] as? [String: Any]
        let meta = data["meta"] as? [String: Any]

        let lastWearing = (data["lastWearingDate"] as? Timestamp)?.dateValue()
        ?? (meta?["lastWearingDate"] as? Timestamp)?.dateValue()

        let wearingCount: Int = {
            let raw = meta?["wearingCount"] ?? data["wearingCount"]
            if let i = raw as? Int { return i }
            if let n = raw as? NSNumber { return n.intValue }
            if let i64 = raw as? Int64 { return Int(i64) }
            if let d = raw as? Double { return Int(d) }
            if let s = raw as? String { return Int(s) ?? 0 }
            return 0
        }()

        // ✅ قراءة isOutside (يدعم وجوده في meta أو root)
        let isOutside: Bool = {
            let raw = meta?["isOutside"] ?? data["isOutside"]
            if let b = raw as? Bool { return b }
            if let n = raw as? NSNumber { return n.boolValue }
            if let s = raw as? String {
                let lower = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if lower == "true" || lower == "1" { return true }
                if lower == "false" || lower == "0" { return false }
            }
            return false
        }()

        return StatsClothingItem(
            id: doc.documentID,
            subcategory: (analysis?["category"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            color: (analysis?["color"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            pattern: (analysis?["pattern"] as? String ?? "سادة").trimmingCharacters(in: .whitespacesAndNewlines),
            imageUrl: image?["originalUrl"] as? String,
            wearingCount: wearingCount,
            epc: meta?["epc"] as? String,
            createdAt: (meta?["createdAt"] as? Timestamp)?.dateValue(),
            lastWearingDate: lastWearing,
            isOutside: isOutside
        )
    }
}

struct DonutSlice: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let value: Int
}

// MARK: - Neglected List
struct AllNeglectedList: View {
    let items: [StatsClothingItem]

    var body: some View {
        NavigationStack {
            List(items) { item in
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(SoftTheme.background)
                        if let urlString = item.imageUrl, let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                phase.image?.resizable().scaledToFit().padding(4)
                            }
                        }
                    }
                    .frame(width: 60, height: 60)

                    VStack(alignment: .leading) {
                        Text(item.subcategory.isEmpty ? "قطعة" : item.subcategory).font(.headline)
                        Text("مرات اللبس: \(item.wearingCount)")
                            .font(.subheadline)
                            .foregroundStyle(SoftTheme.textSecondary)
                    }
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("القطع المهملة")
            .background(SoftTheme.background)
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
}


struct TopRoundedRect: Shape {
    var radius: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let r = min(radius, rect.width / 2)

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))                 // أسفل يسار
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))          // يسار للأعلى

        // قوس أعلى يسار
        path.addArc(
            center: CGPoint(x: rect.minX + r, y: rect.minY + r),
            radius: r,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )

        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))           // أعلى مستقيم

        // قوس أعلى يمين
        path.addArc(
            center: CGPoint(x: rect.maxX - r, y: rect.minY + r),
            radius: r,
            startAngle: .degrees(270),
            endAngle: .degrees(0),
            clockwise: false
        )

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))               // يمين للأسفل
        path.closeSubpath()

        return path
    }
}
