//
//  AdvancedFilterView.swift
//  DitharApp
//
//  Created by Rahaf AlFantoukh on 28/04/1447 AH.
//

import SwiftUI

struct AdvancedFilterView: View {
    @Environment(\.presentationMode) var presentationMode

    @Binding var selectedCategory: String
    @Binding var selectedSubcategory: String?
    @Binding var selectedColor: String?
    @Binding var selectedPattern: String?   // تأكدي أنه موجود عندك

    var onApply: (() -> Void)? = nil

    // الفئات الرئيسية
    private let mainCategories: [(title: String, icon: String?, imageName: String?)] = [
        ("الكل",       "square.grid.2x2", nil),
        ("قطع علوية",  "tshirt.fill",     nil),
        ("قطع سفلية",  nil,               "PantsIcon"),
        ("أحذية",      "shoe",            nil),
        ("إكسسوارات",  "bag",             nil),
        ("قطع كاملة",  "tshirt.fill",     nil)
    ]

    // الفئات الفرعية
    private let subcategoryMapping: [String: [String]] = [
        "قطع علوية": ["قميص", "بلوزة", "كنزة", "معطف", "تيشيرت"],
        "قطع سفلية": ["بنطال", "تنورة", "شورت"],
        "قطع كاملة": ["فستان", "شيال", "ثوب", "عباية"],
        "أحذية":     ["حذاء رياضي", "حذاء رسمي", "صندل", "كعب", "بوت"],
        "إكسسوارات": ["سلسال", "اسورة", "حلق", "خاتم", "ساعة", "نظارة", "حقيبة", "حزام", "قبعة", "وشاح"]
    ]

    // الألوان
    let basicColors: [(String, Color)] = [
        ("أبيض", .white), ("أسود", .black), ("رمادي", .gray), ("بني", .brown),
        ("بيج", Color(red: 0.96, green: 0.96, blue: 0.86)),
        ("أحمر", .red), ("وردي", .pink), ("بنفسجي", .purple),
        ("برتقالي", .orange), ("أصفر", .yellow), ("أخضر", .green),
        ("سماوي", .cyan), ("أزرق", .blue),
        ("ذهبي", Color(red: 1.0, green: 0.84, blue: 0.0)),
        ("فضي", Color(red: 0.75, green: 0.75, blue: 0.75))
    ]

    // النقشات
    private let patterns: [String] = [
        "سادة", "مخطط", "منقط", "مربعات", "ورود", "دانتيـل", "أشكال هندسية", "كاروهات"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding()

                Text("خيارات التصفية")
                    .font(.title2).bold()
                    .padding(.bottom, 20)

                // MARK: - عنوان الفئة ✅ جديد
                Text("الفئة")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal)

                Spacer().frame(height: 10)
                
                // MARK: - فئات رئيسية (دوائر)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(mainCategories, id: \.title) { item in
                            CategoryButton(
                                icon: item.icon,
                                imageName: item.imageName,
                                title: item.title,
                                isSelected: selectedCategory == item.title
                            ) {
                                selectedCategory = item.title
                                // عند تغيير الفئة الرئيسية، صفّر الفئة الفرعية
                                selectedSubcategory = nil
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .environment(\.layoutDirection, .rightToLeft)
                .padding(.bottom, 12)

                // MARK: - فئات فرعية (chips) تظهر فقط عند اختيار فئة غير "الكل"
                // MARK: - فئات فرعية (رول أفقي) تظهر فقط عند اختيار فئة غير "الكل"
                if let subs = subcategoryMapping[selectedCategory], !subs.isEmpty {
                    VStack(alignment: .trailing, spacing: 8) {
                        // (اختياري) عنوان صغير فوق الشيبس
                        // Text("الفئة التفصيلية")
                        //     .font(.subheadline)
                        //     .frame(maxWidth: .infinity, alignment: .trailing)
                        //     .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                // "الكل" لهذه الفئة
                                SubChip(title: "الكل", isSelected: selectedSubcategory == nil) {
                                    selectedSubcategory = nil
                                }
                                // بقية الأنواع
                                ForEach(subs, id: \.self) { sub in
                                    SubChip(title: sub, isSelected: selectedSubcategory == sub) {
                                        selectedSubcategory = (selectedSubcategory == sub ? nil : sub)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 2)
                        }
                        .environment(\.layoutDirection, .rightToLeft)  // ✅
                    }
                    .padding(.bottom, 12)
                }

                Spacer().frame(height: 25)

                // MARK: - اللون
                VStack(alignment: .trailing, spacing: 8) {
                    Text("اللون")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal)

                    Spacer().frame(height: 10)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // كل الألوان
                            Button {
                                selectedColor = nil
                            } label: {
                                Circle()
                                    .strokeBorder(selectedColor == nil ? Color.black : Color.gray.opacity(0.3), lineWidth: 2)
                                    .background(
                                        Circle().fill(
                                            LinearGradient(
                                                colors: [.red, .orange, .yellow, .green, .blue, .purple],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                    )
                                    .frame(width: 40, height: 40)
                            }

                            ForEach(basicColors, id: \.0) { colorName, color in
                                Button {
                                    selectedColor = colorName
                                } label: {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(
                                                    selectedColor == colorName ? Color.black : Color.gray.opacity(0.2),
                                                    lineWidth: 2
                                                )
                                        )
                                        .overlay(
                                            selectedColor == colorName
                                            ? Image(systemName: "checkmark")
                                                .foregroundColor(.white)
                                                .font(.system(size: 16, weight: .bold))
                                            : nil
                                        )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .environment(\.layoutDirection, .rightToLeft)   // ✅
                }
                
                Spacer().frame(height: 25)

                // MARK: - النقشة (سطر أفقي) ✅ تم تحويلها لرول
                VStack(alignment: .trailing, spacing: 8) {
                    Text("النقشة")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal)

                    Spacer().frame(height: 10)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            // "الكل" للنقشة
                            SubChip(title: "الكل", isSelected: selectedPattern == nil) {
                                selectedPattern = nil
                            }
                            ForEach(patterns, id: \.self) { p in
                                SubChip(title: p, isSelected: selectedPattern == p) {
                                    selectedPattern = (selectedPattern == p ? nil : p)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 2)
                    }
                    .environment(\.layoutDirection, .rightToLeft)   // ✅
                }
                .padding(.top, 12)

                Spacer()

                // أزرار أسفل
                HStack(spacing: 12) {
                    Button {
                        onApply?()
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Text("تصفية")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 0.47, green: 0.58, blue: 0.44))
                            .cornerRadius(10)
                    }

                    Button {
                        // مسح التحديدات
                        selectedCategory = "الكل"
                        selectedSubcategory = nil
                        selectedColor = nil
                        selectedPattern = nil
                    } label: {
                        Text("مسح")
                            .font(.headline)
                            .foregroundColor(Color(red: 0.47, green: 0.58, blue: 0.44))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 0.47, green: 0.58, blue: 0.44).opacity(0.15))
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }
}

// MARK: - عنصر chip للفئات الفرعية
private struct SubChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected
                            ? Color(red: 0.47, green: 0.58, blue: 0.44).opacity(0.15)
                            : Color(red: 0.93, green: 0.93, blue: 0.93))
                .foregroundColor(isSelected
                                 ? Color(red: 0.47, green: 0.58, blue: 0.44)
                                 : .gray)
                .cornerRadius(18)
        }
        .buttonStyle(.plain)
    }
}
