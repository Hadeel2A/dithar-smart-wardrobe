//
//  WardrobeRFIDLinkingView.swift
//  DitharApp
//
//  Created by Fatmah Alsufaian on 29/04/1447 AH.
//

import SwiftUI
import AVKit
import FirebaseFirestore

// MARK: - حالة المسح
fileprivate enum RFIDScanState {
    case idle        // بداية: رمادي "انتظار المسح"
    case waiting     // بعد الضغط: برتقالي "جاهز لربط المعرف"
    case capturing   // أثناء الالتقاط: برتقالي "جاري المسح…"
    case done        // نجاح: أخضر "تم ربط المعرف"
    case timeout     // فشل: أحمر "فشل ربط المعرف"

    var dotColor: Color {
        switch self {
        case .idle: return .gray.opacity(0.6)
        case .waiting, .capturing: return .orange
        case .done: return .green
        case .timeout: return .red
        }
    }
    
    var label: String {
        switch self {
        case .idle: return "انتظار المسح"
        case .waiting: return "جاهز لربط المعرف"
        case .capturing: return "جاري المسح…"
        case .done: return "تم ربط المعرف"
        case .timeout: return "فشل ربط المعرف"
        }
    }
}

// MARK: - نموذج بيانات القطعة الموجودة (للخزانة)
struct ExistingClothingItemWardrobe {
    var docId: String
    var imageUrl: String
    var category: String
    var epc: String
}

// MARK: - شاشة ربط RFID من الخزانة
struct WardrobeRFIDLinkingView: View {
    let itemId: String
    let itemCategory: String
    @Binding var isLinked: Bool
    @Binding var linkedEPC: String
    @Environment(\.presentationMode) var presentationMode
    
    @State private var scanState: RFIDScanState = .idle
    @State private var isScanning = false
    @State private var scanSuccess = false
    @State private var listener: ListenerRegistration? = nil
    
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
    @State private var isPlaying = false
    @State private var showFullscreenVideo = false
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    Spacer().frame(height: 40)
                    
                    // MARK: - بطاقة الفيديو
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
                                        }, alignment: .center
                                    )
                                    .overlay(
                                        Button(action: { showFullscreenVideo = true }) {
                                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.white)
                                                .padding(10)
                                                .background(Color.black.opacity(0.35))
                                                .clipShape(Circle())
                                        }
                                        .padding(10),
                                        alignment: .topLeading
                                    )
                                    .onTapGesture {
                                        if isPlaying { p.pause() } else { p.play() }
                                        isPlaying.toggle()
                                    }
                                    .onDisappear {
                                        p.pause()
                                        isPlaying = false
                                    }
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.black.opacity(0.06))
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 44))
                                        .foregroundColor(Color(red: 0.47, green: 0.58, blue: 0.44))
                                }
                                .frame(height: 180)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        Text("قرّب المعرّف من القارئ لربطه بالقطعة.")
                            .font(.system(size: 13))
                            .foregroundColor(.gray.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 20)
                    .background(Color(red: 0.96, green: 0.96, blue: 0.96))
                    .cornerRadius(16)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    
                    // MARK: - مربع الحالة
                    HStack(spacing: 12) {
                        Spacer()
                        Text(scanState.label)
                        .accessibilityLabel("حالة المسح: \(scanState.label)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)
                        Circle()
                            .fill(scanState.dotColor)
                            .frame(width: 10, height: 10)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .background(Color(red: 0.96, green: 0.96, blue: 0.96))
                    .cornerRadius(10)
                    .padding(.horizontal, 24)
                    
                    Spacer().frame(height: 20)
                    
                    Image(systemName: "wifi")
                        .font(.system(size: 60))
                        .foregroundColor(Color(red: 0.47, green: 0.58, blue: 0.44))
                        .padding(.vertical, 30)
                    
                    Spacer()
                    
                    // MARK: - الأزرار
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
                .accessibilityLabel(isScanning ? "جاري المسح" : "بدء مسح المعرف")
                        
                        Button(action: {
                            listener?.remove()
                            listener = nil
                            presentationMode.wrappedValue.dismiss()
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
                    .padding(.bottom, 30)
                }
                .onDisappear {
                    listener?.remove()
                    listener = nil
                    demoPlayer?.pause()
                    isPlaying = false
                }
                .onAppear {
                    listener?.remove()
                    listener = nil
                    isScanning = false
                    scanSuccess = false
                    scanState = .idle
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
                        
                        Text("المعرف مرتبط بقطعة أخرى")
                            .font(.system(size: 18, weight: .bold))
                            .multilineTextAlignment(.center)
                        
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
                                case .failure(_):
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 200, height: 200)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .font(.system(size: 40))
                                                .foregroundColor(.gray)
                                        )
                                case .empty:
                                    ProgressView()
                                        .frame(width: 200, height: 200)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                        
                        VStack(spacing: 12) {
                            Button(action: confirmReplacement) {
                                Text("تأكيد الاستبدال")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color(red: 0.47, green: 0.58, blue: 0.44))
                                    .cornerRadius(12)
                            }
                            
                            Button(action: cancelReplacement) {
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
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(action: {
                    listener?.remove()
                    listener = nil
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "arrow.right")
                        .foregroundColor(.black)
                }
            )
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ربط المعرف")
                        .font(.system(size: 18, weight: .semibold))
                }
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
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
    
    // MARK: - Actions
    private func onPrimaryTapped() {
        if scanSuccess {
            presentationMode.wrappedValue.dismiss()
            return
        }
        
        demoPlayer?.pause()
        demoPlayer?.seek(to: .zero)
        isPlaying = false
        
        guard !itemId.isEmpty else { return }
        
        isScanning = true
        scanState = .waiting
        
        listener = startWardrobeEnrollmentRequest(
            clotheId: itemId,
            userName: "hadeel"
        ) { status, epc in
            switch status {
            case "capturing":
                scanState = .capturing
                
            case "done":
                if let epc = epc, !epc.isEmpty {
                    pendingEPC = epc
                    checkExistingRFIDTag(epc: epc, currentClotheId: itemId) { existing in
                        if let existing = existing {
                            self.existingItem = existing
                            self.showReplacementAlert = true
                            self.isScanning = false
                            self.scanSuccess = false
                            self.scanState = .waiting
                            self.listener?.remove()
                            self.listener = nil
                        } else {
                            self.completeRFIDLink(epc: epc)
                        }
                    }
                } else {
                    isScanning = false
                    scanSuccess = false
                    scanState = .timeout
                    listener?.remove()
                    listener = nil
                }
                
            case "timeout":
                isScanning = false
                scanSuccess = false
                scanState = .timeout
                listener?.remove()
                listener = nil
                
            default:
                break
            }
        }
    }
    
    private func completeRFIDLink(epc: String) {
        isScanning = false
        scanSuccess = true
        scanState = .done
        isLinked = true
        linkedEPC = epc
        
        // تحديث Firestore
        let db = Firestore.firestore()
        db.collection("Clothes").document(itemId).setData([
            "meta": ["epc": epc]
        ], merge: true) { error in
            if let error = error {
                print("❌ خطأ في تحديث RFID:", error.localizedDescription)
            } else {
                print("✅ تم ربط RFID بنجاح")
            }
        }
        
        listener?.remove()
        listener = nil
    }
    
    private func confirmReplacement() {
        guard !pendingEPC.isEmpty else { return }
        moveRFIDToCurrentItem(epc: pendingEPC, keepClotheId: itemId) { _ in
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
    }
}

// MARK: - دوال مساعدة لربط RFID
fileprivate func startWardrobeEnrollmentRequest(
    clotheId: String,
    userName: String,
    onStatus: @escaping (_ status: String, _ epc: String?) -> Void
) -> ListenerRegistration {
    let db = Firestore.firestore()
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
        let epc = data["epc"] as? String
        onStatus(status, epc)
    }
}

fileprivate func checkExistingRFIDTag(
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

fileprivate func moveRFIDToCurrentItem(
    epc: String,
    keepClotheId: String,
    completion: @escaping (Bool) -> Void
) {
    let db = Firestore.firestore()
    db.collection("Clothes")
        .whereField("meta.epc", isEqualTo: epc)
        .getDocuments { snap, err in
            guard err == nil else { completion(false); return }
            
            let batch = db.batch()
            let docs = snap?.documents ?? []
            for d in docs where d.documentID != keepClotheId {
                batch.setData(
                    ["meta": ["epc": NSNull()]],
                    forDocument: d.reference,
                    merge: true
                )
            }
            
            batch.commit { e in
                completion(e == nil)
            }
        }
}

// MARK: - Preview
struct WardrobeRFIDLinkingView_Previews: PreviewProvider {
    static var previews: some View {
        WardrobeRFIDLinkingView(
            itemId: "test123",
            itemCategory: "قميص",
            isLinked: .constant(false),
            linkedEPC: .constant("")
        )
        .environment(\.layoutDirection, .rightToLeft)
    }
}
