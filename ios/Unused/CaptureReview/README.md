# CaptureReview

The screen that followed every shot from the in-app camera (ADR-012): the photo or video full screen with Retake, then "Where was this?" against the Philadelphia catalog. Each shot became its own Experience. `LifeStore+SaveCapture.swift` is the save it called, which lived at the end of `LifeStore`.

**Parked 2026-10-22:** the founder chose A + C for creating Experiences. Shots now collect in a draft tray beside the shutter, grouped by time and place, and are kept from the tray or from the card on the globe (`Experience/Life/CaptureTray.swift`). Nothing asks a question between shots.

**Restore:** move `CaptureReview.swift` back to `ios/Experience/Camera/`, paste `saveCapture` back into `LifeStore`, and in `CaptureFlow` show `CaptureReview` when `camera.captured` is set instead of adding it to the tray.
