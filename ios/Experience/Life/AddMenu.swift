import ExperienceCore
import PhotosUI
import SwiftUI

/// The + sheet: four ways in, all ending on the same draft screen. The camera hands over to the camera page.
struct AddMenu: View {
    /// Goes to the camera page; the sheet closes first.
    let onCamera: () -> Void

    @Environment(LifeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: TrayDraft?
    @State private var picks: [PhotosPickerItem] = []
    @State private var importing = false
    @State private var importError: String?
    @State private var confirmingDiscard = false
    @State private var week: [TrayDraft] = []
    @State private var bringingIn = false

    var body: some View {
        Group {
            if draft != nil {
                DraftView(draft: Binding(get: { draft ?? TrayDraft() }, set: { draft = $0 }), onDismiss: cancel, onSave: save)
                    .transition(.move(edge: .trailing))
            } else {
                menu.transition(.opacity)
            }
        }
        .animation(Theme.Motion.short, value: draft == nil)
        .presentationDetents([.large])
        .presentationCornerRadius(Theme.Radius.sheet)
        .presentationDragIndicator(draft == nil ? .visible : .hidden)
        .interactiveDismissDisabled(draft?.canSave == true)
        .onChange(of: picks) { _, items in Task { await importPicks(items) } }
        .task { loadWeek() }
        .fullScreenCover(isPresented: $bringingIn) {
            ImportFlow { kept in
                bringingIn = false
                if kept > 0 { dismiss() }
            }
        }
        .confirmationDialog("Discard this draft?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive, action: discard)
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("Nothing has been saved yet.")
        }
    }

    private var menu: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                Text("Add an Experience").font(.display(30)).displayTracking(30).foregroundStyle(Theme.text)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    Button {
                        dismiss()
                        onCamera()
                    } label: {
                        tile("camera.fill", "Take a photo\nor video", dark: true)
                    }
                    .buttonStyle(PressableStyle())
                    PhotosPicker(selection: $picks, maxSelectionCount: 30, matching: .any(of: [.images, .videos]), photoLibrary: .shared()) {
                        tile(importing ? "hourglass" : "photo.on.rectangle.angled", importing ? "Adding…" : "Choose from\nPhotos")
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(importing)
                    Button { start(TrayDraft()) } label: { tile("text.alignleft", "Just write\nit down") }
                        .buttonStyle(PressableStyle())
                    Button { start(TrayDraft(lived: false)) } label: { tile("star", "Something I\nwant to do") }
                        .buttonStyle(PressableStyle())
                }
                if let importError { Text(importError).font(.footnote).foregroundStyle(Theme.error) }
                if !week.isEmpty { weekSection }
                bringInRow
            }
            .padding(.horizontal, Theme.Space.xl)
            .padding(.top, Theme.Space.xl)
        }
        .background(Theme.surface)
    }

    /// Only once Photos access was given (from "Bring in past Experiences"); this menu never asks for it.
    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("From your photos this week").font(.mono).textCase(.uppercase).tracking(0.66).foregroundStyle(Theme.textMuted)
            HStack(spacing: Theme.Space.sm) {
                ForEach(week) { d in
                    Button { draft = d } label: {
                        ZStack(alignment: .bottomLeading) {
                            if let cover = d.cover { MediaThumb(asset: cover.asset, drift: false) } else { Theme.soft }
                            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(d.start.formatted(.dateTime.weekday(.wide)))
                                Text(d.countLabel)
                            }
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 112)
                        .clipShape(.rect(cornerRadius: Theme.Radius.button, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("\(d.start.formatted(.dateTime.weekday(.wide))), \(d.countLabel.lowercased())")
                }
            }
            Text("Grouped on this iPhone by day and place. Tap one to start a draft.")
                .font(.footnote).foregroundStyle(Theme.textMuted)
        }
    }

    private var bringInRow: some View {
        Button { bringingIn = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "photo.stack")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 44, height: 44)
                    .background(Theme.soft, in: .rect(cornerRadius: Theme.Radius.control, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bring in past Experiences").font(.body.weight(.semibold)).foregroundStyle(Theme.text)
                    Text("From your albums in Photos").font(.footnote).foregroundStyle(Theme.textMuted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.textMuted)
            }
            .padding(Theme.Space.lg)
            .background(Theme.surface, in: .rect(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.hairline))
            .contentShape(.rect)
        }
        .buttonStyle(PressableStyle())
    }

    private func loadWeek() {
        guard PhotoLibrary.canRead else { return }
        let drafts = PhotoLibrary.group(PhotoLibrary.shots(PhotoLibrary.recent(days: 7), skipping: store.linkedRefs))
        week = Array(drafts.suffix(3).reversed())
    }

    private func tile(_ symbol: String, _ label: String, dark: Bool = false) -> some View {
        VStack(alignment: .leading) {
            Image(systemName: symbol).font(.system(size: 22, weight: .semibold))
            Spacer(minLength: Theme.Space.md)
            Text(label).font(.body.weight(.semibold)).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(dark ? Theme.onPrimary : Theme.text)
        .padding(Theme.Space.lg)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .background(dark ? Theme.primary : Theme.soft, in: .rect(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label.replacingOccurrences(of: "\n", with: " "))
    }

    // MARK: Actions

    /// A new text draft starts on today; a want has no time.
    private func start(_ new: TrayDraft) {
        var d = new
        if d.lived { d.chosenTime = .day(Date()) }
        draft = d
    }

    private func importPicks(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        importing = true
        importError = nil
        let (added, failed) = await LifeMedia.importPicked(items)
        picks = []
        importing = false
        if failed > 0 { importError = failed == 1 ? "One item couldn't be added." : "\(failed) items couldn't be added." }
        guard !added.isEmpty else { return }
        var d = TrayDraft(shots: added.map { TrayShot(picked: $0, takenAt: Date()) })
        // Photos without a date can't say when; leave that to the person.
        if added.allSatisfy({ $0.takenAt == nil }) { d.chosenTime = .unknown }
        draft = d
    }

    private func save() {
        guard let saving = draft?.saving() else { return }
        store.save(saving.draft, media: saving.media, collection: saving.collection)
        dismiss()
    }

    private func cancel() {
        if draft?.canSave == true || draft?.words.isEmpty == false { confirmingDiscard = true } else { discard() }
    }

    /// Picked photos were copied in for this draft; they go with it. The library keeps its own.
    private func discard() {
        for shot in draft?.shots ?? [] { shot.discardFile() }
        draft = nil
        dismiss()
    }
}
