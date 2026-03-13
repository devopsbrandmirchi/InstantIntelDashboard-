-- ============================================================
-- Allow authenticated users to manage roles (Role Management page).
-- Run in: Supabase Dashboard → SQL Editor
-- ============================================================

DROP POLICY IF EXISTS "roles_insert_authenticated" ON public.roles;
CREATE POLICY "roles_insert_authenticated"
  ON public.roles FOR INSERT
  TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "roles_update_authenticated" ON public.roles;
CREATE POLICY "roles_update_authenticated"
  ON public.roles FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "roles_delete_authenticated" ON public.roles;
CREATE POLICY "roles_delete_authenticated"
  ON public.roles FOR DELETE
  TO authenticated
  USING (true);

GRANT INSERT, UPDATE, DELETE ON public.roles TO authenticated;
