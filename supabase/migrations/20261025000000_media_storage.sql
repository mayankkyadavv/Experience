-- Private media storage (ADR-013 media durability; brief §9, §21).
-- Bucket `media`, private. Objects live at <owner_id>/<experience_id>/<client_id>.<ext> (the original, untouched)
-- and <owner_id>/<experience_id>/<client_id>.thumb.jpg (a replaceable derivative with no location metadata).
-- Only the owner writes under their own folder. Reading goes through the same rule as everything else:
-- the owner, or anyone who may see the Experience once the asset is ready. Signed URLs are short-lived, and
-- the storage API checks this policy before signing one; an unguessable path is not authorization.
-- Skipped where the Storage service isn't installed (the PGlite schema tests).

do $migration$
begin
  if to_regclass('storage.objects') is null then
    raise notice 'storage schema not present; skipping media bucket';
    return;
  end if;

  insert into storage.buckets (id, name, public, file_size_limit)
  values ('media', 'media', false, 1073741824)
  on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit;

  execute $p$
    create policy media_owner_write on storage.objects for insert to authenticated
      with check (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text
                  and public.owns_experience(((storage.foldername(name))[2])::uuid))
  $p$;
  execute $p$
    create policy media_owner_update on storage.objects for update to authenticated
      using (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text)
      with check (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text)
  $p$;
  execute $p$
    create policy media_owner_delete on storage.objects for delete to authenticated
      using (bucket_id = 'media' and (storage.foldername(name))[1] = auth.uid()::text)
  $p$;
  execute $p$
    create policy media_read on storage.objects for select to authenticated, anon
      using (bucket_id = 'media' and (
        (auth.uid() is not null and (storage.foldername(name))[1] = auth.uid()::text)
        or exists (select 1 from public.media_assets m
                   where (m.original_path = name or m.thumb_path = name)
                     and m.status = 'ready'
                     and public.can_view_experience(m.experience_id))))
  $p$;
end;
$migration$;
