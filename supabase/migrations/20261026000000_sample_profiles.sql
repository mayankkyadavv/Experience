-- Sample profiles (brief §19: a demo must be clearly labelled and removable; never mixed into a real archive).
-- A sample account's profile carries this flag, and the app labels it "Sample profile" wherever it shows.
alter table profiles add column is_sample boolean not null default false;
