# Nabila Food

## Supabase setup

1. Create a user in the Supabase project's **Authentication → Users** page.
   The app signs in with that user's email and password; there is no public
   sign-up flow.
2. Run [`supabase/schema.sql`](supabase/schema.sql) in the Supabase SQL Editor.
   It creates the profile, materials, products, production-batch, and activity
   log tables with row-level security policies scoped to the signed-in user.
   Triggers record each insert, update, and delete on the app's data tables.
   Re-run the script after pulling schema changes.
3. Configure the project URL and publishable key in
   [`lib/data/supabase_config.dart`](lib/data/supabase_config.dart). The
   publishable key is intended for client apps; never put a service-role key
   in the Flutter application.
4. Run `flutter pub get`, then `flutter run`.

## Vercel deployment

Keep the Vercel project root set to this repository's root. The included
[`vercel.json`](vercel.json) builds Flutter Web and publishes `build/web`,
and redirects the old `/dashboard.html` URL to the Flutter app. The build
script installs Flutter 3.47.4 when it is not already available.

The app persists admin profiles, materials, products, production batches,
activity history, and product/admin/production photos. Dashboard summary
counters and oven/fermentation presentation data are not stored in Supabase.
The Products page can import five starter recipes into the signed-in user's
account. Re-run `supabase/schema.sql` before importing so the `recipe_yield`
column is present; the import skips recipes whose names already exist.
Product recipes now use the signed-in user's materials marked for recipe use.
Recipe quantities can use Kg/Gram or Liter/mL for compatible inventory items;
Pcs remains item-based. Starting a production record converts recipe amounts
to the inventory unit and scales them to the production count. Set the full
recipe output in kg and each retail piece/package weight in grams on the
product. The usage ratio is
`produced pcs * grams per piece / (full recipe kg * 1000)`.
Consumption is atomic; insufficient stock rejects the batch, and deleting
the batch restores the recorded usage. The product's daily batch limit is
enforced per production date; target and actual output are both measured in
pcs and do not count as batch totals.
Re-run `supabase/schema.sql` to add the recipe-item fields and stock-safe
production functions before using this flow. Edit previously imported starter
recipes to link their text ingredients to inventory materials and enter the
per-batch quantities before selecting them in production.
