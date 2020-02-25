START TRANSACTION;

  -- Convert a jsonb array or jsonb value to a jsonb array 
  CREATE or replace FUNCTION "fn_contentful_jsonb_any_to_jsonb_array"(potential_arr jsonb) RETURNS jsonb AS $$
  DECLARE
    result jsonb;
  BEGIN
    SELECT
      CASE 
        WHEN jsonb_typeof(potential_arr) = 'array' THEN potential_arr
        ELSE jsonb_build_array(potential_arr)
      END
      INTO result;
    RETURN result;
  END;
  $$ LANGUAGE 'plpgsql';


  INSERT INTO wcc_contentful_schema_version
    VALUES (2);
COMMIT;
