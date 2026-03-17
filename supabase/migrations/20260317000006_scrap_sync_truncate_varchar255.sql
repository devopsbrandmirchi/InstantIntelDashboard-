-- Fix: value too long for type character varying(255)
-- Truncate all string values to 255 chars in the sync function so INSERT never fails.

CREATE OR REPLACE FUNCTION public.run_normalized_inventory_from_scrap(p_date date DEFAULT CURRENT_DATE)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_inserted bigint;
  v_pull_ts  timestamptz := clock_timestamp();
BEGIN
  IF p_date IS NULL THEN
    p_date := CURRENT_DATE;
  END IF;

  INSERT INTO public.normalized_inventory_from_scrap (
    customer_id, track_date, pull_date, pull_date_time,
    "condition", year, make, model, vin, advertiser, color, description,
    doors, drivetrain, formatted_price, fuel_type, image_type, image_url,
    location, mileage, price, title, transmission, trim, type, url, vehicle_type,
    custom_label_0, custom_label_1, custom_label_2, custom_label_3, custom_label_4,
    custom_type, rv_type, rv_category, rv_class, category, motorhome_class,
    custom_make, custom_type_2, custom_condition, cms, sale_tag, stock_number, msrp,
    custom_model, custom_trim
  )
  SELECT
    c.id,
    r.creation_date,
    r.creation_date,
    v_pull_ts,
    LEFT(COALESCE(r.condition_, '')::text, 255),
    LEFT(COALESCE(r.year_, '')::text, 255),
    LEFT(COALESCE(r.make, '')::text, 255),
    LEFT(COALESCE(r.model, '')::text, 255),
    LEFT(COALESCE(r.vin, '')::text, 255),
    LEFT(COALESCE(r.dealer_url, '')::text, 255),
    LEFT(COALESCE(r.exterior_color, '')::text, 255),
    LEFT(COALESCE(r.description, '')::text, 255),
    LEFT(COALESCE(r.doors, '')::text, 255),
    LEFT(COALESCE(r.drivetrain, '')::text, 255),
    LEFT(COALESCE(r.price, '')::text, 255),
    LEFT(COALESCE(r.fuel_type, '')::text, 255),
    ''::varchar(255),
    LEFT(COALESCE(r.image_url, '')::text, 255),
    LEFT(
      CASE
        WHEN c.id IN (143, 144, 145, 146, 147, 150, 151) THEN 'Location one'
        ELSE COALESCE(REPLACE(r.location, ',', ''), '')
      END::text,
      255
    ),
    LEFT(TRIM(COALESCE(r.mileage_value, '') || ' ' || COALESCE(r.mileage_unit, ''))::text, 255),
    LEFT(COALESCE(NULLIF(TRIM(REGEXP_REPLACE(COALESCE(r.price, ''), '[,$]', '', 'g')), ''), '0.00')::text, 255),
    LEFT(COALESCE(r.title, '')::text, 255),
    LEFT(COALESCE(r.transmission, '')::text, 255),
    LEFT(COALESCE(r.trim, '')::text, 255),
    LEFT(COALESCE(r.type_, '')::text, 255),
    LEFT(COALESCE(r.url, '')::text, 255),
    ''::varchar(255),
    LEFT(COALESCE(r.custom_label_0, '')::text, 255),
    LEFT(COALESCE(r.custom_label_1, '')::text, 255),
    LEFT(COALESCE(r.custom_label_2, '')::text, 255),
    ''::varchar(255),
    ''::varchar(255),
    LEFT(TRIM(COALESCE(r.type_, '') || CASE WHEN COALESCE(TRIM(r.sub_type), '') <> '' THEN ' ' || r.sub_type ELSE '' END)::text, 255),
    ''::varchar(255),
    ''::varchar(255),
    ''::varchar(255),
    LEFT(COALESCE(r.sub_type, '')::text, 255),
    ''::varchar(255),
    LEFT(COALESCE((SELECT cm.custom_make_text FROM public.custommaketext cm WHERE LOWER(TRIM(COALESCE(r.make, ''))) = LOWER(cm.make_text) LIMIT 1), '')::text, 255),
    LEFT(COALESCE((SELECT ct.custom_type_text FROM public.customtypetext ct
      WHERE LOWER(TRIM(COALESCE(r.type_, '') || CASE WHEN COALESCE(TRIM(r.sub_type), '') <> '' THEN ' ' || r.sub_type ELSE '' END)) = LOWER(ct.type_text) LIMIT 1), '')::text, 255),
    LEFT(COALESCE((SELECT cc.custom_condition_text FROM public.customconditiontext cc
      WHERE LOWER(TRIM(COALESCE(r.condition_, ''))) = LOWER(cc.condition_text) LIMIT 1), '')::text, 255),
    LEFT(COALESCE(r.cms, '')::text, 255),
    LEFT(COALESCE(r.special_tag, '')::text, 255),
    LEFT(COALESCE(r.stock_number, '')::text, 255),
    LEFT(COALESCE(r.msrp, '')::text, 255),
    LEFT(COALESCE((SELECT cmt.custom_model FROM public.custom_model_trim cmt
      WHERE LOWER(TRIM(COALESCE(r.model, ''))) = LOWER(TRIM(COALESCE(cmt.model, '')))
        AND LOWER(TRIM(COALESCE(r.trim, ''))) = LOWER(TRIM(COALESCE(cmt.trim, '')))
        AND LOWER(TRIM(COALESCE(r.title, ''))) = LOWER(TRIM(COALESCE(cmt.title, ''))) LIMIT 1), '')::text, 255),
    LEFT(COALESCE((SELECT cmt.custom_trim FROM public.custom_model_trim cmt
      WHERE LOWER(TRIM(COALESCE(r.model, ''))) = LOWER(TRIM(COALESCE(cmt.model, '')))
        AND LOWER(TRIM(COALESCE(r.trim, ''))) = LOWER(TRIM(COALESCE(cmt.trim, '')))
        AND LOWER(TRIM(COALESCE(r.title, ''))) = LOWER(TRIM(COALESCE(cmt.title, ''))) LIMIT 1), '')::text, 255)
  FROM public.scrap_rawdata r
  INNER JOIN public.clients c
    ON c.dealership_name IS NOT NULL AND TRIM(c.dealership_name) <> ''
   AND c.is_active = TRUE
   AND c.dealership_name = r.dealership_name
  WHERE r.creation_date = p_date
  ON CONFLICT (customer_id, pull_date, vin, url) DO NOTHING;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;
  RETURN jsonb_build_object('date', p_date, 'rows_inserted', v_inserted, 'status', 'ok');
END;
$$;

COMMENT ON FUNCTION public.run_normalized_inventory_from_scrap(date) IS 'Syncs scrap_rawdata into normalized_inventory_from_scrap. All string values truncated to 255 chars to avoid varchar(255) overflow.';
