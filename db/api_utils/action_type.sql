-- drop type api_utils.action_type;

create type api_utils.action_type as enum(
  'go_back',
  'open_object',
  'show_message');
