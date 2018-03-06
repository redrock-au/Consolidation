/*$Header: svn://d02584/consolrepos/branches/AR.09.03/poc/1.0.0/install/sql/POC_SUPPLIER_INFO_V_DBI.sql 2689 2017-10-05 04:37:59Z svnuser $*/
CREATE OR REPLACE VIEW 
apps.poc_supplier_info_v_dbi 
(
   supplier_id, 
   supplier_name, 
   supplier_number, 
   supplier_terms, 
   supplier_abn, 
   supplier_site_id, 
   site_name, 
   site_org, 
   site_address_line1, 
   site_address_line2, 
   site_address_line3, 
   site_city, 
   site_state, 
   site_postcode, 
   site_phone, 
   site_fax, 
   site_email_address, 
   site_abn, 
   site_pay_flag, 
   site_bsb_number,
   site_bank_acct_num
)
AS
SELECT apv.vendor_id,
       apv.vendor_name,
       apv.segment1 vendor_number,
       at.name terms_name,
       apv.vat_registration_num,
       apsv.vendor_site_id,
       apsv.vendor_site_code,
       apsv.org_id,
       apsv.address_line1,
       apsv.address_line2,
       apsv.address_line3,
       apsv.city,
       apsv.state,
       apsv.zip,
       apsv.phone,
       apsv.fax,
       apsv.email_address,
       apsv.vat_registration_num,
       apsv.pay_site_flag,
       bank_account_details.bank_num,
       bank_account_details.bank_account_num
FROM   po_vendor_sites_all apsv,
       po_vendors apv ,
       ap_terms at,
       fnd_profile_options fpo,
       fnd_profile_option_values fpov,       
       (
          SELECT abb.bank_number || '-' || bank_num bank_num,
                 abaa.bank_account_num,
                 abaua.vendor_site_id
          FROM   ap_bank_accounts_all abaa,
                 ap_bank_branches abb,
                 ap_bank_account_uses_all abaua
          WHERE  abaa.bank_branch_id = abb.bank_branch_id
          AND abaua.external_bank_account_id = abaa.bank_account_id(+)
          AND TRUNC(SYSDATE) BETWEEN TRUNC(NVL(abaua.START_DATE,sysdate-1)) AND TRUNC(NVL(abaua.END_DATE,sysdate+1))
       ) bank_account_details
WHERE apsv.vendor_id     = apv.vendor_id
AND apsv.inactive_date  IS NULL
AND apv.enabled_flag     = 'Y'
AND apv.end_date_active IS NULL
AND apsv.vendor_site_id  = bank_account_details.vendor_site_id(+)
AND at.term_id(+) = apv.terms_id
AND fpov.profile_option_id = fpo.profile_option_id
AND fpo.profile_option_name = 'POC_KOFAX_ENABLED'
AND fpov.level_value = apsv.org_id
AND fpov.level_id = 10006;

GRANT SELECT ON APPS.poc_supplier_info_v_dbi TO KOFAX;

CREATE OR REPLACE SYNONYM KOFAX.poc_supplier_info_v_dbi FOR APPS.poc_supplier_info_v_dbi;
