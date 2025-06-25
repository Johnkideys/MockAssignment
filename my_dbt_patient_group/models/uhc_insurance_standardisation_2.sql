{{ config(materialized='table') }}

WITH insurance_standardization AS (
    SELECT 
        e.id as encounter_id,
        e.patient,
        e.payer_coverage,
        e.total_claim_cost,
        CASE 
          WHEN e.payer_coverage = 0 THEN 'Uninsured'
          WHEN e.payer_coverage < e.total_claim_cost THEN 'Partial Coverage'
          ELSE 'Full Coverage'
        END AS coverage_category
    FROM encounters e
),

patient_coverage_patterns AS (
    SELECT
        patient,
        CASE
            WHEN COUNT(DISTINCT CASE WHEN payer_coverage = 0 THEN encounter_id END) = COUNT(DISTINCT encounter_id) THEN 'Always Uninsured'
            WHEN COUNT(DISTINCT CASE WHEN payer_coverage > 0 THEN encounter_id END) = COUNT(DISTINCT encounter_id) THEN 'Always Insured'
            ELSE 'Mixed Coverage'
        END AS patient_coverage_pattern
    FROM insurance_standardization
    GROUP BY patient
)

SELECT 
    p.code AS procedure_code,
    p.description AS procedure_description,
    ic.coverage_category,
    ic.patient,
    pcp.patient_coverage_pattern,
    COUNT(*) AS procedure_count,
    MAX(p.stop::date) AS latest_procedure_date
FROM procedures p
JOIN insurance_standardization ic 
    ON p.encounter = ic.encounter_id
JOIN patient_coverage_patterns pcp
    ON ic.patient = pcp.patient
GROUP BY 1, 2, 3, 4, 5
ORDER BY procedure_description, latest_procedure_date DESC
