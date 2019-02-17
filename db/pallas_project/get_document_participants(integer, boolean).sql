-- drop function pallas_project.get_document_participants(integer, boolean);

create or replace function pallas_project.get_document_participants(in_document_id integer, in_with_sign_info boolean default false)
returns text
volatile
as
$$
declare
  v_persons text := '';
  v_record record;
  v_system_document_participants jsonb := data.get_attribute_value(in_document_id, 'system_document_participants');
  v_system_document_author integer := json.get_integer(data.get_attribute_value(in_document_id, 'system_document_author'));
begin
  for v_record in (select x.code, 
                          (case 
                            when in_with_sign_info then (case when signed then ' - Есть подпись' else ' - Нет подписи' end) 
                            else '' end) sign
                   from jsonb_to_recordset(v_system_document_participants) as x(code text, signed boolean)) loop
    v_persons:= v_persons || 'E/n' || pp_utils.link(v_record.code, v_system_document_author) || v_record.sign;
  end loop;

  return v_persons;
end;
$$
language plpgsql;
