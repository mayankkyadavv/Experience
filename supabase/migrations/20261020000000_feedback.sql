-- Feedback on an Experience (MVP.md): Save · Interested · Not interested · Did it · Rating.
-- One call updates user_experiences and logs the MVP event, atomically, as the caller (RLS applies).
--   POST /rest/v1/rpc/record_feedback {"p_experience_id": "...", "p_action": "rate", "p_rating": 3}

create function record_feedback(
  p_experience_id uuid,
  p_action text,
  p_rating smallint default null,
  p_recommendation_id uuid default null
) returns user_experiences
language plpgsql security invoker set search_path = public
as $$
declare
  me uuid := auth.uid();
  ue user_experiences;
begin
  if me is null then
    raise exception 'Not signed in' using errcode = '28000';
  end if;
  if p_action not in ('save', 'unsave', 'interested', 'not_interested', 'done', 'undone', 'rate') then
    raise exception 'Unknown action "%"', p_action using errcode = '22023';
  end if;
  -- RLS on experiences hides drafts and other people's private rows.
  if not exists (select 1 from experiences where id = p_experience_id) then
    raise exception 'Experience not found' using errcode = 'P0002';
  end if;

  insert into user_experiences (user_id, experience_id) values (me, p_experience_id)
  on conflict (user_id, experience_id) do nothing;

  select * into ue from user_experiences where user_id = me and experience_id = p_experience_id for update;

  if p_action = 'rate' then
    if ue.done_at is null then
      raise exception 'Mark it done before rating it' using errcode = '22023';
    end if;
    if p_rating is null or p_rating not between 1 and 3 then
      raise exception 'Rating must be 1, 2 or 3' using errcode = '22023';
    end if;
  end if;

  update user_experiences set
    saved_at          = case p_action when 'save' then coalesce(saved_at, now()) when 'unsave' then null else saved_at end,
    interested_at     = case p_action when 'interested' then now() when 'not_interested' then null else interested_at end,
    not_interested_at = case p_action when 'not_interested' then now() when 'interested' then null else not_interested_at end,
    done_at           = case p_action when 'done' then coalesce(done_at, now()) when 'undone' then null else done_at end,
    rating            = case p_action when 'rate' then p_rating when 'undone' then null else rating end,
    from_recommendation = coalesce(p_recommendation_id, from_recommendation),
    updated_at        = now()
  where user_id = me and experience_id = p_experience_id
  returning * into ue;

  insert into events (user_id, name, props) values (
    me,
    case p_action when 'save' then 'saved' when 'unsave' then 'unsaved' when 'done' then 'did_it' when 'undone' then 'undid_it'
                  when 'rate' then 'rated' else p_action end,
    jsonb_strip_nulls(jsonb_build_object(
      'experience_id', p_experience_id,
      'rating', case when p_action = 'rate' then p_rating end,
      'recommendation_id', p_recommendation_id,
      'from_recommendation', case when p_action = 'done' then ue.from_recommendation is not null end
    ))
  );

  return ue;
end;
$$;

revoke execute on function record_feedback(uuid, text, smallint, uuid) from public, anon;
grant execute on function record_feedback(uuid, text, smallint, uuid) to authenticated;
