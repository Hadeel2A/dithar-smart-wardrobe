import SwiftUI

struct AvatarView: View {
    let displayName: String
    let urlString: String?
    var size: CGFloat = 56

    private var initials: String {
        let parts = displayName.split(separator: " ")
        let f = parts.first?.first.map(String.init) ?? ""
        let l = parts.dropFirst().first?.first.map(String.init) ?? ""
        let s = (f + l)
        return s.isEmpty ? "?" : s
    }

    var body: some View {
        ZStack {
            if let u = urlString, let url = URL(string: u) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    case .empty: ProgressView().scaleEffect(0.8)
                    default: placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .background(Color.gray.opacity(0.12))
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    private var placeholder: some View {
        Text(initials)
            .font(.system(size: size * 0.36, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.47, green: 0.58, blue: 0.44))
            .clipShape(Circle())
    }
}
