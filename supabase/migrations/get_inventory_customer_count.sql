-- ============================================================
-- Count distinct customers that have inventory data.
-- Used by dashboard to show "customers with inventory" without
-- transferring rows (single fast RPC, no loading time issue).
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_inventory_customer_count()
RETURNS bigint
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT COUNT(DISTINCT customer_id)::bigint
  FROM public.inventorydata
  WHERE customer_id IS NOT NULL;
$$;

COMMENT ON FUNCTION public.get_inventory_customer_count() IS 'Returns count of distinct customer_id in inventorydata for dashboard.';

GRANT EXECUTE ON FUNCTION public.get_inventory_customer_count() TO authenticated;
