-- drop function pallas_project.actgenerator_mine(integer, integer);

create or replace function pallas_project.actgenerator_mine(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
  v_actions jsonb := '{}';
begin
  v_actions :=
    v_actions ||
    jsonb '{
      "save_map": {
        "code": "save_map", 
        "name": "Сохранить карту",
        "disabled": false,
        "params": {},
        "user_params": [
          {
            "code": "map",
            "description": "Новая карта",
            "type": "string"
          }
        ]
      },
      "add_content": {
        "code": "add_content", 
        "name": "Добавить содержимое",
        "disabled": false,
        "params": {},
        "user_params": [
          {
            "code": "id",
            "description": "Идентификатор транспорта",
            "type": "string"
          },
          {
            "code": "content_id",
            "description": "Идентификатор содержимого",
            "type": "string"
          }
        ]
      },
      "remove_content": {
        "code": "remove_content", 
        "name": "Убрать содержимое",
        "disabled": false,
        "params": {},
        "user_params": [
          {
            "code": "id",
            "description": "Идентификатор транспорта",
            "type": "string"
          },
          {
            "code": "content_id",
            "description": "Идентификатор содержимого",
            "type": "string"
          }
        ]
      },
      "take_equipment": {
        "code": "take_equipment", 
        "name": "Занять оборудование",
        "disabled": false,
        "params": {},
        "user_params": [
          {
            "code": "id",
            "description": "Идентификатор оборудования",
            "type": "string"
          }
        ]
      },
      "free_equipment": {
        "code": "free_equipment", 
        "name": "Освободить оборудование",
        "disabled": false,
        "params": {},
        "user_params": [
          {
            "code": "id",
            "description": "Идентификатор оборудования",
            "type": "string"
          }
        ]
      },
      "move_equipment": {
        "code": "move_equipment", 
        "name": "Переместить оборудование",
        "disabled": false,
        "params": {},
        "user_params": [
          {
            "code": "id",
            "description": "Идентификатор оборудования",
            "type": "string"
          },
          {
            "code": "x",
            "description": "Новая координата x",
            "type": "integer"
          },
          {
            "code": "y",
            "description": "Новая координата y",
            "type": "integer"
          }
        ]
      },
      "add_equipment": {
        "code": "add_equipment", 
        "name": "Добавить оборудование",
        "disabled": false,
        "params": {},
        "user_params": [
          {
            "code": "x",
            "description": "Координата x",
            "type": "integer"
          },
          {
            "code": "y",
            "description": "Координата y",
            "type": "integer"
          },
          {
            "code": "type",
            "description": "Тип",
            "type": "string"
          }
        ]
      }
    }';
  return v_actions;
end;
$$
language plpgsql;
