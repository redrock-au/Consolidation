-- REM $Header: svn://d02584/consolrepos/branches/AP.00.02/arc/1.0.0/install/sql/XXAR_PRINT_INVOICES_V.sql 1470 2017-07-05 00:33:23Z svnuser $
CREATE OR REPLACE VIEW XXAR_PRINT_INVOICES_V AS
(SELECT t.customer_trx_id,
       t.cust_trx_type_id,
       x.type trx_type,
       t.bill_to_customer_id customer_id,
       c.customer_number,
       --AR.01.01
       NVL(
          (SELECT NVL(NVL(RTRIM(LTRIM(t.attribute1)), RTRIM(LTRIM(LTRIM(acv.title || ' ') || 
                  acv.first_name || ' ' || acv.last_name))), 'Accounts Payable')
             FROM  ar_contacts_v acv
            WHERE  t.bill_to_contact_id = acv.contact_id (+)
              AND  ROWNUM=1
          ),'Accounts Payable') customer_contact,
       ---
       c.customer_class_code,
       t.org_id,
       t.trx_number,
       t.trx_date,
       t.status_trx,
       LPAD(t.trx_number, 20, '0') trx_number_order,
       t.batch_id,
       NVL(t.printing_count, 0) printing_count,
       c.customer_name,
       c.customer_type,
       c.postal_code,
       CASE WHEN c.customer_type = 'Internal' AND x.type = 'CM'
               THEN NVL(x.attribute11, 'XXARINVPSREMIC')
            WHEN c.customer_type = 'External' AND x.type = 'CM'
               THEN NVL(x.attribute11, 'XXARINVPSREMEC')
            WHEN c.customer_type = 'Internal' AND x.type = 'INV'
               THEN NVL(x.attribute11, 'XXARINVPSREMII')
            WHEN c.customer_type = 'External' AND x.type = 'INV'
               THEN NVL(x.attribute11, 'XXARINVPSREM')
            ELSE NULL
       END template_code,
       c.transmission_method,
       -- CEMLI AR.01.01 (Rao)
       CASE 
          WHEN x.attribute_category ='Agriculture Feeder Systems' THEN
                NVL(NVL(t.attribute8,c.email_address),x.attribute14)    -- Only for feeder systems 
          ELSE
       		NVL(t.attribute8,c.email_address)  
       END  email_address, 
       CASE 
          WHEN x.attribute_category ='Agriculture Feeder Systems' THEN
               x.attribute14
       END feedersys_email
       -- CEMLI AR.01.01 (Rao)
FROM   ra_customer_trx t,
       ra_batch_sources s,
       ra_cust_trx_types x,
      (SELECT ad.address_id,
              su.site_use_id,
              ad.customer_id,
              pa.party_name customer_name,
              ac.account_number customer_number,
              NVL(fl.meaning, 'External') customer_type,
              ac.customer_class_code,
              ad.postal_code,
              si.attribute1 transmission_method,
              si.attribute2 email_address
       FROM   ra_addresses ad,
              hz_parties pa,
              hz_cust_accounts ac,
              hz_cust_site_uses_all su,
              hz_cust_acct_sites_all si,
              fnd_lookup_values fl
       WHERE  su.cust_acct_site_id = si.cust_acct_site_id
       AND    si.party_site_id = ad.party_site_id
       AND    si.cust_account_id = ac.cust_account_id
       AND    ad.customer_id = ac.cust_account_id
       AND    ac.party_id = pa.party_id
       AND    ac.customer_type = fl.lookup_code(+)
       AND    fl.lookup_type(+) = 'CUSTOMER_TYPE') c
WHERE  t.batch_source_id = s.batch_source_id
AND    t.bill_to_customer_id = c.customer_id
AND    t.bill_to_site_use_id = c.site_use_id
AND    t.cust_trx_type_id = x.cust_trx_type_id
AND    t.complete_flag = 'Y'  -- 30/Jun/2017 -- Uncommented
AND    c.customer_type NOT IN ('Internal')   -- 30/Jun/2017 - Only external
AND    EXISTS
       (SELECT 1
        FROM   ra_customer_trx_lines_all l
        WHERE  l.customer_trx_id = t.customer_trx_id)
);