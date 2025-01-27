-- En excluant les commandes annulées, quelles sont les commandes récentes de moins de 3 mois que les clients ont reçues avec au moins 3 jours de retard ?
SELECT o.order_id, o.order_purchase_timestamp, o.order_estimated_delivery_date,o.order_delivered_customer_date, o.order_status
FROM orders o
WHERE order_status <> 'canceled'
  AND o.order_estimated_delivery_date IS NOT NULL
   AND o.order_purchase_timestamp > (
      SELECT MAX(order_purchase_timestamp) - INTERVAL 3 MONTH
      FROM orders
  )
  AND o.order_delivered_customer_date > o.order_estimated_delivery_date + INTERVAL 3 DAY;

-- Qui sont les vendeurs ayant généré un chiffre d'affaires de plus de 100 000 Real sur des commandes livrés via Olist?
SELECT seller_id, somme_ventes, nombre_items
FROM (
    SELECT 
		oi.seller_id, 
        SUM(oi.price) AS somme_ventes,
		COUNT(oi.product_id) AS nombre_items
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id
) AS ventes_par_vendeur
WHERE somme_ventes > 100000
ORDER BY
	somme_ventes DESC;

-- Qui sont les nouveaux vendeurs (moins de 3 mois d'ancienneté) qui sont déjà très engagés avec la plateforme (ont déjà vendu plus de 30 produits) ?
	-- Sélection des vendeurs en fonctions du nombre de produit vendu
WITH FirstOrders AS (
    SELECT
        oi.seller_id,
        MIN(o.order_purchase_timestamp) AS first_order_purchase_timestamp
    FROM
        order_items oi
    JOIN
        orders o ON o.order_id = oi.order_id
    WHERE
        o.order_approved_at IS NOT NULL
    GROUP BY
        oi.seller_id
),
TotalProductsSold AS (
    SELECT
        oi.seller_id,
        COUNT(*) AS total_products_sold
    FROM
        order_items oi
    JOIN
        orders o ON oi.order_id = o.order_id
    WHERE
        o.order_status = 'delivered'
    GROUP BY
        oi.seller_id
    HAVING
        COUNT(*) > 30
),
TotalSales AS (
    SELECT
        oi.seller_id,
        SUM(oi.price) AS total_amount
    FROM
        order_items oi
    GROUP BY
        oi.seller_id
),
MostRecentOrderDate AS (
    SELECT
        MAX(order_purchase_timestamp) AS most_recent_order_date
    FROM
        orders
)
SELECT
    tps.seller_id,
    fo.first_order_purchase_timestamp,
    tps.total_products_sold,
    ts.total_amount
FROM
    TotalProductsSold tps
JOIN
    FirstOrders fo ON tps.seller_id = fo.seller_id
JOIN
    TotalSales ts ON tps.seller_id = ts.seller_id
CROSS JOIN 
    MostRecentOrderDate
WHERE
    TIMESTAMPDIFF(MONTH, fo.first_order_purchase_timestamp, MostRecentOrderDate.most_recent_order_date) < 3;


-- Quels sont les 5 codes postaux, enregistrant plus de 30 commandes, avec le pire review score moyen sur les 12 derniers mois ?
WITH RecentOrders AS (
    SELECT
        o.order_id,
        c.customer_zip_code_prefix,
        orv.review_score
    FROM
        order_reviews orv
    JOIN 
        orders o ON o.order_id = orv.order_id
    JOIN
        customers c ON c.customer_id = o.customer_id
    WHERE
        o.order_approved_at > (SELECT MAX(order_purchase_timestamp) FROM orders) - INTERVAL 12 MONTH
),
AggregatedScores AS (
    SELECT
        customer_zip_code_prefix,
        AVG(review_score) AS avg_review_score,
        COUNT(*) AS total_orders,
        COUNT(review_score) AS total_review
    FROM
        RecentOrders
    GROUP BY
        customer_zip_code_prefix
    HAVING
        total_orders > 30
)
SELECT
    customer_zip_code_prefix,
    avg_review_score,
    total_review
FROM
    AggregatedScores
ORDER BY
    avg_review_score ASC
LIMIT 5;