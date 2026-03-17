-- Use existing scrap_rawdata table structure (sk, condition_, year_, type_, price, sub_type, etc.)
-- If migration 002 created a different scrap_rawdata, drop it so your table is the only one.
-- Then replace the sync function to map from your columns into normalized_inventory_from_scrap.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'scrap_rawdata' AND column_name = 'condition'
  ) THEN
    DROP TABLE IF EXISTS public.scrap_rawdata;
  END IF;
END $$;

-- Sync function: map from your scrap_rawdata columns to normalized_inventory_from_scrap
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
    customer_id,
    track_date,
    pull_date,
    pull_date_time,
    "condition",
    year,
    make,
    model,
    vin,
    advertiser,
    color,
    description,
    doors,
    drivetrain,
    formatted_price,
    fuel_type,
    image_type,
    image_url,
    location,
    mileage,
    price,
    title,
    transmission,
    trim,
    type,
    url,
    vehicle_type,
    custom_label_0,
    custom_label_1,
    custom_label_2,
    custom_label_3,
    custom_label_4,
    custom_type,
    rv_type,
    rv_category,
    rv_class,
    category,
    motorhome_class,
    custom_make,
    custom_type_2,
    custom_condition,
    cms,
    sale_tag,
    stock_number,
    msrp,
    custom_model,
    custom_trim
  )
  SELECT
    m.client_id,
    r.creation_date,
    r.creation_date,
    v_pull_ts,
    r.condition_,
    r.year_,
    r.make,
    r.model,
    r.vin,
    COALESCE(r.dealer_url, '')::varchar(255),
    COALESCE(r.exterior_color, '')::varchar(255),
    r.description,
    r.doors,
    r.drivetrain,
    r.price,
    r.fuel_type,
    ''::varchar(255),
    r.image_url,
    CASE
      WHEN m.client_id IN (143, 144, 145, 146, 147, 150, 151) THEN 'Location one'
      ELSE COALESCE(REPLACE(r.location, ',', ''), '')
    END,
    TRIM(COALESCE(r.mileage_value, '') || ' ' || COALESCE(r.mileage_unit, ''))::varchar(255),
    COALESCE(
      NULLIF(TRIM(REGEXP_REPLACE(COALESCE(r.price, ''), '[,$]', '', 'g')), ''),
      '0.00'
    )::varchar(255),
    r.title,
    r.transmission,
    r.trim,
    r.type_,
    COALESCE(r.url, '')::varchar(255),
    ''::varchar(255),
    r.custom_label_0,
    r.custom_label_1,
    r.custom_label_2,
    ''::varchar(255),
    ''::varchar(255),
    r.type_,
    ''::varchar(255),
    ''::varchar(255),
    ''::varchar(255),
    r.sub_type,
    ''::varchar(255),
    r.make,
    r.type_,
    r.condition_,
    r.cms,
    r.special_tag,
    r.stock_number,
    r.msrp,
    r.model,
    r.trim
  FROM public.scrap_rawdata r
  INNER JOIN public.client_dealership_mapping m ON m.dealership_name = r.dealership_name
  WHERE r.creation_date = p_date
  ON CONFLICT (customer_id, pull_date, vin, url) DO NOTHING;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  RETURN jsonb_build_object(
    'date', p_date,
    'rows_inserted', v_inserted,
    'status', 'ok'
  );
END;
$$;

COMMENT ON FUNCTION public.run_normalized_inventory_from_scrap(date) IS 'Syncs scrap_rawdata (creation_date + dealership_name) into normalized_inventory_from_scrap. Uses existing scrap_rawdata columns: condition_, year_, type_, price, sub_type, mileage_value, mileage_unit, exterior_color, special_tag, etc.';
