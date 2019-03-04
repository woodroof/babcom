-- drop function pallas_project.actgenerator_prices(integer, integer);

create or replace function pallas_project.actgenerator_prices(in_object_id integer, in_actor_id integer)
returns jsonb
volatile
as
$$
declare
begin
  return
    jsonb '{
      "change_coin_price": {
        "code": "change_coin_price",
        "name": "Изменить статус коина",
        "disabled": false,
        "params": null,
        "user_params": [
          {
            "code": "price",
            "description": "Стоимость, UN$",
            "type": "integer",
            "restrictions": {
              "min_value": 0
            }
          }
        ]
      },
      "change_life_support_status_price": {
        "code": "change_status_price",
        "name": "Изменить стоимость статусов жизнеобеспечения",
        "disabled": false,
        "params": "life_support",
        "user_params": [
          {
            "code": "index",
            "description": "Статус (1 - бронза, 2 - серебро, 3 - золото)",
            "type": "integer",
            "restrictions": {
              "min_value": 1,
              "max_value": 3
            }
          },
          {
            "code": "price",
            "description": "Стоимость в коинах перехода от предыдущего статуса",
            "type": "integer",
            "restrictions": {
              "min_value": 0
            }
          }
        ]
      },
      "change_health_care_status_price": {
        "code": "change_status_price",
        "name": "Изменить стоимость статусов медицины",
        "disabled": false,
        "params": "health_care",
        "user_params": [
          {
            "code": "index",
            "description": "Статус (1 - бронза, 2 - серебро, 3 - золото)",
            "type": "integer",
            "restrictions": {
              "min_value": 1,
              "max_value": 3
            }
          },
          {
            "code": "price",
            "description": "Стоимость в коинах перехода от предыдущего статуса",
            "type": "integer",
            "restrictions": {
              "min_value": 0
            }
          }
        ]
      },
      "change_recreation_status_price": {
        "code": "change_status_price",
        "name": "Изменить стоимость статусов развлечений",
        "disabled": false,
        "params": "recreation",
        "user_params": [
          {
            "code": "index",
            "description": "Статус (1 - бронза, 2 - серебро, 3 - золото)",
            "type": "integer",
            "restrictions": {
              "min_value": 1,
              "max_value": 3
            }
          },
          {
            "code": "price",
            "description": "Стоимость в коинах перехода от предыдущего статуса",
            "type": "integer",
            "restrictions": {
              "min_value": 0
            }
          }
        ]
      },
      "change_police_status_price": {
        "code": "change_status_price",
        "name": "Изменить стоимость статусов полиции",
        "disabled": false,
        "params": "police",
        "user_params": [
          {
            "code": "index",
            "description": "Статус (1 - бронза, 2 - серебро, 3 - золото)",
            "type": "integer",
            "restrictions": {
              "min_value": 1,
              "max_value": 3
            }
          },
          {
            "code": "price",
            "description": "Стоимость в коинах перехода от предыдущего статуса",
            "type": "integer",
            "restrictions": {
              "min_value": 0
            }
          }
        ]
      },
      "change_administrative_services_status_price": {
        "code": "change_status_price",
        "name": "Изменить стоимость статусов адм. обслуживания",
        "disabled": false,
        "params": "administrative_services",
        "user_params": [
          {
            "code": "index",
            "description": "Статус (1 - бронза, 2 - серебро, 3 - золото)",
            "type": "integer",
            "restrictions": {
              "min_value": 1,
              "max_value": 3
            }
          },
          {
            "code": "price",
            "description": "Стоимость в коинах перехода от предыдущего статуса",
            "type": "integer",
            "restrictions": {
              "min_value": 0
            }
          }
        ]
      }
    }';
end;
$$
language plpgsql;
