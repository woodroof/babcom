-- drop function data.calc_content_diff(jsonb, jsonb);

create or replace function data.calc_content_diff(in_original_content jsonb, in_new_content jsonb)
returns jsonb
volatile
as
$$
-- add - массив объектов с полями position и object_code
-- remove - массив кодов объектов
declare
  v_add jsonb := jsonb '[]';
  v_remove jsonb := jsonb '[]';
  v_code text;
begin
  perform json.get_string_array_opt(in_original_content);
  perform json.get_string_array_opt(in_new_content);

  if
    in_original_content is null and in_new_content is null or
    in_original_content = in_new_content
  then
    return jsonb '{"add": [], "remove": []}';
  end if;

  if in_new_content is null then
    v_remove := in_original_content;
  elsif in_original_content is null then
    for v_code in
    (
      select value
      from jsonb_array_elements(in_new_content)
    )
    loop
      v_add := v_add || jsonb_build_object('object_code', v_code);
    end loop;
  else
    -- todo самое интересное
  end if;

  return jsonb_build_object('add', v_add, 'remove', v_remove);
end;
$$
language plpgsql;
