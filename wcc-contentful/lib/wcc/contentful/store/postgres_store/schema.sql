CREATE TABLE IF NOT EXISTS wcc_contentful_schema_version (
  version integer PRIMARY KEY,
  updated_at timestamp DEFAULT now()
);

START TRANSACTION;

CREATE TABLE IF NOT EXISTS contentful_raw (
  -- The Contentful 'sys'->'id'
  id varchar PRIMARY KEY,
  -- The contentful entry
  data jsonb,
  -- Every ID that this entry links to in 'fields'->*->[each locale]->'sys'->'id'
  links text[]
);
CREATE INDEX IF NOT EXISTS contentful_raw_value_type ON contentful_raw ((data->'sys'->>'type'));
CREATE INDEX IF NOT EXISTS contentful_raw_value_content_type ON contentful_raw ((data->'sys'->'contentType'->'sys'->>'id'));

-- Insert or update a Contentful entry by it's ID
CREATE or replace FUNCTION "fn_contentful_upsert_entry"(_id varchar, _data jsonb, _links text[]) RETURNS jsonb AS $$
DECLARE
  prev jsonb;
BEGIN
  SELECT data, links FROM contentful_raw WHERE id = _id INTO prev;
  INSERT INTO contentful_raw (id, data, links) values (_id, _data, _links)
    ON CONFLICT (id) DO
      UPDATE
      SET data = _data,
        links = _links;
  RETURN prev;
END;
$$ LANGUAGE 'plpgsql';

-- Joins the entries table to itself by all the linked entries down to depth 5.
-- Each entry has a row for each downstream entry in it's tree.
-- Example:
--  | id    | included_id | depth |
--  | page1 | page2       | 1     |
--  | page1 | subpage2    | 2     | -- through page2
--  | page1 | asset1      | 1     |
--  | page2 | subpage2    | 1     |
--  ...
CREATE MATERIALIZED VIEW IF NOT EXISTS contentful_raw_includes_ids_jointable AS
  WITH RECURSIVE includes (root_id, depth) AS (
    SELECT t.id as root_id, 0, t.id, t.links FROM contentful_raw t
    UNION ALL
      SELECT l.root_id, l.depth + 1, r.id, r.links
      FROM includes l, contentful_raw r
      WHERE r.id = ANY(l.links) AND l.depth < 5
  )
  SELECT DISTINCT root_id as id, id as included_id, depth
    FROM includes;

CREATE INDEX IF NOT EXISTS contentful_raw_includes_ids_jointable_id ON contentful_raw_includes_ids_jointable (id);
CREATE UNIQUE INDEX IF NOT EXISTS contentful_raw_includes_ids_jointable_id_included_id ON contentful_raw_includes_ids_jointable (id, included_id);

-- Uses the contentful_raw_includes_ids_jointable to join the entries table to itself,
-- aggregating the included entries into an array.
-- Example:
--  | id    | data  | includes                                    |
--  | page1 | jsonb | {page2 jsonb, subpage2 jsonb, asset1 jsonb} |
CREATE OR REPLACE VIEW contentful_raw_includes AS
  SELECT t.id, t.data, array_remove(array_agg(r_incl.data), NULL) as includes
    FROM contentful_raw t
    LEFT JOIN contentful_raw_includes_ids_jointable incl ON t.id = incl.id
    LEFT JOIN contentful_raw r_incl ON r_incl.id = incl.included_id
    GROUP BY t.id, t.data;

INSERT INTO wcc_contentful_schema_version
  VALUES (1);

COMMIT;
