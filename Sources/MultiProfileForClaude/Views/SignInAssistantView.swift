import SwiftUI

struct SignInAssistantView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var router = AppModel.shared.signInRouter
    @Environment(\.dismiss) private var dismiss
    let profile: Profile

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if router.isActive {
                steps
            } else {
                finished
            }
        }
        .padding(28)
        .frame(width: 580)
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 14) {
                LetterBadge(letter: profile.letter, color: profile.color, size: 40)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Signing in to \(profile.displayName)").font(.title3.weight(.semibold))
                    Text("Sign-in links now open \(profile.displayName). When you finish — or after 10 minutes — they go back to your original Claude app.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if let deadline = router.deadline {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = max(0, Int(deadline.timeIntervalSince(context.date)))
                        Text(String(format: "%d:%02d left", remaining / 60, remaining % 60))
                            .font(.caption.monospacedDigit())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.secondary.opacity(0.14)))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                step(1, "Check which account your browser is using",
                     "If your browser is already signed in to claude.ai with a different account, sign out there first, or paste the sign-in link into a private window.")
                step(2, "Sign in from the \(profile.displayName) window",
                     "Use email or Google sign-in. Passkeys, security keys and Microsoft single sign-on aren't available in profile apps.")
                step(3, "Allow keychain access once",
                     "macOS asks whether \(profile.displayName) may use “Claude Safe Storage”. Enter your Mac login password and choose Always Allow.")
            }

            Divider()
            HStack {
                Button("Open \(profile.displayName)") { model.open(profile) }
                Spacer()
                Button("Cancel") { Task { await model.finishSignIn() } }
                Button("I'm Signed In") { Task { await router.finish() } }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var finished: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("You're all set").font(.title3.weight(.semibold))
            NoticeBox {
                Text("Sign-in links open your original Claude app again. \(profile.displayName) stays signed in until you sign out inside it.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("Sign In Again") { Task { await model.beginSignIn(profile) } }
                Button("Close") {
                    model.signInProfileID = nil
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func step(_ number: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .fontWeight(.semibold)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.secondary.opacity(0.15)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).fontWeight(.semibold)
                Text(detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
