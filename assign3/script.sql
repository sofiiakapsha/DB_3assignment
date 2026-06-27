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
RETURNS NUMERIC(10, 2)
LANGUAGE SQL
AS $$
    SELECT COALESCE(SUM(quantity * price), 0)::NUMERIC(10, 2)
    FROM order_items
    WHERE order_id = p_order_id;
$$;

CREATE OR REPLACE PROCEDURE create_order(o_customer_id INT)
LANGUAGE SQL
AS $$
   INSERT INTO orders (customer_id, order_date, total_amount)
SELECT
    o_customer_id,
    CURRENT_TIMESTAMP,
    0.00
FROM customers
WHERE o_customer_id = customer_id;
$$;

CREATE OR REPLACE PROCEDURE add_product_to_order(
    p_order_id int,
    p_product_id int,
    p_quantity int
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_price numeric(10,2);
    v_stock int;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Quantity must be greater than zero';
    END IF;

    SELECT price, stock_quantity INTO v_price, v_stock
    FROM products
    WHERE product_id = p_product_id;

    IF v_stock < p_quantity THEN
        RAISE EXCEPTION 'Not enough stock';
    END IF;

    UPDATE products
    SET stock_quantity = stock_quantity - p_quantity
    WHERE product_id = p_product_id;

    INSERT INTO order_items (order_id, product_id, quantity, price)
    VALUES (p_order_id, p_product_id, p_quantity, v_price);
END;
$$;

CREATE OR REPLACE FUNCTION log_new_order()
RETURNS TRIGGER
AS $$
BEGIN
    INSERT INTO order_log (order_id, customer_id, action)
    VALUES (NEW.order_id, NEW.customer_id, 'Order Created');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER order_log_trigger
AFTER INSERT ON orders
FOR EACH ROW
EXECUTE FUNCTION log_new_order();

CREATE OR REPLACE FUNCTION update_order_total()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE orders
    SET total_amount = calculate_order_total(NEW.order_id)
    WHERE order_id = NEW.order_id;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION delete_order_total()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE orders
    SET total_amount = calculate_order_total(OLD.order_id)
    WHERE order_id = OLD.order_id;
    RETURN OLD;
END;
$$;

CREATE TRIGGER update_order_trigger
AFTER UPDATE OR INSERT ON order_items
FOR EACH ROW
EXECUTE FUNCTION update_order_total();

CREATE TRIGGER delete_order_trigger
AFTER DELETE ON order_items
FOR EACH ROW
EXECUTE FUNCTION delete_order_total();