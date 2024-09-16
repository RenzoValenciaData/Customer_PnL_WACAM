WITH FINAL_CPNL_WACAM_TABLE AS (
  SELECT
    DATE
    ,Market
    ,ACCOUNT_LVL_1
    ,SUM(Value_LCL) AS AMOUNT_FINAL
  FROM
  `dev-amer-analyt-actuals-svc-7a.amer_p_la_fin_data_hub.v_wacam_cust_pnl_detailed_ff`
  WHERE
    SCENARIO = "ACT"
    AND ACCOUNT_LVL_1 NOT IN ("Net Invoice Sales","Net Revenue","Gross Profit")
    AND DATE >= "2023-01-01"
  GROUP BY
    1,2,3
  ORDER BY 1 ASC
  LIMIT
    1000
),

WACAM_STEP1_TABLE AS (
  SELECT 
    COUNTRY AS Market
    ,PARSE_DATE('%Y-%m-%d', CONCAT(SUBSTR(CAST(FISCPER AS STRING), 1, 4), '-', SUBSTR(CAST(FISCPER AS STRING), 6, 2), '-01')) AS DATE
    ,CASE 
      WHEN FIT_BW_ACCOUNT IN ("Variable Cost","Write Off","Transportation & Warehousing") THEN "COGS"
      WHEN FIT_BW_ACCOUNT IN ("Trade incentive","Non-Performance Deals","Consumer Incentives - Init","Sales Allowances || Sales Returns") THEN "Gross to Net"
      ELSE FIT_BW_ACCOUNT
    END AS FIT_BW_ACCOUNT
    ,SUM(
      CASE
        WHEN FIT_BW_ACCOUNT IN ("Volume","Gross Sales") THEN  BW_AMOUNT_WITH_DIFFERENCE
        ELSE BW_AMOUNT_WITH_DIFFERENCE * -1
      END) AS AMOUNT_STEP1
  FROM
    `prd-amer-analyt-actuals-svc-0a.amer_p_la_fin_data_hub.t_wacam_cust_pnl_detailed_step1` 
  WHERE LEFT(FISCPER,4) IN ("2024", "2023")
    -- AND FIT_BW_ACCOUNT = "Volume"
  GROUP BY 
    1,2,3
  ORDER BY 2 ASC
  LIMIT 1000
) 

,FIT_GM_DATA AS (
  SELECT 
    COUNTRY as market
    ,CASE 
      WHEN FIT_BW_ACCOUNT IN ("Variable Cost","Write Off","Transportation & Warehousing") THEN "COGS"
      WHEN FIT_BW_ACCOUNT IN ("Trade incentive","Non-Performance Deals","Consumer Incentives - Init","Sales Allowances || Sales Returns") THEN "Gross to Net"
      ELSE FIT_BW_ACCOUNT
    END AS ACCOUNT_LVL_1
    ,PARSE_DATE('%Y-%m-%d', CONCAT(SUBSTR(CAST(FISCPER AS STRING), 1, 4), '-', SUBSTR(CAST(FISCPER AS STRING), 6, 2), '-01')) AS DATE
    ,SUM(
      CASE
        WHEN FIT_BW_ACCOUNT IN ("Volume","Gross Sales") THEN  FIT_AMOUNT
        ELSE FIT_AMOUNT * -1
      END) AS AMOUNT_FIT 
  FROM `prd-amer-analyt-actuals-svc-0a.amer_p_la_fin_data_hub.t_detailed_FIT_GM_ACTUALS` 
  GROUP BY 1,2,3
)
-- SELECT DISTINCT ACCOUNT_LVL_1 FROM FINAL_CPNL_WACAM_TABLE

SELECT 
  a.Market
  ,a.DATE
  ,a.ACCOUNT_LVL_1
  ,a.AMOUNT_FINAL
  ,b.AMOUNT_STEP1
  ,a.AMOUNT_FINAL - b.AMOUNT_STEP1 AS DIFF_FINAL_vs_STEP1
  ,(a.AMOUNT_FINAL - b.AMOUNT_STEP1)/ b.AMOUNT_STEP1 AS PERC_DIFF_FINAL_vs_STEP1
  ,c.AMOUNT_FIT
  ,ROUND(a.AMOUNT_FINAL - c.AMOUNT_FIT ,2) AS DIFF_FINAL_vs_FIT
  ,ROUND(a.AMOUNT_FINAL - c.AMOUNT_FIT ,2) / c.AMOUNT_FIT AS PERC_DIFF_FINAL_vs_FIT
FROM 
  FINAL_CPNL_WACAM_TABLE a
INNER JOIN WACAM_STEP1_TABLE b ON a.Market = b.Market
    AND a.DATE = b.DATE
    AND a.ACCOUNT_LVL_1 = b.FIT_BW_ACCOUNT
INNER JOIN FIT_GM_DATA c ON a.market = c.market
  AND a.date = c.date
  AND a.account_lvl_1 = c.account_lvl_1
WHERE ROUND(a.AMOUNT_FINAL - b.AMOUNT_STEP1,2) != 0
ORDER BY 1,2,3 ASC

