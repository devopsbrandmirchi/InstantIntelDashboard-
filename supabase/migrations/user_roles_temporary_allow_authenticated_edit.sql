-- ============================================================
-- TEMPORARY: Allow any authenticated user to insert/update/delete user_roles
-- so you can assign the admin role to any user from User Management.
-- REMOVE THIS POLICY when done: run the "Revert" block at the bottom.
-- Run in: Supabase Dashboard → SQL Editor
-- ============================================================

DROP POLICY IF EXISTS "user_roles_temporary_allow_authenticated_edit" ON public.user_roles;
CREATE POLICY "user_roles_temporary_allow_authenticated_edit"
  ON public.user_roles
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- ============================================================
-- REVERT (run this when you want to restore admin-only editing):
-- ============================================================
/*
DROP POLICY IF EXISTS "user_roles_temporary_allow_authenticated_edit" ON public.user_roles;
*/
