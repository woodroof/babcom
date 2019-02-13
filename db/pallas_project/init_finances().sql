-- drop function pallas_project.init_finances();

create or replace function pallas_project.init_finances()
returns void
volatile
as
$$
begin
  perform data.create_class(
    'transaction',
    jsonb '[
      {"code": "is_visible", "value": true, "value_object_code": "master"},
      {
        "code": "mini_card_template",
        "value": {
          "title": "title",
          "groups": [{"code": "group", "attributes": ["mini_description"]}]
        }
      }
    ]');
  perform data.create_class(
    'transactions',
    jsonb '[
      {"code": "title", "value": "История транзакций"},
      {"code": "is_visible", "value": true, "value_object_code": "master"},
      {
        "code": "template",
        "value": {
          "title": "title",
          "groups": []
        }
      },
      {"code": "list_element_function", "value": "pallas_project.lef_do_nothing"}
    ]');
end;
$$
language plpgsql;
