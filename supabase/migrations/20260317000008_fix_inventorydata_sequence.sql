-- Fix inventorydata id sequence so new inserts get ids > MAX(id).
-- Run this if you see "duplicate key value violates unique constraint inventorydata_pkey" (e.g. Key (id)=(1) already exists).

SELECT setval(
  pg_get_serial_sequence('public.inventorydata', 'id'),
  COALESCE((SELECT MAX(id) FROM public.inventorydata), 1)
);
