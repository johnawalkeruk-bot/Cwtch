-- CWTCH: one private garden per account; no public player directory.
begin;
create table if not exists public.cwtch_saves (
 user_id uuid primary key references auth.users(id) on delete cascade,
 payload jsonb not null,
 revision bigint not null default 1 check (revision > 0),
 updated_at timestamptz not null default now(),
 constraint cwtch_payload_size check (octet_length(payload::text) <= 3000000)
);
alter table public.cwtch_saves enable row level security;
revoke all on public.cwtch_saves from public, anon, authenticated;
grant select on public.cwtch_saves to authenticated;
drop policy if exists cwtch_owner_read on public.cwtch_saves;
create policy cwtch_owner_read on public.cwtch_saves for select to authenticated
 using ((select auth.uid()) = user_id);

-- Expected revision 0 means a first upload. Atomic compare-and-swap also
-- protects two devices uploading at once. Clients cannot choose an owner.
create or replace function public.cwtch_put_save(expected_revision bigint, garden jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 owner_id uuid := auth.uid();
 saved public.cwtch_saves;
begin
 if owner_id is null then raise exception 'Sign in first' using errcode='42501'; end if;
 if expected_revision is null or expected_revision < 0 then
  raise exception 'Invalid revision' using errcode='22023';
 end if;
 if garden is null or jsonb_typeof(garden) <> 'object' or
    octet_length(garden::text) > 3000000 or
    (garden->>'version') is distinct from '1' or
    jsonb_typeof(garden->'terrain') is distinct from 'array' or
    jsonb_typeof(garden->'player') is distinct from 'array' then
  raise exception 'Invalid garden' using errcode='22023';
 end if;
 if jsonb_array_length(garden->'terrain') <> 1296 or
    jsonb_array_length(garden->'player') <> 2 then
  raise exception 'Invalid garden dimensions' using errcode='22023';
 end if;
 if exists(select 1 from jsonb_array_elements(garden->'terrain') t
           where t not in ('0'::jsonb,'1'::jsonb,'2'::jsonb,'3'::jsonb,'4'::jsonb,'5'::jsonb,'6'::jsonb,'7'::jsonb)) then
  raise exception 'Invalid terrain' using errcode='22023';
 end if;
 if expected_revision = 0 then
  insert into public.cwtch_saves(user_id,payload) values(owner_id,garden)
   on conflict(user_id) do nothing returning * into saved;
 else
  update public.cwtch_saves set payload=garden, revision=revision+1, updated_at=now()
   where user_id=owner_id and revision=expected_revision returning * into saved;
 end if;
 if saved.user_id is null then
  raise exception 'Cloud garden changed. Review it before syncing.' using errcode='40001';
 end if;
 return jsonb_build_object('revision',saved.revision,'updated_at',saved.updated_at);
end $$;
revoke all on function public.cwtch_put_save(bigint,jsonb) from public, anon, authenticated;
grant execute on function public.cwtch_put_save(bigint,jsonb) to authenticated;
notify pgrst, 'reload schema';
commit;
