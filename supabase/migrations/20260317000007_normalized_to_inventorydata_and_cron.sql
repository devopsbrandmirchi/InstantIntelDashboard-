-- Transfer from normalized_inventory_from_scrap to inventorydata (like Python script).
-- Only for clients with scrap_feed=1, active_pull=0, is_active=1.
-- Run daily via cron after normalized_inventory_from_scrap sync.

-- ============================================================
-- 1. Client flags for "clients having scrap feed" (scrap_feed=1, active_pull=0)
-- ============================================================
ALTER TABLE public.clients
  ADD COLUMN IF NOT EXISTS scrap_feed  smallint DEFAULT 0,
  ADD COLUMN IF NOT EXISTS active_pull  smallint DEFAULT 0;

COMMENT ON COLUMN public.clients.scrap_feed IS '1 = client has scrap feed and is eligible for normalized -> inventorydata transfer.';
COMMENT ON COLUMN public.clients.active_pull IS '0 = use scrap feed (normalized_inventory_from_scrap); 1 = active pull (other source).';

-- ============================================================
-- 2. Unique constraint on inventorydata for ON CONFLICT DO NOTHING
--    (customer_id, pull_date, vin, url) to avoid duplicates
-- ============================================================
CREATE UNIQUE INDEX IF NOT EXISTS idx_inventorydata_customer_pull_vin_url
  ON public.inventorydata (customer_id, pull_date, vin, url);

-- ============================================================
-- 3. Transfer function: copy normalized_inventory_from_scrap -> inventorydata
--    for given date, only for clients where scrap_feed=1, active_pull=0, is_active=TRUE
-- ============================================================
CREATE OR REPLACE FUNCTION public.run_inventory_from_normalized(p_date date DEFAULT CURRENT_DATE)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_inserted bigint;
BEGIN
  IF p_date IS NULL THEN
    p_date := CURRENT_DATE;
  END IF;

  INSERT INTO public.inventorydata (
    customer_id,
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
    track_date,
    custom_condition,
    cms,
    sale_tag,
    stock_number,
    msrp,
    custom_model,
    custom_trim
  )
  SELECT
    n.customer_id,
    n.pull_date,
    n.pull_date_time,
    LEFT(COALESCE(n."condition", '')::text, 255),
    LEFT(COALESCE(n.year, '')::text, 255),
    LEFT(COALESCE(n.make, '')::text, 255),
    LEFT(COALESCE(n.model, '')::text, 255),
    LEFT(COALESCE(TRIM(n.vin), '')::text, 255),
    LEFT(COALESCE(n.advertiser, '')::text, 255),
    LEFT(COALESCE(n.color, '')::text, 255),
    LEFT(COALESCE(n.description, '')::text, 255),
    LEFT(COALESCE(n.doors, '')::text, 255),
    LEFT(COALESCE(n.drivetrain, '')::text, 255),
    LEFT(COALESCE(n.formatted_price, '')::text, 255),
    LEFT(COALESCE(n.fuel_type, '')::text, 255),
    LEFT(COALESCE(n.image_type, '')::text, 255),
    LEFT(COALESCE(n.image_url, '')::text, 255),
    LEFT(COALESCE(n.location, '')::text, 255),
    LEFT(COALESCE(n.mileage, '')::text, 255),
    LEFT(COALESCE(n.price, '')::text, 255),
    LEFT(COALESCE(n.title, '')::text, 255),
    LEFT(COALESCE(n.transmission, '')::text, 255),
    LEFT(COALESCE(n.trim, '')::text, 255),
    LEFT(COALESCE(n.type, '')::text, 255),
    LEFT(COALESCE(NULLIF(TRIM(n.url), ''), '')::text, 255),
    LEFT(COALESCE(n.vehicle_type, '')::text, 255),
    LEFT(COALESCE(n.custom_label_0, '')::text, 255),
    LEFT(COALESCE(n.custom_label_1, '')::text, 255),
    LEFT(COALESCE(n.custom_label_2, '')::text, 255),
    LEFT(COALESCE(n.custom_label_3, '')::text, 255),
    LEFT(COALESCE(n.custom_label_4, '')::text, 255),
    LEFT(COALESCE(n.custom_type, '')::text, 255),
    LEFT(COALESCE(n.rv_type, '')::text, 255),
    LEFT(COALESCE(n.rv_category, '')::text, 255),
    LEFT(COALESCE(n.rv_class, '')::text, 255),
    LEFT(COALESCE(n.category, '')::text, 255),
    LEFT(COALESCE(n.motorhome_class, '')::text, 255),
    LEFT(COALESCE(n.custom_make, '')::text, 255),
    LEFT(COALESCE(n.custom_type_2, '')::text, 255),
    n.track_date,
    LEFT(COALESCE(n.custom_condition, '')::text, 255),
    LEFT(COALESCE(n.cms, '')::text, 255),
    LEFT(COALESCE(n.sale_tag, '')::text, 255),
    LEFT(COALESCE(n.stock_number, '')::text, 255),
    LEFT(COALESCE(n.msrp, '')::text, 255),
    LEFT(COALESCE(n.custom_model, '')::text, 255),
    LEFT(COALESCE(n.custom_trim, '')::text, 255)
  FROM public.normalized_inventory_from_scrap n
  INNER JOIN public.clients c
    ON c.id = n.customer_id
   AND (CASE WHEN c.is_active IS TRUE THEN 1 WHEN c.is_active IS FALSE THEN 0 ELSE (c.is_active::int) END) = 1
   AND (CASE WHEN c.scrap_feed IS TRUE THEN 1 WHEN c.scrap_feed IS FALSE THEN 0 ELSE COALESCE(c.scrap_feed::int, 0) END) = 1
   AND (CASE WHEN c.active_pull IS TRUE THEN 1 WHEN c.active_pull IS FALSE THEN 0 ELSE COALESCE(c.active_pull::int, 1) END) = 0
  WHERE n.pull_date = p_date
  ON CONFLICT (customer_id, pull_date, vin, url) DO NOTHING;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  RETURN jsonb_build_object(
    'date', p_date,
    'rows_inserted', v_inserted,
    'status', 'ok'
  );
END;
$$;

COMMENT ON FUNCTION public.run_inventory_from_normalized(date) IS 'Copies normalized_inventory_from_scrap into inventorydata for the given date. Only clients with scrap_feed=1, active_pull=0, is_active=TRUE.';

-- ============================================================
-- 4. Grants
-- ============================================================
GRANT EXECUTE ON FUNCTION public.run_inventory_from_normalized(date) TO service_role;
GRANT EXECUTE ON FUNCTION public.run_inventory_from_normalized(date) TO postgres;

-- ============================================================
-- 5. Cron: run after normalized_inventory sync (e.g. 3:00 AM)
-- ============================================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'inventory-from-normalized-daily') THEN
    PERFORM cron.unschedule('inventory-from-normalized-daily');
  END IF;
END $$;

SELECT cron.schedule(
  'inventory-from-normalized-daily',
  '0 3 * * *',
  $$SELECT public.run_inventory_from_normalized(CURRENT_DATE)$$
);
