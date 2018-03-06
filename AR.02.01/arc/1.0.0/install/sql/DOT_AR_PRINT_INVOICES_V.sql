-- REM $Header: svn://d02584/consolrepos/branches/AR.02.01/arc/1.0.0/install/sql/DOT_AR_PRINT_INVOICES_V.sql 1005 2017-06-20 23:55:31Z svnuser $
SELECT t.customer_trx_id,
       t.cust_trx_type_id,
       x.type trx_type,
       t.bill_to_customer_id customer_id,
       c.customer_number,
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
               THEN NVL(x.attribute11, 'DOTINVPSREMIC')
            WHEN c.customer_type = 'External' AND x.type = 'CM'
               THEN NVL(x.attribute11, 'DOTINVPSREMEC')
            WHEN c.customer_type = 'Internal' AND x.type = 'INV'
               THEN NVL(x.attribute11, 'DOTINVPSREMII')
            WHEN c.customer_type = 'External' AND x.type = 'INV'
               THEN NVL(x.attribute11, 'DOTINVPSREM')
            ELSE NULL
       END template_code,
       c.transmission_method,
       c.email_address
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
--AND    t.complete_flag = 'Y'
AND    EXISTS
       (SELECT 1
        FROM   ra_customer_trx_lines_all l
        WHERE  l.customer_trx_id = t.customer_trx_id)
;