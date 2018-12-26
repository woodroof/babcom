-- drop type api_utils.output_message_type;

create type api_utils.output_message_type as enum(
  'actors',
  'diff',
  'go_back',
  'object');
