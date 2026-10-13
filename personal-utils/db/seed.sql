-- PostgreSQL. Synthetic data only.
-- @@HASH_A@@ / @@HASH_B@@ / @@HASH_C@@ are replaced by setup.sh.

-- ---------- PRODUCTS (20 SKUs) ----------
INSERT INTO products (sku, name, price_ngn, stock, keywords) VALUES
('SKU-001', 'Ceramic Vase',             15000, 12, 'planter flower pot'),
('SKU-002', 'Glass Vase',                9500,  8, 'flower vase bottle'),
('SKU-003', 'Tall Floor Vase',          32000,  3, 'large vase decor'),
('SKU-004', 'Scented Candle Set',       12000, 25, 'candles fragrance'),
('SKU-005', 'Throw Pillow Cover',        6500, 40, 'cushion cover pillowcase'),
('SKU-006', 'Linen Table Runner',        8500, 15, 'table cloth runner'),
('SKU-007', 'Woven Storage Basket',     11000, 10, 'basket organiser'),
('SKU-008', 'Ceramic Dinner Plate Set', 28000,  6, 'plates dinnerware'),
('SKU-009', 'Round Wall Mirror',        45000,  2, 'mirror decor'),
('SKU-010', 'Brass Table Lamp',         38000,  0, 'lamp light'),          -- out of stock
('SKU-011', 'Bath Towel Set',           18000, 20, 'towels'),
('SKU-012', 'Leather Tote Bag',         35000,  9, 'handbag bag purse'),
('SKU-013', 'Beaded Necklace',           7500, 30, 'jewelry jewellery'),
('SKU-014', 'Silk Scarf',                9000, 18, 'headscarf scarf'),
('SKU-015', 'Ankara Print Clutch',      14000, 11, 'clutch purse bag'),    -- "bag" overlaps SKU-012
('SKU-016', 'Brass Bracelet',            6000, 35, 'bangle jewelry'),
('SKU-017', 'Canvas Wall Art',          22000,  7, 'painting frame art'),
('SKU-018', 'Cotton Bedsheet Set',      26000, 14, 'bedding bed sheets'),
('SKU-019', 'Woven Rug',                42000,  4, 'carpet mat'),
('SKU-020', 'Wooden Serving Tray',      13500, 16, 'tray');

-- ---------- CONTACTS (fake numbers; the simulated outbox needs a recipient) ----------
INSERT INTO contacts (phone_hash, wa_phone, first_seen, last_seen) VALUES
('@@HASH_A@@', '2348011112222', now() - interval '10 days', now() - interval '1 day'),
('@@HASH_B@@', '2348033334444', now() - interval '4 days',  now() - interval '2 days'),
('@@HASH_C@@', '2348055556666', now() - interval '6 days',  now() - interval '1 day');

-- ---------- ORDERS (6 synthetic, 3 customers) ----------
INSERT INTO orders (order_id, phone_hash, status, items_json, total_ngn, delivery_zone, address,
                    customer_name, created_at, updated_at) VALUES
('ZH-10001', '@@HASH_A@@', 'awaiting_payment',
  '[{"sku":"SKU-001","name":"Ceramic Vase","qty":1,"unit_price":15000}]', 18500, 'Lagos',
  '12 Admiralty Way, Lekki Phase 1, Lagos', 'Ada Test',
  now() - interval '1 day', now() - interval '1 day'),

('ZH-10002', '@@HASH_A@@', 'delivered',
  '[{"sku":"SKU-006","name":"Linen Table Runner","qty":2,"unit_price":8500}]', 20500, 'Lagos',
  '12 Admiralty Way, Lekki Phase 1, Lagos', 'Ada Test',
  now() - interval '10 days', now() - interval '7 days'),

('ZH-10003', '@@HASH_B@@', 'processing',
  '[{"sku":"SKU-012","name":"Leather Tote Bag","qty":1,"unit_price":35000}]', 40500, 'Abuja',
  '5 Aminu Kano Crescent, Wuse 2, Abuja', 'Bola Sample',
  now() - interval '2 days', now() - interval '1 day'),

('ZH-10004', '@@HASH_B@@', 'dispatched',
  '[{"sku":"SKU-011","name":"Bath Towel Set","qty":1,"unit_price":18000}]', 23500, 'Abuja',
  '5 Aminu Kano Crescent, Wuse 2, Abuja', 'Bola Sample',
  now() - interval '4 days', now() - interval '2 days'),

('ZH-10005', '@@HASH_C@@', 'paid_confirmed',
  '[{"sku":"SKU-009","name":"Round Wall Mirror","qty":1,"unit_price":45000}]', 50500, 'Port Harcourt',
  '8 Aba Road, GRA, Port Harcourt', 'Chidi Demo',
  now() - interval '1 day', now() - interval '6 hours'),

('ZH-10006', '@@HASH_C@@', 'cancelled',
  '[{"sku":"SKU-014","name":"Silk Scarf","qty":3,"unit_price":9000}]', 32500, 'Port Harcourt',
  '8 Aba Road, GRA, Port Harcourt', 'Chidi Demo',
  now() - interval '6 days', now() - interval '5 days');