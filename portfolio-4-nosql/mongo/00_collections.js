// OjaHub Marketplace: MongoDB collections with schema validation
// Validators are created before the import, so every migrated document is checked on the way in.

db = db.getSiblingDB("ojahub");
db.dropDatabase();

const intType = { bsonType: ["int", "long"] };

db.createCollection("categories", {
  validator: { $jsonSchema: {
    bsonType: "object",
    required: ["_id", "name"],
    properties: { name: { bsonType: "string", minLength: 1 } }
  } }
});

db.createCollection("products", {
  validator: { $jsonSchema: {
    bsonType: "object",
    required: ["_id", "name", "price", "stock_qty", "is_active", "category", "seller", "attributes", "rating"],
    properties: {
      name: { bsonType: "string", minLength: 1 },
      price: { bsonType: "decimal", minimum: 0.01 },
      stock_qty: { ...intType, minimum: 0 },
      is_active: { bsonType: "bool" },
      category: { bsonType: "object", required: ["id", "name"] },
      seller: { bsonType: "object", required: ["seller_id", "business_name"] },
      attributes: { bsonType: "object" },
      rating: {
        bsonType: "object",
        required: ["count"],
        properties: { count: { ...intType, minimum: 0 }, average: { bsonType: ["double", "int"], minimum: 1, maximum: 5 } }
      }
    }
  } }
});

db.createCollection("customers", {
  validator: { $jsonSchema: {
    bsonType: "object",
    required: ["_id", "first_name", "last_name", "email", "phone", "addresses"],
    properties: {
      email: { bsonType: "string", pattern: "^[^@\\s]+@[^@\\s]+$" },
      phone: { bsonType: "string", pattern: "^\\+234[0-9]{10}$" },
      addresses: { bsonType: "array", minItems: 1 }
    }
  } }
});

db.createCollection("orders", {
  validator: { $jsonSchema: {
    bsonType: "object",
    required: ["_id", "customer", "status", "ordered_at", "shipping_address", "items", "total", "payments"],
    properties: {
      status: { enum: ["pending", "paid", "shipped", "delivered", "cancelled"] },
      ordered_at: { bsonType: "date" },
      total: { bsonType: "decimal", minimum: 0.01 },
      items: {
        bsonType: "array",
        minItems: 1,
        items: {
          bsonType: "object",
          required: ["product_id", "name", "quantity", "unit_price"],
          properties: {
            quantity: { ...intType, minimum: 1 },
            unit_price: { bsonType: "decimal", minimum: 0.01 }
          }
        }
      },
      payments: {
        bsonType: "array",
        items: {
          bsonType: "object",
          required: ["method", "status", "amount", "reference"],
          properties: {
            method: { enum: ["card", "bank_transfer", "ussd", "pay_on_delivery"] },
            status: { enum: ["initiated", "successful", "failed", "refunded"] }
          }
        }
      }
    }
  } }
});

db.createCollection("reviews", {
  validator: { $jsonSchema: {
    bsonType: "object",
    required: ["_id", "product_id", "customer_id", "rating", "reviewed_at"],
    properties: { rating: { ...intType, minimum: 1, maximum: 5 } }
  } }
});

print("Collections created with validators:");
db.getCollectionInfos().forEach(c => print("  " + c.name + "  (validation: " + (c.options.validator ? "on" : "off") + ")"));
