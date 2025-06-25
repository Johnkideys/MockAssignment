{{ config(materialized='table') }}


WITH insurance_standardization AS (
    SELECT 
        e.id as encounter_id,
        e.payer_coverage,
        e.total_claim_cost,
        -- Standardise coverage categories based on ecnounter
        CASE 
            WHEN e.payer_coverage = 0 THEN 'Uninsured'
            WHEN e.payer_coverage < e.total_claim_cost THEN 'Partial Coverage'
            ELSE 'Full Coverage'
        END AS coverage_category
    FROM encounters e
),

procedure_grouping AS (
    SELECT 
        p.*,
        CASE 
            WHEN LOWER(p.description) ~ '(depression|anxiety|substance|behavioral|cognitive|mental)' 
                THEN 'Mental Health'
            WHEN LOWER(p.description) ~ '(screening|assessment)' AND 
            -- exclude mental health codes
                 LOWER(p.description) !~ '(depression|anxiety|substance|mental)'
                THEN 'Preventive Screening & Assessment'
            WHEN LOWER(p.description) ~ '(scan|mammography|computed tomography|ultrasound|examination|test)' AND
                 LOWER(p.description) !~ '(screening|assessment)'
                THEN 'Diagnostic Testing & Imaging'
            WHEN LOWER(p.description) ~ '(therapy|rehabilitation|administration|injection|treatment)'
                THEN 'Therapeutic Interventions'
            WHEN LOWER(p.description) ~ '(fetal|pregnancy|pelvic|genital|birth)'
                THEN 'Maternal & Reproductive Health'
            WHEN LOWER(p.description) ~ '(dialysis|cardioversion|colonoscopy|ablation)'
                THEN 'Specialised Procedures'
            ELSE 'Other Procedures'
        END AS procedure_group
    FROM procedures p
)

SELECT 
    pg.code AS procedure_code,
    pg.description AS procedure_description,
    pg.procedure_group,
    ic.coverage_category,
    pg.encounter AS encounter_id,
    pg.start::date AS procedure_date,
    pg.stop::date AS procedure_end_date,
    ic.total_claim_cost,
    ic.payer_coverage
FROM procedure_grouping pg
LEFT JOIN insurance_standardization ic 
    ON pg.encounter = ic.encounter_id
ORDER BY pg.procedure_group, pg.description, pg.start DESC