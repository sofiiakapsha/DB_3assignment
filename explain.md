Nested Loop  (cost=27.38..57.82 rows=7 width=496) (actual time=0.252..0.260 rows=2 loops=1)
  ->  Nested Loop  (cost=0.30..16.43 rows=1 width=230) (actual time=0.126..0.128 rows=1 loops=1)
        ->  Index Scan using orders_pkey on orders o  (cost=0.15..8.17 rows=1 width=16) (actual time=0.089..0.091 rows=1 loops=1)
              Index Cond: (order_id = 2)
        ->  Index Scan using customers_pkey on customers c  (cost=0.14..8.16 rows=1 width=222) (actual time=0.026..0.027 rows=1 loops=1)
              Index Cond: (customer_id = o.customer_id)
  ->  Hash Join  (cost=27.09..41.28 rows=7 width=242) (actual time=0.113..0.116 rows=2 loops=1)
        Hash Cond: (p.product_id = oi.product_id)
        ->  Seq Scan on products p  (cost=0.00..13.00 rows=300 width=222) (actual time=0.039..0.041 rows=5 loops=1)
        ->  Hash  (cost=27.00..27.00 rows=7 width=28) (actual time=0.037..0.037 rows=2 loops=1)
              Buckets: 1024  Batches: 1  Memory Usage: 9kB
              ->  Seq Scan on order_items oi  (cost=0.00..27.00 rows=7 width=28) (actual time=0.023..0.025 rows=2 loops=1)
                    Filter: (order_id = 2)
                    Rows Removed by Filter: 3
Planning Time: 0.671 ms
Execution Time: 0.386 ms


Під час виконання даної квері PostgreSQL спочатку застосовує фільтр WHERE, щоб відсіяти зайві дані ще на початку, а не перебирати все підряд. Під час перевірки умов відбувається Nested Loop, всередині якого за допомогою Index Scan база знаходить потрібні рядки по order_id. Далі, у тому ж Nested Loop, за допомогою Index Scan по первинному ключу підтягуються дані про кастомерів. На наступноум етапі за допомогою Hash Join поєднуються order_items та products. Тут PostgreSQL обирає Sequential Scan для таблиці products, завантажуючи хеш таблицю в пам'ять.