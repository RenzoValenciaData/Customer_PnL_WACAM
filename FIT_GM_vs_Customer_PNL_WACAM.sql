
WITH FIT_GM_DATA_S1 AS (
  SELECT  
    entity
    ,account_code
    ,date
    ,Scenario
    ,currency
    ,value
  FROM `prd-amer-analyt-actuals-svc-0a.amer_p_la_fin_data_hub.fit_Data` 
  WHERE SCENARIO = "Act"
    AND CURRENCY = "LCL"
    AND ENTITY = "CDCOLCOM"
    AND DATE >= "2023-01-01"
)

,PRD_ACCOUNT_HIERARCHY AS (
  SELECT
    account_code
    ,account_description AS account_desc
    ,level_04_description
    ,level_05_description
    ,level_06_description
    ,level_07_description  
  FROM `prd-amer-analyt-actuals-svc-0a.amer_p_la_fin_data_hub.v_fit_account_hier_amer` 
  WHERE level_03 = "PL229099"
    OR (level_03 = "Memo_Accounts" AND account_code = "PLV959999")
)

,FIT_GM_DATA_S2 AS (
  SELECT
    a.date
    ,"COLOMBIA" AS MARKET
    ,CASE
      WHEN b.level_04_description = "Volume Accounts" THEN "Volume"
      WHEN b.level_06_description = "Cost of Goods Sold" THEN "COGS"
      WHEN b.level_07_description = "Total Gross Sales" THEN  "Gross Sales"
      WHEN b.level_07_description = "Revenue Reductions" THEN "Gross to Net"
      ELSE "NN"
    END AS ACCOUNT_LVL_1
    ,SUM(
      CASE
        WHEN b.level_07_description = "Revenue Reductions" THEN -1 * a.value
        WHEN b.level_06_description = "Cost of Goods Sold" THEN -1 * a.value
        ELSE a.value
      END
    ) AS value_LCL_FIT_GM
  FROM FIT_GM_DATA_S1 a
  LEFT JOIN PRD_ACCOUNT_HIERARCHY b ON a.account_code = b.account_code
  GROUP BY 1,2,3
)

,PRD_FF_TABLE AS (
  SELECT 
    DATE
    ,MARKET
    ,ACCOUNT_LVL_1 
    ,SUM(Value_LCL) AS VALUE_LCL_PRD_FF
  FROM `prd-amer-analyt-actuals-svc-0a.amer_p_la_fin_data_hub.v_wacam_cust_pnl_detailed_ff`
  WHERE MARKET = "COLOMBIA"
    AND ACCOUNT_LVL_1 NOT IN ("Net Invoice Sales","Net Revenue","Gross Profit")
    AND SCENARIO = "ACT"
  GROUP BY 1,2,3
)

,DEV_FF_TABLE AS (
  SELECT 
    DATE
    ,MARKET
    ,ACCOUNT_LVL_1 
    ,SUM(Value_LCL) AS VALUE_LCL_DEV_FF
  FROM   `dev-amer-analyt-actuals-svc-7a.amer_p_la_fin_data_hub.v_wacam_cust_pnl_detailed_ff`
  WHERE MARKET = "COLOMBIA"
    AND ACCOUNT_LVL_1 NOT IN ("Net Invoice Sales","Net Revenue","Gross Profit")
    AND SCENARIO = "ACT"
  GROUP BY 1,2,3
)

SELECT
  FIT.*
  ,PRD_FF.VALUE_LCL_PRD_FF
  ,ROUND(FIT.VALUE_LCL_FIT_GM - PRD_FF.VALUE_LCL_PRD_FF ,2) AS DIFF_FIT_vs_PRD_FF
  ,DEV_FF.VALUE_LCL_DEV_FF
  ,ROUND( FIT.VALUE_LCL_FIT_GM - DEV_FF.VALUE_LCL_DEV_FF ,2) AS DIFF_FIT_vs_DEV_FF
  ,ABS(ROUND(FIT.VALUE_LCL_FIT_GM - PRD_FF.VALUE_LCL_PRD_FF ,2)) / fit.value_lcl_fit_gm AS PERC_DIFF_PRD
  ,ABS(ROUND( FIT.VALUE_LCL_FIT_GM - DEV_FF.VALUE_LCL_DEV_FF ,2)) / fit.value_lcl_fit_gm AS PERC_DIFF_DEV
FROM FIT_GM_DATA_S2 FIT
LEFT JOIN PRD_FF_TABLE PRD_FF ON fit.date = prd_ff.date
  AND fit.market = prd_ff.market
  AND fit.account_lvl_1 = prd_ff.account_lvl_1
LEFT JOIN DEV_FF_TABLE DEV_FF ON fit.date = dev_ff.date
  AND fit.market = dev_ff.market
  AND fit.account_lvl_1 = dev_ff.account_lvl_1
WHERE (ABS(ROUND(FIT.VALUE_LCL_FIT_GM - PRD_FF.VALUE_LCL_PRD_FF ,2)) / fit.value_lcl_fit_gm >= 0.0001 OR ABS(ROUND( FIT.VALUE_LCL_FIT_GM - DEV_FF.VALUE_LCL_DEV_FF ,2)) / fit.value_lcl_fit_gm >= 0.0001)
ORDER BY DATE, ACCOUNT_LVL_1, PERC_DIFF_PRD, PERC_DIFF_DEV DESC
