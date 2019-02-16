-- drop function pallas_project.get_chat_persons_text(integer, boolean);

create or replace function pallas_project.get_chat_persons_text(in_chat_id integer, in_but_masters boolean default false)
returns text
volatile
as
$$
declare
  v_record record;
  v_persons text := '';
begin
-- Список текст со списком участников чата и ссылками
-- in_but_masters = true - кроме мастеров
  for v_record in (select x.code, x.name 
        from jsonb_to_recordset(pallas_project.get_chat_persons(in_chat_id, in_but_masters)) as x(code text, name jsonb)) loop 
        v_persons := v_persons || '
'|| '['||json.get_string(v_record.name)||'](babcom:'||v_record.code||')';
      end loop;
  return v_persons;
end;
$$
language plpgsql;
