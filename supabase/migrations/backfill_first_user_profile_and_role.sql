-- ============================================================
-- One-time backfill for users created BEFORE the signup trigger.
-- Creates missing profiles and assigns a role so the app works.
-- Run once in: Supabase Dashboard → SQL Editor
-- ============================================================

-- 1. Create profiles for any auth users that don't have one
INSERT INTO public.profiles (id, email, full_name)
SELECT
  u.id,
  u.email,
  COALESCE(u.raw_user_meta_data->>'full_name', split_part(u.email, '@', 1), 'User')
FROM auth.users u
WHERE NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = u.id);

-- 2. Assign role to any profile that has no row in user_roles
--    Uses 'admin' (role_id 1) so the first user can access User Management.
--    Change to role_id = 4 for 'viewer' if you prefer.
INSERT INTO public.user_roles (user_id, role_id)
SELECT p.id, 1
FROM public.profiles p
WHERE NOT EXISTS (
  SELECT 1 FROM public.user_roles ur WHERE ur.user_id = p.id
);
