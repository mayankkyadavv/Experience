import AuthenticationServices
import CryptoKit
import SwiftUI

struct WelcomeView: View {
    @Environment(AppModel.self) private var model
    @State private var nonce = ""
    @State private var working = false
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Staggered rise for the welcome content.
    private func rise(_ i: Int) -> some ViewModifier { Rise(shown: shown, delay: reduceMotion ? 0 : Double(i) * 0.08) }

    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                Text("What should we do?")
                    .font(.display(44))
                    .displayTracking(44)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .modifier(rise(0))
                Text("Tell it when, who and how much. Get three good answers in your city, then go.")
                    .font(.body)
                    .foregroundStyle(Theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .modifier(rise(1))

                if let error = model.authError {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(Theme.error)
                }

                signIn
                    .padding(.top, Theme.Space.sm)
                    .modifier(rise(2))
            }
            .padding(Theme.Space.xl)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.Radius.sheet, style: .continuous))
            .lift()
            .padding(8)
        }
        .onAppear { shown = true }
    }

    @ViewBuilder private var signIn: some View {
        #if LOCAL_BACKEND
        Button {
            working = true
            Task {
                await model.signInLocal()
                working = false
            }
        } label: {
            if working { ProgressView().tint(Theme.onPrimary) } else { Text("Continue") }
        }
        .buttonStyle(.primary)
        .disabled(working)
        Text("Local build: signs in to the Docker backend.")
            .monoLabel()
        #else
        SignInWithAppleButton(.continue) { request in
            nonce = Self.randomNonce()
            request.requestedScopes = []
            request.nonce = Self.sha256(nonce)
        } onCompletion: { result in
            guard case .success(let auth) = result,
                  let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let token = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) })
            else { return }
            Task { await model.signInWithApple(idToken: token, nonce: nonce) }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 52)
        .clipShape(.rect(cornerRadius: Theme.Radius.button, style: .continuous))
        #endif
    }

    private static func randomNonce() -> String {
        (0..<32).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
    }

    private static func sha256(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

private struct Rise: ViewModifier {
    let shown: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .offset(y: shown ? 0 : 18)
            .opacity(shown ? 1 : 0)
            .animation(.spring(duration: 0.6, bounce: 0).delay(delay + 0.15), value: shown)
    }
}
