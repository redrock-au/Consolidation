DECLARE
/* $Header $ */
BEGIN
  FOR c_rec IN
  (SELECT    *
  FROM fmsmgr.xxap_supplier_conv_tfm
  WHERE source_supplier_number IN
    (SELECT source_supplier_number
    FROM
      (SELECT COUNT(1) ,
        source_supplier_number
      FROM fmsmgr.xxap_supplier_conv_tfm
      WHERE run_id = 11899
      AND  record_type = 'NEW'
      GROUP BY source_supplier_number
      HAVING COUNT(1) >1
      )
    )
  AND run_id = 11899
  )
  LOOP
    IF C_REC.VENDOR_NAME IS NULL THEN
      UPDATE fmsmgr.xxap_supplier_conv_tfm tfm
      SET dtpli_supplier_num =
        (SELECT MAX(dtpli_supplier_num)
        FROM fmsmgr.xxap_supplier_conv_tfm x
        WHERE x.source_supplier_number = tfm.source_supplier_number
        AND x.vendor_name             IS NOT NULL
        AND status                     = 'SUCCESS'
        AND run_id                     = 11899
        AND dtpli_supplier_num        IS NOT NULL
        ),
        dtpli_site_code = vendor_site_code ,
        status          = 'SUCCESS'
      WHERE record_id   = c_rec.record_id;
      dbms_output.put_line('Updated vendor_id and site code for record Id : '||c_rec.record_id);
    END IF;
  END LOOP;
EXCEPTION
WHEN OTHERS THEN
  dbms_output.put_line('Unexpected exception occurred while updating the transformation table - Error is : '||SQLERRM);
END;
