import SwiftUI

struct PhoneEntryView: View {
    @EnvironmentObject var authVM: AuthViewModel
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
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("Atlas")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                Text("Enter your phone number\nto continue.")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 48)

            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    Text("+1")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color(.tertiarySystemBackground))
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(width: 1, height: 28)
                    TextField("(555) 555-5555", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .focused($focused)
                        .onChange(of: phone) { _, new in
                            phone = formatted(new)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                if let error = authVM.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }

                Button {
                    Task { await authVM.sendOTP(phone: phone) }
                } label: {
                    Group {
                        if authVM.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Continue")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(isValid ? Color.primary : Color(.systemFill))
                    .foregroundStyle(isValid ? Color(uiColor: .systemBackground) : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!isValid || authVM.isLoading)
                .animation(.easeInOut(duration: 0.15), value: isValid)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
        .onAppear { focused = true }
        .fullScreenCover(isPresented: isOTPPresented) {
            OTPVerificationView()
                .environmentObject(authVM)
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
