# AddExperienceSheet

The first Add an Experience form (2026-10-21): lived / want, a media strip, title and words, When with day / month / season / year / not sure, Where as free text, kind chips and a collection, then Save privately.

**Parked 2026-10-22:** the founder chose one draft screen for every way in. The + now opens `AddMenu` (take a photo, choose from Photos, just write it down, something I want to do), and all of them end on `DraftView`, the same screen the camera's tray uses. Its approximate-time logic lives on in `ChosenTime` and `DraftView`'s time editor; the picker import moved to `Experience/Life/PickedMedia.swift`.

**Restore:** move `AddExperienceSheet.swift` back to `ios/Experience/Life/` and present it from `ProfilePage` instead of `AddMenu`.
