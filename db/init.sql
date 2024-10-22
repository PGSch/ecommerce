-- Create the database if it does not exist
SELECT 'CREATE DATABASE products' 
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'products')\gexec

-- Terminate connections and reconnect to the database
\c postgres

DO
$$
BEGIN
   IF EXISTS (SELECT FROM pg_database WHERE datname = 'products') THEN
      PERFORM pg_terminate_backend(pid) 
      FROM pg_stat_activity 
      WHERE datname = 'products' AND pid <> pg_backend_pid();
   END IF;
END
$$;

-- Reconnect to the database
\c products

-- Create the orders table if it does not exist
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL,
    quantity INTEGER NOT NULL,
    price NUMERIC(10, 2) NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create the products table if it does not exist
CREATE TABLE IF NOT EXISTS product_items (
    id SERIAL PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL
);
