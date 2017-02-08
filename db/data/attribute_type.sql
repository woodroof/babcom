-- Type: data.attribute_type

-- DROP TYPE data.attribute_type;

CREATE TYPE data.attribute_type AS ENUM
   ('SYSTEM',
    'INVISIBLE',
    'HIDDEN',
    'NORMAL');
