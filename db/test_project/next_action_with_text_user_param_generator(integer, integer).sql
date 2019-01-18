-- drop function test_project.next_action_with_text_user_param_generator(integer, integer);

create or replace function test_project.next_action_with_text_user_param_generator(in_object_id integer, in_actor_id integer)
returns jsonb
stable
as
$$
declare
  v_object_code text := data.get_object_code(in_object_id);
begin
  assert in_actor_id is not null;

  return format(
'{
  "action": {
    "code": "next_action_with_text_user_param",
    "name": "Далее",
    "disabled": false,
    "params": "%s",
    "user_params": [
      {
        "code": "param",
        "description": "Текстовая строка",
        "type": "string",
        "restrictions": {
          "multiline": false
        }
      }
    ]
  }
}', v_object_code)::jsonb;
end;
$$
language 'plpgsql';
