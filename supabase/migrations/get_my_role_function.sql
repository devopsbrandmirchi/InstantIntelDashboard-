-- ============================================================
-- Get current user's role in one RPC call (avoids RLS timeout).
-- Run in: Supabase Dashboard → SQL Editor
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT LOWER(r.name)
  FROM public.user_roles ur
  JOIN public.roles r ON r.id = ur.role_id
  WHERE ur.user_id = auth.uid()
  ORDER BY CASE WHEN r.name = 'admin' THEN 0 ELSE 1 END
  LIMIT 1;
$$;

COMMENT ON FUNCTION public.get_my_role() IS 'Returns the current user role name (e.g. admin, viewer). Used by the app to avoid RLS timeout on user_roles/roles.';

-- Allow authenticated users to call it
GRANT EXECUTE ON FUNCTION public.get_my_role() TO authenticated;
