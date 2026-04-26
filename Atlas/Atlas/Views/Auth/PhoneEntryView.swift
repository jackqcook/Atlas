import SwiftUI

private let crimson = Color(red: 0.863, green: 0.078, blue: 0.235)

struct PhoneEntryView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var phone = ""
    @FocusState private var focused: Bool

    private var isOTPPresented: Binding<Bool> {
        Binding(
            get: {
                if case .otpVerification = authVM.phase { return true }
                return false
            },
            set: { if !$0 { authVM.phase = .phoneEntry } }
        )
    }

    var body: some View {
        ZStack {
            crimson.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.15))
                            .frame(width: 96, height: 96)
                        Image(systemName: "globe.americas.fill")
                            .font(.system(size: 48, weight: .medium))
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: 4) {
                        Text("ATLAS")
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .tracking(6)
                        Text("Trusted circles. Private channels.")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
                .padding(.bottom, 64)

                // Phone input card
                VStack(spacing: 12) {
                    HStack(spacing: 0) {
                        Text("+1")
                            .foregroundStyle(.white.opacity(0.7))
                            .font(.system(size: 16, weight: .medium))
                            .padding(.horizontal, 16)
                            .frame(height: 54)
                            .background(.white.opacity(0.12))
                        Rectangle()
                            .fill(.white.opacity(0.25))
                            .frame(width: 1, height: 28)
                        TextField("(555) 555-5555", text: $phone)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .focused($focused)
                            .onChange(of: phone) { _, new in phone = formatted(new) }
                            .padding(.horizontal, 16)
                            .frame(height: 54)
                            .foregroundStyle(.white)
                            .tint(.white)
                    }
                    .background(.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                    }

                    if let error = authVM.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }

                    Button {
                        Task { await authVM.sendOTP(phone: phone) }
                    } label: {
                        SwiftUI.Group {
                            if authVM.isLoading {
                                ProgressView().tint(crimson)
                            } else {
                                Text("Continue")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(isValid ? crimson : .white.opacity(0.4))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(isValid ? .white : .white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!isValid || authVM.isLoading)
                    .animation(.easeInOut(duration: 0.15), value: isValid)

                    Button {
                        Task { await authVM.continueInDemoMode() }
                    } label: {
                        Text("Continue in Demo Mode")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(.white.opacity(0.24), lineWidth: 1)
                            }
                    }
                    .disabled(authVM.isLoading)
                }
                .padding(.horizontal, 28)

                Spacer()
                Spacer()

                Text("By continuing you agree to our Terms & Privacy Policy.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 20)
            }
        }
        .onAppear { focused = true }
        .fullScreenCover(isPresented: isOTPPresented) {
            OTPVerificationView()
                .environment(authVM)
        }
    }

    private var isValid: Bool {
        phone.filter { $0.isNumber }.count == 10
    }

    private func formatted(_ raw: String) -> String {
        let digits = raw.filter { $0.isNumber }
        guard !digits.isEmpty else { return "" }
        var result = ""
        for (i, d) in digits.prefix(10).enumerated() {
            if i == 0 { result += "(" }
            if i == 3 { result += ") " }
            if i == 6 { result += "-" }
            result.append(d)
        }
        return result
    }
}
