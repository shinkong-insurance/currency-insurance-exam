-- supabase/migrations/0001_init_schema.test.sql
select 1/count(*) from information_schema.tables
  where table_name in ('course','chapters','questions','mnemonic_cards','sections',
                        'levels','level_progress','license_keys','key_sessions',
                        'key_favorites','key_wrong_answers','study_logs')
  having count(*) = 12;  -- 除以 0 會噴錯，藉此斷言剛好 12 張表都建立

-- RPC 函式也要斷言存在，這是 lk_auth_service.dart 登入流程會直接呼叫的
select 1/count(*) from pg_proc where proname = 'increment_key_used_count';

-- answer 超出範圍應被拒絕
do $$
begin
  begin
    insert into course (id, name) values (1, 'x');
    insert into chapters (id, course_id, unit_no, title) values (1,1,1,'x');
    insert into questions (id, chapter_id, question_no, question, options, answer)
      values (1,1,1,'q', array['a','b','c','d'], 9);
    raise exception 'should have failed on answer check constraint';
  exception when check_violation then
    raise notice 'PASS: answer check constraint enforced';
  end;
  rollback;
end $$;
