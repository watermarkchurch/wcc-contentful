CREATE TABLE IF NOT EXISTS contentful_raw (
  id varchar PRIMARY KEY,
  data jsonb,
  links text[]
);
ALTER TABLE contentful_raw ADD COLUMN IF NOT EXISTS links text[];
CREATE INDEX IF NOT EXISTS contentful_raw_value_type ON contentful_raw ((data->'sys'->>'type'));
CREATE INDEX IF NOT EXISTS contentful_raw_value_content_type ON contentful_raw ((data->'sys'->'contentType'->'sys'->>'id'));

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

CREATE MATERIALIZED VIEW IF NOT EXISTS contentful_raw_includes_ids_jointable AS
  WITH RECURSIVE includes (root_id, depth) AS (
    SELECT t.id as root_id, 0, t.id, t.links FROM contentful_raw t
    UNION ALL
      SELECT l.root_id, l.depth + 1, r.id, r.links
      FROM includes l, contentful_raw r
      WHERE r.id = ANY(l.links) AND l.depth < 5
  )
  SELECT DISTINCT root_id as id, id as included_id
    FROM includes;

CREATE INDEX IF NOT EXISTS contentful_raw_includes_ids_jointable_id ON contentful_raw_includes_ids_jointable (id);
CREATE UNIQUE INDEX IF NOT EXISTS contentful_raw_includes_ids_jointable_id_included_id ON contentful_raw_includes_ids_jointable (id, included_id);

CREATE OR REPLACE VIEW contentful_raw_includes AS
  SELECT t.id, t.data, array_remove(array_agg(r_incl.data), NULL) as includes
    FROM contentful_raw t
    LEFT JOIN contentful_raw_includes_ids_jointable incl ON t.id = incl.id
    LEFT JOIN contentful_raw r_incl ON r_incl.id = incl.included_id
    GROUP BY t.id, t.data;