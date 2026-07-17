const Product = require('../models/product');

async function upsertCatalog(items) {
  if (!Array.isArray(items) || items.length === 0) {
    return 0;
  }

  let upserted = 0;

  for (const item of items) {
    const sku = item.sku || item.id;
    const title = item.title;
    const price = Number(item.price);
    const imageUrl = item.imageUrl || '';
    const stock = item.stock !== undefined ? Number(item.stock) : 10;

    if (!sku || !title || !Number.isFinite(price)) continue;

    await Product.findOneAndUpdate(
      { sku },
      { sku, title, price, imageUrl, stock },
      { upsert: true, returnDocument: 'after', setDefaultsOnInsert: true },
    );
    upserted += 1;
  }

  return upserted;
}

async function seedCatalogToDb(items) {
  await Product.deleteMany({
    sku: { $exists: false },
    title: { $in: ['book', 'pen'] },
  });

  const count = await upsertCatalog(items);
  const products = await Product.find().sort({ title: 1 });
  return { count, products };
}

module.exports = { seedCatalogToDb, upsertCatalog };
