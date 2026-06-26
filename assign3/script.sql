create table customers (
    customer_id serial primary key,
    full_name varchar(100) not null,
    email varchar(100) unique not null,
    balance numeric(10,2) default 0
);

create table products (
    product_id serial primary key,
    product_name varchar(100) not null,
    price numeric(10,2) not null,
    stock_quantity int not null
);

create table orders (
    order_id serial primary key,
    customer_id int references customers(customer_id),
    order_date timestamp default current_timestamp,
    total_amount numeric(10,2) default 0
);

create table order_items (
    order_item_id serial primary key,
    order_id int references orders(order_id),
    product_id int references products(product_id),
    quantity int not null,
    price numeric(10,2) not null
);

create table order_log (
    log_id serial primary key,
    order_id int,
    customer_id int,
    action varchar(50),
    log_date timestamp default current_timestamp
);

CREATE OR REPLACE FUNCTION calculate_order_total(p_order_id INT)
RETURNS TABLE(customer_id INT, order_id INT, order_price NUMERIC(10, 2))
LANGUAGE plpgsql
AS $$
    SELECT
        o.customer_id,
        o.order_id,
        COALESCE(SUM(oi.quantity * oi.price), 0)::NUMERIC(10, 2) AS order_price
    FROM orders o
    LEFT JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_id = p_order_id
    GROUP BY o.customer_id, o.order_id;
$$;

CREATE OR REPLACE PROCEDURE create_order(o_customer_id INT)
LANGUAGE plpgsql
AS $$
   INSERT INTO orders (customer_id, order_date, total_amount)
SELECT
    o_customer_id,
    CURRENT_TIMESTAMP,
    0.00
FROM orders
WHERE EXISTS (SELECT 1 FROM customers c WHERE c.customer_id = o_customer_id);
$$;

CREATE OR REPLACE PROCEDURE add_product_to_order(
    p_order_id int,
    p_product_id int,
    p_quantity int
)
LANGUAGE plpgsql
AS $$
    UPDATE products p2
    SET stock_quantity = stock_quantity - p_quantity
    WHERE p2.product_id = p_product_id
    AND stock_quantity >= 0
    AND p_quantity > 0;

    INSERT INTO order_items (order_id, product_id, quantity, price)
    SELECT
        p_order_id,
        p_product_id,
        p_quantity,
        p.price
    FROM products p
    WHERE p.product_id = p_product_id;
$$;

CREATE OR REPLACE FUNCTION log_new_order()
RETURNS TRIGGER
AS $$
BEGIN
    IF OLD.order_id IS DISTINCT FROM NEW.order_id THEN
        INSERT INTO order_log (order_id, customer_id, action, log_date)
        VALUES (NEW.order_id, NEW.customer_id, NEW.action, NEW.log_date);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER order_log
AFTER UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION log_new_order();