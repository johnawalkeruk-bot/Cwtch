-- Run in the Supabase SQL Editor. All fixture users and saves roll back.
-- No emails are sent and no existing player data is modified.
begin;
select set_config('cwtch.test_a',gen_random_uuid()::text,true);
select set_config('cwtch.test_b',gen_random_uuid()::text,true);
insert into auth.users(id,aud,role,email)
 values(current_setting('cwtch.test_a')::uuid,'authenticated','authenticated',current_setting('cwtch.test_a')||'@example.invalid'),
 (current_setting('cwtch.test_b')::uuid,'authenticated','authenticated',current_setting('cwtch.test_b')||'@example.invalid');
set local role authenticated;
select set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('cwtch.test_a'),'role','authenticated')::text,true);
do $$
declare doc jsonb; result jsonb;
begin
 doc:=jsonb_build_object('version',1,'player',jsonb_build_array(0,0),'terrain',(select jsonb_agg(1) from generate_series(1,1296)));
 result:=public.cwtch_put_save(0,doc);
 assert (result->>'revision')::int=1,'First upload must be revision 1';
 assert (select count(*) from public.cwtch_saves)=1,'Owner can read';
 result:=public.cwtch_put_save(1,doc);
 assert (result->>'revision')::int=2,'Successful save increments revision';
 begin
  perform public.cwtch_put_save(1,doc);
  raise exception 'Stale save was accepted';
 exception when sqlstate '40001' then null;
 end;
 begin
  update public.cwtch_saves set revision=999;
  raise exception 'Direct update was permitted';
 exception when insufficient_privilege then null;
 end;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('cwtch.test_b'),'role','authenticated')::text,true);
 assert (select count(*) from public.cwtch_saves)=0,'Other account must not see owner save';
 begin
  perform public.cwtch_put_save(2,doc);
  raise exception 'Other account could overwrite owner save';
 exception when sqlstate '40001' then null;
 end;
 result:=public.cwtch_put_save(0,doc);
 assert (result->>'revision')::int=1,'Second account gets a separate save';
end $$;
reset role;
set local role anon;
do $$ begin
 begin
  perform 1 from public.cwtch_saves;
  raise exception 'Anonymous read permitted';
 exception when insufficient_privilege then null;
 end;
 begin
  perform public.cwtch_put_save(0,'{}'::jsonb);
  raise exception 'Anonymous write permitted';
 exception when insufficient_privilege then null;
 end;
end $$;
reset role;
select 'PASS: owner isolation, independent saves, revision conflict, direct-write denial and anonymous denial' as result;
rollback;
