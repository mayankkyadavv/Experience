-- Profile basics for the You page (brief §8): a short bio, and sane lengths for what a visitor sees.
-- Still owner-only (profiles_own): nobody else can read a profile until friends/public visibility lands.
alter table profiles
  add column bio text check (char_length(bio) <= 160);
alter table profiles
  add constraint profiles_display_name_length check (char_length(display_name) <= 50);
