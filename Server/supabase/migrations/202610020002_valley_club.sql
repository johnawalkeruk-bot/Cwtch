-- Profiles and mutual friendships. Existing private saves remain owner-only.
begin;
create table public.cwtch_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 username text not null check(username ~ '^[A-Za-z0-9_]{3,20}$'),
 avatar_svg text not null,
 joined_at timestamptz not null default now()
);
create unique index cwtch_username_unique on public.cwtch_profiles(lower(username));
create table public.cwtch_friends (
 sender uuid references public.cwtch_profiles(user_id) on delete cascade,
 recipient uuid references public.cwtch_profiles(user_id) on delete cascade,
 accepted boolean not null default false,
 created_at timestamptz not null default now(),
 primary key(sender,recipient), check(sender <> recipient)
);
create unique index cwtch_friend_pair on public.cwtch_friends(least(sender,recipient),greatest(sender,recipient));
alter table public.cwtch_profiles enable row level security;
alter table public.cwtch_friends enable row level security;
revoke all on public.cwtch_profiles,public.cwtch_friends from public,anon,authenticated;

create function public.cwtch_avatar(person uuid) returns text language sql immutable set search_path='' as $$
 select format('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 160"><rect width="160" height="160" rx="80" fill="hsl(%s,32%%,23%%)"/><circle cx="116" cy="42" r="19" fill="#efd49b"/><path d="M0 127L58 38L115 130Z" fill="#7dada0"/><path d="M31 79L58 38L84 79L62 66L51 76Z" fill="#e7efe1"/><path d="M0 125Q60 77 160 129V160H0Z" fill="#365f47"/><path d="M83 143V106" stroke="#e1cb7a" stroke-width="4"/><g fill="hsl(%s,80%%,70%%)"><ellipse cx="83" cy="99" rx="8" ry="15"/><ellipse cx="70" cy="110" rx="15" ry="8"/><ellipse cx="96" cy="110" rx="15" ry="8"/><ellipse cx="83" cy="121" rx="8" ry="15"/></g><circle cx="83" cy="110" r="7" fill="#b97731"/></svg>',
 (('x'||substr(md5(person::text),1,4))::bit(16)::int % 360),
 (('x'||substr(md5(person::text),5,4))::bit(16)::int % 65));
$$;
create function public.cwtch_username_available(candidate text) returns boolean language sql security definer set search_path='' as $$
 select coalesce(candidate ~ '^[A-Za-z0-9_]{3,20}$',false) and not exists(select 1 from public.cwtch_profiles where lower(username)=lower(candidate));
$$;
create function public.cwtch_create_profile(person uuid, candidate text) returns void language plpgsql security definer set search_path='' as $$
begin
 if candidate is null or candidate !~ '^[A-Za-z0-9_]{3,20}$' then raise exception 'Choose 3–20 letters, numbers or underscores.'; end if;
 insert into public.cwtch_profiles(user_id,username,avatar_svg) values(person,candidate,public.cwtch_avatar(person));
 exception when unique_violation then raise exception 'That username is already taken.';
end $$;
create function public.cwtch_signup_profile() returns trigger language plpgsql security definer set search_path='' as $$
begin
 perform public.cwtch_create_profile(new.id,trim(new.raw_user_meta_data->>'username'));
 return new;
end $$;
create trigger cwtch_signup_profile after insert on auth.users for each row execute function public.cwtch_signup_profile();
create function public.cwtch_claim_username(candidate text) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Sign in first' using errcode='42501'; end if;
 if not exists(select 1 from public.cwtch_profiles where user_id=auth.uid()) then
  perform public.cwtch_create_profile(auth.uid(),trim(candidate));
 end if;
 return (select to_jsonb(p) from public.cwtch_profiles p where user_id=auth.uid());
end $$;
create function public.cwtch_my_profile() returns jsonb language sql security definer set search_path='' as $$
 select to_jsonb(p) from public.cwtch_profiles p where user_id=auth.uid();
$$;
create function public.cwtch_search_people(query text) returns jsonb language sql security definer set search_path='' as $$
 select coalesce(jsonb_agg(x),'[]'::jsonb) from (
 select user_id,username,avatar_svg from public.cwtch_profiles
 where auth.uid() is not null and length(query) between 3 and 20 and user_id<>auth.uid()
 and starts_with(lower(username),lower(query)) order by lower(username) limit 20) x;
$$;
create function public.cwtch_friend_action(target uuid, action text) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or target=auth.uid() then raise exception 'Choose another player.' using errcode='42501'; end if;
 if action='request' then
  insert into public.cwtch_friends(sender,recipient) values(auth.uid(),target) on conflict do nothing;
 elsif action='accept' then
  update public.cwtch_friends set accepted=true where sender=target and recipient=auth.uid();
 elsif action='remove' then
  delete from public.cwtch_friends where (sender=target and recipient=auth.uid()) or (sender=auth.uid() and recipient=target);
 else raise exception 'Unknown friendship action'; end if;
end $$;
create function public.cwtch_list_friends() returns jsonb language sql security definer set search_path='' as $$
 select coalesce(jsonb_agg(x),'[]'::jsonb) from (
 select p.user_id,p.username,p.avatar_svg,f.accepted,(f.recipient=auth.uid()) as incoming
 from public.cwtch_friends f join public.cwtch_profiles p on p.user_id=case when f.sender=auth.uid() then f.recipient else f.sender end
 where auth.uid() in (f.sender,f.recipient) order by lower(p.username)) x;
$$;
-- Only these display fields leave the owner-only save. Never return positions,
-- save payloads, email addresses, tokens or account metadata to friends.
create function public.cwtch_garden_snapshot(target uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.cwtch_saves; p jsonb; visitors jsonb;
begin
 if auth.uid() is null or not (target=auth.uid() or exists(select 1 from public.cwtch_friends where accepted and ((sender=target and recipient=auth.uid()) or (recipient=target and sender=auth.uid())))) then
  raise exception 'Accept a friend request to compare gardens.' using errcode='42501';
 end if;
 select * into s from public.cwtch_saves where user_id=target;
 if not found then return null; end if;
 p:=s.payload;
 select coalesce(jsonb_object_agg(key,jsonb_build_object('visit_day',value->'visit_day','resident_day',value->'resident_day')),'{}') into visitors from jsonb_each(coalesce(p#>'{wildlife,records}','{}'));
 return jsonb_build_object('updated_at',s.updated_at,'revision',s.revision,'payload',jsonb_build_object(
 'coins',p->'coins','elapsed',p->'elapsed','harvested',p->'harvested','terrain',p->'terrain',
 'experience',jsonb_build_object('total',p#>'{experience,total}'),
 'summary',jsonb_build_object('animals',p#>'{summary,animals}','day',p#>'{summary,day}'),
 'wildlife',jsonb_build_object('records',visitors),
 'gardening_actions',(select count(*) from jsonb_object_keys(coalesce(p#>'{experience,worked}','{}'))),
 'crops_growing',jsonb_array_length(coalesce(p->'crops','[]')),
 'purchases',jsonb_array_length(coalesce(p->'purchases','[]')),
 'watered_tiles',jsonb_array_length(coalesce(p->'watered','[]')),
 'births',(select count(*) from jsonb_array_elements(coalesce(p#>'{wildlife,life_events}','[]')) e where e->>'kind'='birth'),
 'deaths',(select count(*) from jsonb_array_elements(coalesce(p#>'{wildlife,life_events}','[]')) e where e->>'kind'='death'),
 'weather',p->'weather','wetness',p->'wetness'));
end $$;
-- Lock helpers, then expose only the intended API.
revoke all on function public.cwtch_avatar(uuid),public.cwtch_create_profile(uuid,text),public.cwtch_signup_profile(),public.cwtch_username_available(text),public.cwtch_claim_username(text),public.cwtch_my_profile(),public.cwtch_search_people(text),public.cwtch_friend_action(uuid,text),public.cwtch_list_friends(),public.cwtch_garden_snapshot(uuid) from public,anon,authenticated;
grant execute on function public.cwtch_username_available(text) to anon,authenticated;
grant execute on function public.cwtch_claim_username(text),public.cwtch_my_profile(),public.cwtch_search_people(text),public.cwtch_friend_action(uuid,text),public.cwtch_list_friends(),public.cwtch_garden_snapshot(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
