BEGIN TRANSACTION;
CREATE TABLE albums (
  id integer,
  card_uuid string,
  button_number integer,
  album_name string,
  listen_count integer
);
COMMIT;
  