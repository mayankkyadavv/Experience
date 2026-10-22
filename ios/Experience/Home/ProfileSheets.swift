import SwiftUI

/// Name, username and bio: what a visitor sees at the top of your profile.
struct EditProfileSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var username = ""
    @State private var bio = ""
    @State private var saving = false
    @State private var error: String?

    private static let bioLimit = 160

    /// Matches the server's rule: 3-24 of a-z, 0-9 and _.
    private var usernameProblem: String? {
        guard !username.isEmpty else { return nil }
        if username.count < 3 { return "At least 3 characters." }
        if username.count > 24 { return "At most 24 characters." }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                        .accessibilityIdentifier("profile.name")
                        .onChange(of: name) { _, v in if v.count > 50 { name = String(v.prefix(50)) } }
                    HStack(spacing: 2) {
                        Text("@").foregroundStyle(.secondary)
                        TextField("username", text: $username)
                            .accessibilityIdentifier("profile.username")
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.username)
                            .onChange(of: username) { _, v in
                                let cleaned = String(v.lowercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }.prefix(24))
                                if cleaned != v { username = cleaned }
                            }
                    }
                } footer: {
                    Text(usernameProblem ?? "Letters, numbers and underscores. Friends can find you by it later.")
                        .foregroundStyle(usernameProblem == nil ? Color.secondary : Theme.error)
                }

                Section {
                    TextField("A line about you", text: $bio, axis: .vertical)
                        .accessibilityIdentifier("profile.bio")
                        .lineLimit(3...5)
                        .onChange(of: bio) { _, v in if v.count > Self.bioLimit { bio = String(v.prefix(Self.bioLimit)) } }
                } header: {
                    Text("Bio")
                } footer: {
                    HStack {
                        Text("Shown on your profile.")
                        Spacer()
                        Text("\(bio.count)/\(Self.bioLimit)").monospacedDigit()
                    }
                }

                if let error {
                    Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(Theme.error) }
                }
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if saving {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await save() } }
                            .fontWeight(.semibold)
                            .disabled(usernameProblem != nil)
                    }
                }
            }
        }
        .onAppear {
            name = model.profile?.displayName ?? ""
            username = model.profile?.username ?? ""
            bio = model.profile?.bio ?? ""
        }
        .interactiveDismissDisabled(saving)
    }

    private func save() async {
        saving = true
        error = nil
        do {
            try await model.updateProfile(displayName: name, username: username, bio: bio)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        saving = false
    }
}

/// Behind the cog on the You page: appearance, the light background preview, privacy, sign out.
struct SettingsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance") private var appearance: Appearance = .system
    @AppStorage("lightBackdrop") private var backdrop: LightBackdrop = .atlas

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(Appearance.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    // Temporary: the founder compares the two light backgrounds, then the other is deleted.
                    Picker("Light background", selection: $backdrop) {
                        ForEach(LightBackdrop.allCases) { Text($0.label).tag($0) }
                    }
                } footer: {
                    Text("Atlas is warm paper with faint map lines; Gallery is plain white.")
                }

                Section {
                    Label("Everything you add is private unless you choose to share it.", systemImage: "lock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                #if LOCAL_BACKEND
                Section {
                    if model.isUsingSampleProfile {
                        Button("Back to my account") { dismiss(); Task { await model.useMyAccount() } }
                    } else {
                        Button("Use the sample profile") { dismiss(); Task { await model.useSampleProfile() } }
                    }
                } header: {
                    Text("Developer")
                } footer: {
                    Text("A labelled demo account with sample Experiences, for showing the app. Local builds only.")
                }
                #endif

                Section {
                    Button("Sign out", role: .destructive) {
                        dismiss()
                        Task { await model.signOut() }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.semibold) }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
