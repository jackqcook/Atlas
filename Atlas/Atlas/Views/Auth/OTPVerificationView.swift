import SwiftUI

private let crimson = Color(red: 0.863, green: 0.078, blue: 0.235)

struct OTPVerificationView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var code = ""
    @FocusState private var focused: Bool

    private var phone: String {
        if case .otpVerification(let p) = authVM.phase { return p }
        return ""
    }

    var body: some View {
        ZStack {
            crimson.ignoresSafeArea()

            VStack(spacing: 0) {
                // Back button
                HStack {
                    Button {
                        authVM.phase = .phoneEntry
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                VStack(spacing: 8) {
                    Text("Check your messages")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Enter the 6-digit code sent to \(phone).")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 40)

                VStack(spacing: 12) {
                    TextField("000000", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .font(.system(size: 36, weight: .semibold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .focused($focused)
                        .onChange(of: code) { _, new in
                            code = String(new.filter { $0.isNumber }.prefix(6))
                            if code.count == 6 {
                                Task { await authVM.verifyOTP(code: code) }
                            }
                        }
                        .foregroundStyle(.white)
                        .tint(.white)
                        .frame(height: 54)
                        .background(.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                        }
                        .padding(.horizontal, 28)

                    if let error = authVM.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }

                    if authVM.isLoading {
                        ProgressView()
                            .tint(.white)
                            .padding(.top, 8)
                    }
                }

                Spacer()
                Spacer()
            }
        }
        .onAppear { focused = true }
    }
}
