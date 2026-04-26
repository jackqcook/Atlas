import SwiftUI

struct OTPVerificationView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var code = ""
    @FocusState private var focused: Bool

    private var phone: String {
        if case .otpVerification(let p) = authVM.phase { return p }
        return ""
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    authVM.phase = .phoneEntry
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("Check your messages")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Enter the 6-digit code sent to \(phone).")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)

            VStack(spacing: 12) {
                TextField("000000", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.system(size: 32, weight: .semibold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .focused($focused)
                    .onChange(of: code) { _, new in
                        code = String(new.filter { $0.isNumber }.prefix(6))
                        if code.count == 6 {
                            Task { await authVM.verifyOTP(code: code) }
                        }
                    }
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if let error = authVM.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                if authVM.isLoading {
                    ProgressView()
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
        .onAppear { focused = true }
    }
}
