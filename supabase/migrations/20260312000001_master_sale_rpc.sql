-- ============================================================
-- Drop old per-step helper functions (replaced by master RPC)
-- ============================================================
DROP FUNCTION IF EXISTS get_distinct_vins(integer);
DROP FUNCTION IF EXISTS get_vins_with_sale_tag_date(integer);
DROP FUNCTION IF EXISTS get_last_entry_dates(integer, text[]);
DROP FUNCTION IF EXISTS get_sale_tag_today_vins(integer, text[], date);
DROP FUNCTION IF EXISTS get_latest_inventory_records(integer, text[]);


-- ============================================================
-- Master RPC: builds the full saleprocessedvins payload for ONE
-- dealer entirely inside Postgres, then bulk-inserts it.
-- Returns the count of rows inserted.
--
-- This avoids ALL PostgREST row-count caps and all round-trips.
-- ============================================================
CREATE OR REPLACE FUNCTION process_dealer_sales(
  p_customer_id integer,
  p_todate      date
)
RETURNS integer          -- rows inserted
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_inserted      integer := 0;
  v_stag_inserted integer := 0;
BEGIN

  -- ── Step 1: Actually-sold VINs ────────────────────────────────────────────
  -- A VIN is "sold" if its last pull_date for this dealer is before p_todate.
  -- sold_date  = last_pull_date + 1 day
  -- stag_first_date = earliest pull_date where sale_tag was set (if any)
  -- final_sold_date = MIN(sold_date, stag_first_date)
  -- days_delay      = sold_date - stag_first_date  (0 if no stag)

  WITH last_dates AS (
    -- max pull_date per vin (case-insensitive grouping)
    SELECT LOWER(vin) AS lvin,
           MAX(pull_date) AS last_pull_date
    FROM   inventorydata
    WHERE  customer_id = p_customer_id
      AND  vin IS NOT NULL AND vin <> ''
    GROUP  BY LOWER(vin)
    HAVING MAX(pull_date) < p_todate          -- not seen today → sold
  ),
  stag_dates AS (
    -- earliest pull_date where sale_tag was set, per vin
    SELECT LOWER(vin) AS lvin,
           MIN(pull_date) AS stag_first_date
    FROM   inventorydata
    WHERE  customer_id = p_customer_id
      AND  vin IS NOT NULL AND vin <> ''
      AND  sale_tag IS NOT NULL AND sale_tag <> ''
    GROUP  BY LOWER(vin)
  ),
  sold_vins AS (
    SELECT ld.lvin,
           (ld.last_pull_date + INTERVAL '1 day')::date          AS sold_date,
           sd.stag_first_date
    FROM   last_dates ld
    LEFT JOIN stag_dates sd ON sd.lvin = ld.lvin
  ),
  latest_records AS (
    -- one row per vin: the record with the highest pull_date
    SELECT DISTINCT ON (LOWER(vin))
           id, LOWER(vin) AS lvin, customer_id, pull_date, pull_date_time,
           condition, year, model, vin AS orig_vin, advertiser, location,
           price, trim, custom_make, custom_type_2,
           color, description, doors, drivetrain, formatted_price, fuel_type,
           image_type, image_url, mileage, title, transmission, type, url,
           vehicle_type, custom_label_0, custom_label_1, custom_label_2,
           custom_label_3, custom_label_4, custom_type, rv_type, rv_category,
           rv_class, category, motorhome_class, custom_condition, sale_tag,
           custom_model, custom_trim
    FROM   inventorydata
    WHERE  customer_id = p_customer_id
      AND  vin IS NOT NULL AND vin <> ''
    ORDER  BY LOWER(vin), pull_date DESC
  )
  INSERT INTO saleprocessedvins (
    customer_id, pull_date, pull_date_time, condition, year, model, vin,
    advertiser, location, price, trim, custom_make, custom_type_2,
    color, description, doors, drivetrain, formatted_price, fuel_type,
    image_type, image_url, mileage, title, transmission, type, url,
    vehicle_type, custom_label_0, custom_label_1, custom_label_2,
    custom_label_3, custom_label_4, custom_type, rv_type, rv_category,
    rv_class, category, motorhome_class, custom_condition, sale_tag,
    sold_date, stag_first_date, days_delay, final_sold_date,
    custom_model, custom_trim
  )
  SELECT
    lr.customer_id,
    lr.pull_date,
    lr.pull_date_time,
    lr.condition,
    lr.year,
    lr.model,
    lr.lvin                                                          AS vin,
    lr.advertiser,
    lr.location,
    COALESCE(NULLIF(TRIM(lr.price::text), ''), '0')::numeric          AS price,
    lr.trim,
    lr.custom_make,
    lr.custom_type_2,
    lr.color, lr.description, lr.doors, lr.drivetrain,
    lr.formatted_price, lr.fuel_type, lr.image_type, lr.image_url,
    lr.mileage, lr.title, lr.transmission, lr.type, lr.url,
    lr.vehicle_type,
    lr.custom_label_0, lr.custom_label_1, lr.custom_label_2,
    lr.custom_label_3, lr.custom_label_4,
    lr.custom_type, lr.rv_type, lr.rv_category, lr.rv_class,
    lr.category, lr.motorhome_class, lr.custom_condition, lr.sale_tag,
    sv.sold_date,
    sv.stag_first_date,
    CASE
      WHEN sv.stag_first_date IS NOT NULL
      THEN (sv.sold_date - sv.stag_first_date)
      ELSE 0
    END                                                              AS days_delay,
    CASE
      WHEN sv.stag_first_date IS NOT NULL
      THEN LEAST(sv.sold_date, sv.stag_first_date)
      ELSE sv.sold_date
    END                                                              AS final_sold_date,
    lr.custom_model,
    lr.custom_trim
  FROM   sold_vins sv
  JOIN   latest_records lr ON lr.lvin = sv.lvin;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;


  -- ── Step 2: Sale-tag-only VINs ────────────────────────────────────────────
  -- VINs that are still in today's inventory (NOT actually sold) but carry a
  -- sale_tag today.  Exclude VINs already inserted in step 1.

  WITH already_inserted AS (
    SELECT vin FROM saleprocessedvins WHERE customer_id = p_customer_id
  ),
  stag_today AS (
    SELECT DISTINCT ON (LOWER(vin))
           LOWER(vin) AS lvin, customer_id, pull_date, pull_date_time,
           condition, year, model, advertiser, location, price, trim,
           custom_make, custom_type_2, color, description, doors, drivetrain,
           formatted_price, fuel_type, image_type, image_url, mileage, title,
           transmission, type, url, vehicle_type,
           custom_label_0, custom_label_1, custom_label_2,
           custom_label_3, custom_label_4,
           custom_type, rv_type, rv_category, rv_class, category,
           motorhome_class, custom_condition, sale_tag, custom_model, custom_trim
    FROM   inventorydata
    WHERE  customer_id = p_customer_id
      AND  pull_date   = p_todate
      AND  vin IS NOT NULL AND vin <> ''
      AND  sale_tag IS NOT NULL AND sale_tag <> ''
      AND  LOWER(vin) NOT IN (SELECT vin FROM already_inserted)
    ORDER  BY LOWER(vin), pull_date DESC
  ),
  stag_first AS (
    SELECT LOWER(vin) AS lvin,
           MIN(pull_date) AS stag_first_date
    FROM   inventorydata
    WHERE  customer_id = p_customer_id
      AND  sale_tag IS NOT NULL AND sale_tag <> ''
    GROUP  BY LOWER(vin)
  )
  INSERT INTO saleprocessedvins (
    customer_id, pull_date, pull_date_time, condition, year, model, vin,
    advertiser, location, price, trim, custom_make, custom_type_2,
    color, description, doors, drivetrain, formatted_price, fuel_type,
    image_type, image_url, mileage, title, transmission, type, url,
    vehicle_type, custom_label_0, custom_label_1, custom_label_2,
    custom_label_3, custom_label_4, custom_type, rv_type, rv_category,
    rv_class, category, motorhome_class, custom_condition, sale_tag,
    sold_date, stag_first_date, days_delay, final_sold_date,
    custom_model, custom_trim
  )
  SELECT
    st.customer_id,
    st.pull_date,
    st.pull_date_time,
    st.condition, st.year, st.model,
    st.lvin                     AS vin,
    st.advertiser, st.location,
    COALESCE(NULLIF(TRIM(st.price::text), ''), '0')::numeric,
    st.trim, st.custom_make, st.custom_type_2,
    st.color, st.description, st.doors, st.drivetrain,
    st.formatted_price, st.fuel_type, st.image_type, st.image_url,
    st.mileage, st.title, st.transmission, st.type, st.url,
    st.vehicle_type,
    st.custom_label_0, st.custom_label_1, st.custom_label_2,
    st.custom_label_3, st.custom_label_4,
    st.custom_type, st.rv_type, st.rv_category, st.rv_class,
    st.category, st.motorhome_class, st.custom_condition, st.sale_tag,
    NULL::date                  AS sold_date,
    sf.stag_first_date,
    0                           AS days_delay,
    sf.stag_first_date          AS final_sold_date,
    st.custom_model, st.custom_trim
  FROM   stag_today st
  LEFT JOIN stag_first sf ON sf.lvin = st.lvin;

  GET DIAGNOSTICS v_stag_inserted = ROW_COUNT;
  v_inserted := v_inserted + v_stag_inserted;

  RETURN v_inserted;
END;
$$;


-- ============================================================
-- Convenience: count rows in saleprocessedvins
-- ============================================================
CREATE OR REPLACE FUNCTION get_saleprocessedvins_count()
RETURNS bigint LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT COUNT(*) FROM saleprocessedvins;
$$;


-- ============================================================
-- Convenience: TRUNCATE saleprocessedvins (needs SECURITY DEFINER
-- because edge functions run as anon/service role)
-- ============================================================
CREATE OR REPLACE FUNCTION truncate_saleprocessedvins()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  TRUNCATE TABLE saleprocessedvins;
END;
$$;
