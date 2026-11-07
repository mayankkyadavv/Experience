-- Media linked to the Photos library instead of uploaded (founder, 2026-10-22: "for testing, linked to Photos").
-- An import points at the photo where it already lives; nothing is copied. The reference is the library's local
-- identifier, which only means something on the phone that made it: other devices and viewers see no picture
-- until the file is uploaded. Export and other devices need the upload path; this is the testing default.
alter type media_status add value if not exists 'linked';
alter table media_assets add column library_ref text check (char_length(library_ref) <= 200);
