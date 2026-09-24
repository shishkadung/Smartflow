-- Add Treasury and Office of the Mayor to an existing SmartFlow database.
-- Safe to re-run. Runtime bootstrap also inserts these on the next API request.

INSERT IGNORE INTO offices (name, code) VALUES
  ('Municipal Treasury', 'TRE'),
  ('Office of the Mayor', 'MAY');
