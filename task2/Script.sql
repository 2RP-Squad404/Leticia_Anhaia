%hive
-- Selecionar o local de compra mais utilizado, o total gasto, as datas da primeira e última compra, 
-- a campanha que mais recebeu o status 'received', a quantidade de campanhas com o status 'error' para cada cliente,
-- e a data atual em diferentes formatos.

SELECT 
    p.client_id,  -- Seleciona o ID do cliente
    p.purchase_location AS most_purchase_location,  -- Seleciona o local de compra mais frequente
    CONCAT('R$ ', CAST(ROUND(SUM(p.price * p.amount * (1 - p.discount_applied)), 2) AS STRING)) AS total_price,  -- Calcula o total gasto pelo cliente considerando desconto
    DATE_FORMAT(MIN(p.purchase_datetime), 'yyyy-MM-dd') AS first_purchase_date,  -- Formata e seleciona a data da primeira compra do cliente
    DATE_FORMAT(MAX(p.purchase_datetime), 'yyyy-MM-dd') AS last_purchase_date,  -- Formata e seleciona a data da última compra do cliente
    c.most_campaign,  -- Seleciona a campanha que mais recebeu o status 'received' para o cliente
    COALESCE(e.error_count, 0) AS error_count,  -- Conta quantas campanhas tiveram status 'error' para o cliente; retorna 0 se não houver
    DATE_FORMAT(CURRENT_DATE, 'yyyy-MM-dd') AS current_date_format,  -- Formata a data atual como 'yyyy-MM-dd'
    DATE_FORMAT(CURRENT_DATE, 'MM/yyyy') AS current_date_month_year  -- Formata a data atual como 'MM/yyyy'
FROM (
    -- Subconsulta para identificar o local de compra mais frequente por cliente
    SELECT 
        client_id,  -- Seleciona o ID do cliente
        purchase_location,  -- Seleciona o local de compra
        price,  -- Seleciona o preço do produto
        amount,  -- Seleciona a quantidade do produto comprada
        discount_applied,  -- Seleciona o desconto aplicado
        purchase_datetime,  -- Seleciona a data e hora da compra
        ROW_NUMBER() OVER (PARTITION BY client_id ORDER BY COUNT(*) DESC) AS rank  -- Atribui um número de linha para cada compra, ordenando pela mais frequente
    FROM 
        purchase  -- Da tabela de compras
    GROUP BY -- Agrupa por cliente, local de compra, preço, quantidade, desconto e data/hora da compra
        client_id, 
        purchase_location,
        price,
        amount,
        discount_applied,
        purchase_datetime 
) p
-- Subconsulta para identificar a campanha que mais recebeu o status 'received' por cliente
LEFT JOIN (
    SELECT 
        client_id,  -- Seleciona o ID do cliente
        id_campaign AS most_campaign  -- Seleciona a campanha mais frequente com status 'received'
    FROM (
        SELECT 
            client_id,  -- Seleciona o ID do cliente
            id_campaign,  -- Seleciona o ID da campanha
            COUNT(*) AS campaign_count,  -- Conta o número de vezes que a campanha recebeu o status 'received'
            ROW_NUMBER() OVER (PARTITION BY client_id ORDER BY COUNT(*) DESC) AS rank  -- Atribui um número de linha para cada campanha, ordenando pela mais frequente
        FROM 
            campaigns_2023_hist  -- Da tabela de histórico de campanhas
        WHERE 
            return_status = 'received'  -- Filtra campanhas com status 'received'
        GROUP BY 
            client_id,
            id_campaign  -- Agrupa por cliente e campanha
    ) ranked_campaigns
    WHERE rank = 1  -- Mantém apenas a campanha mais frequente por cliente
) c ON p.client_id = c.client_id  -- Junta as informações da campanha com as informações da compra, utilizando o ID do cliente
-- Subconsulta para contar o número de campanhas com status 'error' por cliente
LEFT JOIN (
    SELECT 
        client_id,  -- Seleciona o ID do cliente
        COUNT(*) AS error_count  -- Conta o número de campanhas com status 'error' para cada cliente
    FROM 
        campaigns_2023_hist  -- Da tabela de histórico de campanhas
    WHERE 
        return_status = 'error'  -- Filtra campanhas com status 'error'
    GROUP BY 
        client_id  -- Agrupa por cliente
) e ON p.client_id = e.client_id  -- Junta as informações de erro com as informações da compra, utilizando o ID do cliente
WHERE p.rank = 1  -- Filtra para manter apenas o local de compra mais frequente por cliente
GROUP BY 
    p.client_id,
    p.purchase_location,
    c.most_campaign,
    e.error_count  -- Agrupa os resultados finais por cliente, local de compra, campanha mais frequente e contagem de erros
