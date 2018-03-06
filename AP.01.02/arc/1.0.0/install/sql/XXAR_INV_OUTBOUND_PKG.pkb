CREATE OR REPLACE PACKAGE BODY xxar_inv_outbound_pkg
AS
/* $Header: svn://d02584/consolrepos/branches/AP.01.02/arc/1.0.0/install/sql/XXAR_INV_OUTBOUND_PKG.pkb 1415 2017-07-04 05:27:42Z svnuser $ */
/*******************************************************************
**
** CEMLI ID: AR.02.01
**
**      This package implements outbound file creation for Feeder Systems
**      Files are created in file system directories specified by configuration
**      in the custom table
**      Invoices are selected based on updates to invoice header or payment
**      schedules ("activity") since a point in time, either a user specified
**      time or since the last time the program run.
**
** Change History:
**
** Date        Who                  Comments
** 12/05/2017  NCHENNURI (RED ROCK) Initial build.
**
*******************************************************************/
  gc_delim                   CONSTANT VARCHAR2(1) := '|';
  g_default_outbound_date    DATE                 := TO_DATE('01-JAN-1990');
  --gc_date_format             CONSTANT VARCHAR2(8) := 'YYYYMMDD';
  gc_date_format             CONSTANT VARCHAR2(16) := 'YYYYMMDDHH24MMSS';  -- used HH24 to handle conflic between AM and PM time 
  g_error                    VARCHAR2(10)         := 'ERROR: ';
  g_debug                    VARCHAR2(10)         := 'DEBUG: ';
  g_request_id               NUMBER               := -1;
  ex_no_source_successful    EXCEPTION;
  ex_partial_success         EXCEPTION;
  ex_invalid_date            EXCEPTION;
  ex_invalid_transation_type EXCEPTION;
  ex_other_outbound_date     EXCEPTION;
  ex_no_detail_records       EXCEPTION;
  ex_file_copy_error         EXCEPTION;
  ex_beyond_outbound_date    EXCEPTION;
  -- --------------------------------------------------------------------------------------------------
  --  PROCEDURE
  --      log_msg
  --  PURPOSE
  --       Writes a line to the concurrent log file.
  -- --------------------------------------------------------------------------------------------------
  PROCEDURE log_msg(
      p_message IN VARCHAR2 )
  IS
  BEGIN
    IF g_request_id > 0 THEN
      fnd_file.put_line(fnd_file.log, SUBSTR(p_message, 1, 2000));
    ELSE
      dbms_output.put_line(SUBSTR(p_message, 1, 2000));
    END IF;
  END log_msg;
-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      log_msg
--  PURPOSE
--       Writes a line to the concurrent log file.
-- --------------------------------------------------------------------------------------------------
  PROCEDURE out_msg(
      p_message IN VARCHAR2 )
  IS
  BEGIN
    IF g_request_id > 0 THEN
      fnd_file.put_line(fnd_file.output, SUBSTR(p_message, 1, 2000));
    ELSE
      dbms_output.put_line(SUBSTR(p_message, 1, 2000));
    END IF;
  END out_msg;
/* -------------------------------------------------------------------------
-- Procedure:
--    write_header
-- Purpose:
--    Writes the file header record
-- Parameters:
--    pv_source_name        Batch Source Name
--    pd_last_runtime       Last runtime of the interface
--    pf_file_ref           File handler of current file to be written
-- ----------------------------------------------------------------------- */
  PROCEDURE write_header(
      pv_source_name  IN VARCHAR2,
      pd_last_runtime IN DATE,
      pf_file_ref     IN OUT nocopy utl_file.file_type )
  IS
    lv_buffer VARCHAR2(100);
  BEGIN
    lv_buffer := '0' || gc_delim || pv_source_name 
                     || gc_delim || TO_CHAR(pd_last_runtime, gc_date_format) 
                     || gc_delim || TO_CHAR(sysdate, gc_date_format);
    out_msg(lv_buffer);
    utl_file.put_line(pf_file_ref, lv_buffer, true);
  END write_header;
/* -------------------------------------------------------------------------
-- Procedure:
--    write_detail
-- Purpose:
--    Writes the file detail record
-- Parameters:
--    pv_trx_type           -- transaction type
--    pv_transaction_source -- transaction source
--    pd_last_outbound_date -- last outbound date
--    pf_file_ref           -- File handler of current file to be written
-- ----------------------------------------------------------------------- */
  PROCEDURE write_detail(
      pv_trx_type           IN VARCHAR2,
      pv_transaction_source IN VARCHAR2,
      pd_last_outbound_date IN DATE,
      pf_file_ref           IN OUT nocopy utl_file.file_type)
  IS
    CURSOR c_inv(pv_transaction_type IN VARCHAR2,pv_source_name IN VARCHAR2,pd_activity_date IN DATE)
    IS
      SELECT DISTINCT rct.customer_trx_id ,
        rct.trx_number ,
        rct.trx_date ,
        --NVL(hca.account_name, hp.party_name) AS customer_name ,
        NVL(hp.party_name,hca.account_name) AS customer_name ,
        hca.cust_account_id ,
        rct.attribute7 AS crn ,
        (SELECT COUNT(*)
        FROM ra_customer_trx_lines rctl
        WHERE rctl.customer_trx_id = rct.customer_trx_id
        AND rctl.line_type         = 'LINE'
        ) AS line_count ,
      (SELECT SUM(DECODE(rctd.account_class, 'REV', rctd.amount,0))
      FROM ra_cust_trx_line_gl_dist rctd
      WHERE rctd.customer_trx_id = rct.customer_trx_id
      ) AS rev_amount ,
      (SELECT SUM(DECODE(rctd.account_class, 'TAX', rctd.amount,0))
      FROM ra_cust_trx_line_gl_dist rctd
      WHERE rctd.customer_trx_id = rct.customer_trx_id
      ) AS tax_amount ,
      aps.due_date ,
      aps.amount_due_remaining ,
      (
      CASE aps.status
        WHEN 'CL'
        THEN aps.last_update_date
        ELSE NULL
      END )                                                                                          AS date_closed ,
      DECODE(ara.application_type,'CASH', 'Cash Receipt','CM', 'Credit Memo', ara.application_type ) AS application_type ,
      aps.class
    FROM ra_customer_trx rct ,
      ra_batch_sources rbs ,
      ra_cust_trx_types rctt,
      hz_cust_accounts hca ,
      hz_parties hp ,
      ar_payment_schedules aps ,
      ar_receivable_applications ara,
      fnd_lookup_values lv
    WHERE 1                                =1
    AND lv.lookup_type                     = 'XXAR_INVOICE_OUTBOUND_TXN_TYPE'
    AND lv.meaning                         = rctt.name
    AND rctt.cust_Trx_type_id              =rct.cust_Trx_type_id
    AND hca.cust_account_id                = rct.bill_to_customer_id
    AND rbs.batch_source_id                = rct.batch_source_id
    AND hp.party_id                        = hca.party_id
    AND aps.customer_trx_id                = rct.customer_trx_id
    AND ara.applied_payment_schedule_id(+) = aps.payment_schedule_id
    AND rbs.name                           = NVL(pv_source_name,rbs.name)  --29/Jun/17
    AND rctt.name                          = NVL(pv_transaction_type,rctt.name) --29/Jun/17
/*    AND ( aps.last_update_date            >= NVL(pd_activity_date, aps.last_update_date)
    OR rct.last_update_date               >= NVL(pd_activity_date, rct.last_update_date) )*/
      AND ( aps.last_update_date            >= NVL(
                                                   (select NVL(pd_activity_date,max(last_outbound_date)) 
                                                      from xxar_invoice_out_int_log logtab
					             where 1=1
						       and logtab.transaction_source=rbs.name
						       and logtab.transaction_type=rctt.name
						       and logtab.status='SUCCESS'
						    )
						   ,aps.last_update_date)
      OR rct.last_update_date               >= NVL(
   						   (select NVL(pd_activity_date,max(last_outbound_date)) 
						      from xxar_invoice_out_int_log logtab
						     where 1=1
						       and logtab.transaction_source=rbs.name
						       and logtab.transaction_type=rctt.name
						       and logtab.status='SUCCESS'
							)
      					      , rct.last_update_date) )    
    ORDER BY rct.trx_number ;
    lv_buffer VARCHAR2(2000);
    ln_cnt NUMBER:=0;
  BEGIN
    log_msg('In write_detail procedure');
    log_msg('   Executing cursor c_inv for');
    log_msg('   pv_trx_type:'||pv_trx_type);
    log_msg('   pv_transaction_source:'||pv_transaction_source);
    log_msg('   pd_last_outbound_date:'||TO_CHAR(pd_last_outbound_date,'DD-MON-YYYY'));
    FOR r_inv IN c_inv(pv_trx_type,pv_transaction_source, pd_last_outbound_date)
    LOOP      
      ln_cnt := ln_cnt+1;
      lv_buffer := '1' || gc_delim || r_inv.trx_number || gc_delim || TO_CHAR(r_inv.trx_date, gc_date_format) 
                       || gc_delim || r_inv.customer_name || gc_delim || r_inv.crn || gc_delim || r_inv.line_count 
                       || gc_delim || ROUND(r_inv.rev_amount,2) || gc_delim || ROUND(r_inv.tax_amount,2) || gc_delim 
                       || (ROUND(r_inv.rev_amount,2) + ROUND(r_inv.tax_amount,2)) || gc_delim 
                       || TO_CHAR(r_inv.due_date, gc_date_format) || gc_delim || ROUND(r_inv.amount_due_remaining,2) ;
      out_msg(lv_buffer);
      utl_file.put_line(pf_file_ref, lv_buffer, true);
    END LOOP;
    IF ln_cnt = 0 THEN
       RAISE ex_no_detail_records;
    ELSE
       log_msg(ln_cnt||' detail records are extracted');
    END IF;
  END write_detail;
/* -------------------------------------------------------------------------
-- Procedure:
--    write_trailer
-- Purpose:
--    Writes the file trailer record
-- Parameters:
--    pf_file_ref           File handler of current file to be written
-- ----------------------------------------------------------------------- */
  PROCEDURE write_trailer(
      pf_file_ref IN OUT nocopy utl_file.file_type)
  IS
    lv_buffer VARCHAR2(100);
  BEGIN
    lv_buffer := '9';
    out_msg(lv_buffer);
    utl_file.put_line(pf_file_ref, lv_buffer, true);
  END write_trailer;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      insert_outbound_log_table
--  PURPOSE
-- inserts a new record for the first run of interface with transaction type and source parameters
-- --------------------------------------------------------------------------------------------------
  PROCEDURE insert_outbound_log_table(
      pv_trx_type  IN VARCHAR2,
      pd_activity_date IN DATE
      )
  IS
    l_user_id             NUMBER := fnd_profile.value('USER_ID');

    CURSOR c_sources(p_trx_type IN VARCHAR2, p_activity_date IN DATE)
    IS
      SELECT rctt.name transaction_type, ---29/Jun/2017
             rbs.name transaction_source -- transaction source
      FROM ra_customer_trx rct ,
           ra_batch_sources rbs ,
           ra_cust_trx_types rctt,
           hz_cust_accounts hca ,
           hz_parties hp ,
           ar_payment_schedules aps ,
           ar_receivable_applications ara,
           fnd_lookup_values lv
      WHERE 1                                =1
      AND lv.lookup_type                     = 'XXAR_INVOICE_OUTBOUND_TXN_TYPE'
      AND lv.meaning                         = rctt.name
      AND rctt.cust_Trx_type_id              =rct.cust_Trx_type_id
      AND hca.cust_account_id                = rct.bill_to_customer_id
      AND rbs.batch_source_id                = rct.batch_source_id
      AND hp.party_id                        = hca.party_id
      AND aps.customer_trx_id                = rct.customer_trx_id
      AND ara.applied_payment_schedule_id(+) = aps.payment_schedule_id
      AND rctt.name                          = NVL(p_trx_type,rctt.name)
      AND ( aps.last_update_date            >= NVL(
                                                   (select NVL(pd_activity_date,max(last_outbound_date)) 
                                                      from xxar_invoice_out_int_log logtab
					                                           where 1=1
                                                       and logtab.transaction_source=rbs.name
                                                       and logtab.transaction_type=rctt.name
                                                       and logtab.status='SUCCESS'
                                    						    )
                                                  ,aps.last_update_date)
      OR rct.last_update_date               >= NVL(
                                                   (select NVL(pd_activity_date,max(last_outbound_date)) 
                                                    from xxar_invoice_out_int_log logtab
                                                   where 1=1
                                                     and logtab.transaction_source=rbs.name
                                                     and logtab.transaction_type=rctt.name
                                                     and logtab.status='SUCCESS'
                                                  )
                                                  , rct.last_update_date) )
      GROUP BY rbs.name ,
        rctt.name 
      ORDER BY rctt.name,
        rbs.name ;     
  BEGIN    

    log_msg('In insert_outbound_log_table procedure');
    
    FOR r_sources IN c_sources(pv_trx_type,pd_activity_date)
    LOOP
    
      log_msg('inserting a new record in xxar_invoice_out_int_log table for p_trx_type:'||pv_trx_type);
      INSERT
      INTO xxar_invoice_out_int_log VALUES
      (
      g_request_id,
      r_sources.transaction_source,
      r_sources.transaction_type,
      NULL,		-- last outbound date is NULL, the same is updated upon successful completion -- check this
      NULL,
      NULL,
      l_user_id,
      sysdate,
      l_user_id,
      sysdate
      );
      
     END LOOP;
     
     
  EXCEPTION WHEN OTHERS THEN
    log_msg(g_error||' While inserting log records in xxar_invoice_out_int_log'||SQLERRM);
    RAISE ex_other_outbound_date;
  END insert_outbound_log_table;

-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      get_last_outbound_date
--  PURPOSE
--      Checks an existing record in outbound interface log table and returns last outbound date if exists
-- inserts a new record for the first run of interface with transaction type and source parameters
-- --------------------------------------------------------------------------------------------------
  PROCEDURE get_last_outbound_date(
      pv_trx_type  IN VARCHAR2,
      pv_source    IN VARCHAR2,
      pd_last_outbound_date OUT DATE
      )
  IS
    l_user_id             NUMBER := fnd_profile.value('USER_ID');
    ld_last_outbound_date DATE;
  BEGIN
    
    pd_last_outbound_date := NULL;
    
    SELECT last_outbound_date
    INTO pd_last_outbound_date
    FROM xxar_invoice_out_int_log
    WHERE transaction_source = pv_source
    AND transaction_type     = pv_trx_type;    
    
    /* This is written based on ideal outbound interface 
    IF ld_last_outbound_date IS NOT NULL THEN
       IF (NVL(pd_date,SYSDATE) < ld_last_outbound_date) THEN
          log_msg('In get_last_outbound_date: last outbound date '||ld_last_outbound_date||' is beyond given date '||pd_date);
          pd_last_outbound_date := ld_last_outbound_date;
       END IF;
    ELSE
       log_msg('last_outbound_date is NULL for transaction type:'||pv_trx_type||' transaction source:'||pv_source);
       RAISE ex_other_outbound_date;
    END IF;
    */   
       
  EXCEPTION 
  WHEN NO_DATA_FOUND THEN
    --insert
    log_msg('inserting a new record in xxar_invoice_out_int_log table for p_trx_type:'||pv_trx_type||' and pv_source:'||pv_source);
    INSERT
    INTO xxar_invoice_out_int_log VALUES
      (
        g_request_id,
        pv_source,
        pv_trx_type,
        NULL,		-- last outbound date is NULL, the same is updated upon successful completion -- check this
        NULL,
        NULL,
        l_user_id,
        sysdate,
        l_user_id,
        sysdate
      );
  WHEN OTHERS THEN
    log_msg(g_error||' in get_last_outbound_date'||SQLERRM);
    RAISE ex_other_outbound_date;
  END get_last_outbound_date;
-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      validate_transaction_type
--  PURPOSE
--      Validate invoice transaction type.
--       1) Must be in RA_CUST_TRX_TYPES
-- --------------------------------------------------------------------------------------------------
  PROCEDURE validate_transaction_type
    (
      p_trx_type IN VARCHAR2
    )
  IS
    l_trx_type fnd_lookup_values.lookup_code%TYPE;
  BEGIN
    IF p_trx_type IS NULL THEN
      log_msg('No Transaction type selected. Program runs for the below transaction types');
      FOR r_trx_types IN
      (SELECT rctt.name
        FROM ra_cust_trx_types rctt,
          fnd_lookup_values lv
        WHERE 1            =1
        AND lv.lookup_type = 'XXAR_INVOICE_OUTBOUND_TXN_TYPE'
        AND lv.meaning     = rctt.name
      )
      LOOP
        log_msg
        (
          r_trx_types.name
        )
        ;
      END LOOP;
    ELSE
      BEGIN
        SELECT rctt.name INTO l_trx_type 
         FROM ra_cust_trx_types rctt,
              fnd_lookup_values lv 
        WHERE rctt.name=p_trx_type 
          AND lv.lookup_type = 'XXAR_INVOICE_OUTBOUND_TXN_TYPE'
          AND lv.meaning=rctt.name;
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE ex_invalid_transation_type;
      END;
    END IF;
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE ex_invalid_transation_type;
  END validate_transaction_type;
-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      extract_records
--  PURPOSE
--      Extracts the invoices and exports as invidual files
--  PARAMETERS
--  p_trx_type
--  p_date_from
-- --------------------------------------------------------------------------------------------------
  PROCEDURE extract_records(
      p_trx_type  IN VARCHAR2 DEFAULT NULL,
      p_date_from IN DATE DEFAULT NULL )
  IS
    CURSOR c_sources(p_trx_type IN VARCHAR2, pd_activity_date IN DATE)
    IS
      SELECT --rctt.name transaction_type, ---29/Jun/2017
             rbs.name transaction_source -- transaction source
      FROM ra_customer_trx rct ,
           ra_batch_sources rbs ,
           ra_cust_trx_types rctt,
           hz_cust_accounts hca ,
           hz_parties hp ,
           ar_payment_schedules aps ,
           ar_receivable_applications ara,
           fnd_lookup_values lv
      WHERE 1                                =1
      AND lv.lookup_type                     = 'XXAR_INVOICE_OUTBOUND_TXN_TYPE'
      AND lv.meaning                         = rctt.name
      AND rctt.cust_Trx_type_id              =rct.cust_Trx_type_id
      AND hca.cust_account_id                = rct.bill_to_customer_id
      AND rbs.batch_source_id                = rct.batch_source_id
      AND hp.party_id                        = hca.party_id
      AND aps.customer_trx_id                = rct.customer_trx_id
      AND ara.applied_payment_schedule_id(+) = aps.payment_schedule_id
      AND rctt.name                          = NVL(p_trx_type,rctt.name)
      --29/Jun/2017
      AND ( aps.last_update_date            >= NVL(
                                                   (select NVL(pd_activity_date,max(last_outbound_date)) 
                                                      from xxar_invoice_out_int_log logtab
					                                           where 1=1
                                                       and logtab.transaction_source=rbs.name
                                                       and logtab.transaction_type=rctt.name
                                                       and logtab.status='SUCCESS'
                                    						    )
                                                  ,aps.last_update_date)
      OR rct.last_update_date               >= NVL(
                                                   (select NVL(pd_activity_date,max(last_outbound_date)) 
                                                    from xxar_invoice_out_int_log logtab
                                                   where 1=1
                                                     and logtab.transaction_source=rbs.name
                                                     and logtab.transaction_type=rctt.name
                                                     and logtab.status='SUCCESS'
                                                  )
                                                  , rct.last_update_date) )      
      --AND ( aps.last_update_date            >= NVL(pd_activity_date, aps.last_update_date)  --29/Jun/2017
      --OR rct.last_update_date               >= NVL(pd_activity_date, rct.last_update_date)  --29/Jun/2017
      GROUP BY rbs.name 
        --rctt.name  --29/Jun/2017
      ORDER BY --rctt.name, --29/Jun/2017
        rbs.name ; 
    l_last_outbound_date DATE;
    lv_buffer            VARCHAR2(1000);
    l_message            VARCHAR2(500);
    l_file_handle UTL_FILE.FILE_TYPE;
    z_file_temp_dir       CONSTANT VARCHAR2(150) := 'USER_TMP_DIR';
    z_file_temp_name      VARCHAR2(150);
    pr_dba_directory      VARCHAR2(250);
    pv_transaction_type   VARCHAR2(250);
    pv_transaction_source VARCHAR2(250);
    l_file_name           VARCHAR2(250);
    ld_runtime            DATE;
    ln_success_count      NUMBER:=0;
    l_outbound_dir        VARCHAR2(250);
    l_file_copy           INTEGER;
    lb_source_error       BOOLEAN := false;
    lb_program_found      BOOLEAN := false;
    lb_error_found        BOOLEAN := false;
    ln_file_copy_fail_cnt NUMBER:=0;
    l_trimmed_curr_source VARCHAR2(250);
  BEGIN
    -- fetch transaction source from ra_customer_trx_all
    log_msg('in extract_records procedure');
    
    insert_outbound_log_table(p_trx_type,p_date_from);  --29/Jun/2017
    
    FOR r_sources IN c_sources(p_trx_type, p_date_from)
    LOOP
    log_msg('=================================================================');
    log_msg('                                                                 ');
      -- check the table xxar_invoice_out_int_log to get the last_outbound_date , 
      -- if not insert one with transaction type, source, request_id and last_outbound_date
      --pv_transaction_type   := r_sources.transaction_type; --29/Jun/2017
      pv_transaction_type   := p_trx_type;  --29/Jun/2017
      pv_transaction_source := r_sources.transaction_source;
      lb_source_error := false;  
      l_last_outbound_date := null;
      log_msg('Caling get_last_outbound_date with params p_date_from:'||TO_CHAR(p_date_from,'DD-MON-YYYY HH24:MI:SS')||' and l_last_outbound_date:'||TO_CHAR(l_last_outbound_date,'DD-MON-YYYY HH24:MI:SS'));
      --get_last_outbound_date(pv_transaction_type, pv_transaction_source,l_last_outbound_date); --29/Jun/2017
      log_msg('After calling get_last_outbound_date with out params l_last_outbound_date:'||TO_CHAR(l_last_outbound_date,'DD-MON-YYYY HH24:MI:SS'));
      -- This is based on DDEV code. When date parameter is NOT NULL, the program is submitted with the date
      IF p_date_from IS NOT NULL THEN
        log_msg('Setting last outbound date as :'||TO_CHAR(l_last_outbound_date,'DD-MON-YYYY HH24:MI:SS'));
      	l_last_outbound_date := p_date_from;
      ELSE
      	IF l_last_outbound_date IS NOT NULL THEN
        	log_msg('p_date_from is null so look for last execution date for given transaction type is: '||TO_CHAR(l_last_outbound_date,'DD-MON-YYYY HH24:MI:SS'));
        END IF;
      END IF;
      
      /* -- This unit is developed based on ideal outbound interface
      -- Check whether data is extracted for the transaction type/ source for the given date (if date is provided)
      -- if date is null, it will fetch the last outbound and continued
      -- validate last outbound if data parameter is provided
      BEGIN
         l_last_outbound_date := NULL;
         get_last_outbound_date(pv_transaction_type, pv_transaction_source,l_last_outbound_date);
         IF l_last_outbound_date IS NOT NULL THEN
           RAISE ex_beyond_outbound_date;
         END IF;
      EXCEPTION
      WHEN ex_beyond_outbound_date THEN
        log_msg('** Warning: Data already fetched beyond the given date:'||p_date_from ||' Transaction type:'||r_sources.transaction_type||' Transaction source:'||r_sources.transaction_source);
        log_msg('** Last outbound date was:'||l_last_outbound_date);
        log_msg('** Program continues with other transaction type/source..');
        log_msg(sqlerrm);
        log_msg('** Aborting processing for source:'||pv_transaction_source);
        lb_source_error  := true;
        lb_error_found := true;
        CONTINUE;      
      END;
      */
      
      -- the extract
      log_msg('execuring c_inv cursor for :');
      log_msg('---------------------------------------------------');
      log_msg('Parameters:');
      log_msg('---------------------------------------------------');
      log_msg('User Transaction type parameter:'||p_trx_type);

      IF p_trx_type IS NULL THEN
        log_msg('User provided transaction type is null.....then get transaction type from cursor...');
        --log_msg('r_sources.transaction_type:'||r_sources.transaction_type);
      END IF;
      
      log_msg('pv_transaction_source:'||pv_transaction_source);
      log_msg('---------------------------------------------------');
      -- get outbound directory
      
      l_trimmed_curr_source := REPLACE(pv_transaction_source,' ','_'); -- if Source has spces replace with underscrore
      l_file_name           := TO_CHAR(sysdate, gc_date_format) || '_' || l_trimmed_curr_source || '.out';
      
      l_outbound_dir := xxint_common_pkg.interface_path ( p_application => 'AR', 
                                                          p_source => pv_transaction_source,
                                                          p_in_out => 'OUTBOUND', 
                                                          p_message => l_message );
      IF l_message   IS NOT NULL THEN
        log_msg('** Unable to find the outbound directory for p_application AR p_source '||pv_transaction_source
                                                                                         ||' p_in_out:'||'OUTBOUND'
                                                                                         ||' p_message'||l_message);
        log_msg('** Aborting processing for '||pv_transaction_source);
        lb_source_error  := true;
        lb_error_found := true;
        CONTINUE; -- return to next source
      END IF;
      -- Start writing into file
      -- derive file name
      -- open file handler
      BEGIN
        pr_dba_directory := NULL;
        SELECT directory_path
        INTO pr_dba_directory
        FROM dba_directories
        WHERE directory_name = z_file_temp_dir;
      EXCEPTION
      WHEN no_data_found THEN
        log_msg('** Error while retriving directory path for '||z_file_temp_dir);
      END;
      BEGIN
        l_file_handle := utl_file.fopen(z_file_temp_dir, l_file_name||'.tmp', 'w');
      EXCEPTION
      WHEN OTHERS THEN
        log_msg('** File ['||l_file_name||'.tmp'||'] could not be opened for writing in directory [' ||pr_dba_directory||']');
        log_msg(sqlerrm);
        log_msg('** Aborting processing for source:'||pv_transaction_source);
        lb_source_error  := true;
        lb_error_found := true;
        CONTINUE;
      END;
      /*
      ||-- write header
      */
      out_msg('******************************* Start spooling file: '||l_file_name);
      log_msg('Writing header...');
      BEGIN
        write_header(pv_transaction_source, l_last_outbound_date, l_file_handle);
      EXCEPTION
      WHEN OTHERS THEN
        log_msg('** Error writing Header record');
        log_msg(sqlerrm);
        log_msg('** Aborting processing for source:'||pv_transaction_source);
        utl_file.fclose(l_file_handle);
        lb_source_error := true;
        lb_error_found  := true;
        CONTINUE;
      END;
      /*
      ||-- write detail
      */
      log_msg('Writing detail records...');
      BEGIN
        write_detail(pv_transaction_type,pv_transaction_source, l_last_outbound_date, l_file_handle);
      EXCEPTION
      WHEN ex_no_detail_records THEN
        log_msg('** No invoices found for above parameters');
        log_msg('** Aborting processing for source:'||pv_transaction_source);
        utl_file.fclose(l_file_handle);
        lb_source_error := true;
        lb_error_found  := true;
        CONTINUE;      
      WHEN OTHERS THEN
        log_msg('** Error writing detail record');
        log_msg(sqlerrm);
        log_msg('** Aborting processing for source:'||pv_transaction_source);
        utl_file.fclose(l_file_handle);
        lb_source_error := true;
        lb_error_found  := true;
        CONTINUE;
      END;
      /*
      ||-- write trailer
      */
      log_msg('Writing trailer...');
      BEGIN
        write_trailer(l_file_handle);
        out_msg('          ');
        out_msg('******************************* End of spooling file: '||l_file_name);
        out_msg('          ');
      EXCEPTION
      WHEN OTHERS THEN
        log_msg('** Error writing detail record');
        log_msg(sqlerrm);
        log_msg('** Aborting processing for source:'||pv_transaction_source);
        utl_file.fclose(l_file_handle);
        lb_source_error := true;
        lb_error_found  := true;
        CONTINUE;
      END;
      -- close file
      BEGIN
        log_msg('Closing file...');
        utl_file.fclose(l_file_handle);
        -- WRITE FILE TO
        log_msg('Copying temporary file ' || pr_dba_directory ||'/'|| l_file_name||'.tmp' || ' to ' 
                                          || l_outbound_dir || '/' || l_file_name);
        l_file_copy := xxint_common_pkg.file_copy( p_from_path => pr_dba_directory||'/'|| l_file_name||'.tmp', 
                                                   p_to_path => l_outbound_dir || '/' || l_file_name);
        log_msg('File copy returned ' || l_file_copy);        
        IF NVL(l_file_copy,0) > 0 THEN
          log_msg('File copy successful. Removing temp file');        
          utl_file.fremove(z_file_temp_dir, l_file_name||'.tmp');
        ELSE
          RAISE ex_file_copy_error;
        END IF;
        log_msg('file closed');
      EXCEPTION
      WHEN ex_file_copy_error THEN
      	log_msg('** Error while copying temporary file from ' || pr_dba_directory ||'/'|| l_file_name||'.tmp' || ' to ' 
                                                              || l_outbound_dir || '/' || l_file_name);
        ln_file_copy_fail_cnt := ln_file_copy_fail_cnt+1;
      WHEN OTHERS THEN
        log_msg('** Error closing file ['||l_file_name||']');
        log_msg(sqlerrm);
        log_msg('** Aborting processing for source:'||pv_transaction_source);
-- if we consider failure of file copying is not a showstopper of updating log table with last outbound date, 
-- comment below
--      lb_source_error := true;
--      lb_error_found  := true;
        CONTINUE;
      END;
      -- capture the runtime
      ld_runtime := sysdate;
      /*
      || If successful record run date and running concurrent request id in xxar_invoice_out_int_log.
      */
      log_msg('Updating xxar_invoice_out_int_log when there are no errors and l_last_outbound_date is null');
      IF NOT lb_source_error THEN
         log_msg('lb_source_error is FALSE and l_last_outbound_date:'||l_last_outbound_date);
      ELSE
         log_msg('lb_source_error is TRUE and l_last_outbound_date:'||l_last_outbound_date);
      END IF;
      log_msg('pv_transaction_source and pv_transaction_type are: '||pv_transaction_source|| ' and '||pv_transaction_type);
      
      if l_last_outbound_date is null
      then
      	log_msg('l_last_outbound_date  is null');
      end if;
      
      BEGIN
        IF NOT (lb_source_error) AND l_last_outbound_date IS NULL  -- This condition is based on the code DDEV -- 
        THEN
          log_msg('Before xxar_invoice_out_int_log');
          UPDATE xxar_invoice_out_int_log
          SET 
            request_id           = g_request_id,
            last_update_date     = ld_runtime,
            last_updated_by      = fnd_profile.value('USER_ID'),
            last_outbound_date   = ld_runtime,
            status               = 'SUCCESS',
            MESSAGE              = 'Export completed'
          WHERE 1=1
          AND transaction_source = pv_transaction_source
          AND transaction_type   = pv_transaction_type;
          
          log_msg('updated xxar_invoice_out_int_log for source '
                  ||pv_transaction_source|| ' with run time ['
                  ||TO_CHAR(ld_runtime,'DD-MON-YYYY HH24:MI:SS') 
                  ||'] concurrent request ['||NVL(fnd_global.conc_request_id,-1)||']');
        END IF;
      EXCEPTION
      WHEN OTHERS THEN
        log_msg('** Error updating table xxar_invoice_out_int_log.');
        log_msg(sqlerrm);
        log_msg('** Aborting processing for '||pv_transaction_source);
        lb_source_error := true;
        lb_error_found  := true;
        utl_file.fclose(l_file_handle);
        CONTINUE;
      END;
      ln_success_count := ln_success_count + 1;
    END LOOP; -- for each transaction type
    
    
    log_msg('                                          ');
    log_msg('======== end of extract_records procedure ');
    log_msg('                                          ');
    
    
    -- Check for overall errors
    IF nvl(ln_success_count,0) = 0 THEN
      log_msg('No successful records');
      RAISE ex_no_source_successful;
    ELSIF ln_success_count > 0 AND lb_error_found THEN
      log_msg('Program partially successful');
      RAISE ex_partial_success;
    ELSIF ln_file_copy_fail_cnt > 0 THEN
      log_msg('Program failed during file processing');
      RAISE ex_file_copy_error;
    ELSE
      log_msg('Program completed successfully');
    END IF;
    
  EXCEPTION
  WHEN ex_file_copy_error THEN
     RAISE ex_file_copy_error;
  WHEN ex_no_source_successful THEN
     RAISE ex_no_source_successful;
  WHEN ex_other_outbound_date THEN     
     RAISE ex_other_outbound_date;
  WHEN ex_partial_success THEN
     RAISE ex_partial_success;
  WHEN OTHERS THEN
    IF utl_file.is_open(l_file_handle) THEN
      utl_file.fclose(l_file_handle);
    END IF;
    log_msg(g_error||' in extract() procedure: ' || SQLERRM);
    RAISE;
  END extract_records;
-- --------------------------------------------------------------------------------------------------
--  PROCEDURE
--      create_outbound_file_cp
--  PURPOSE
--       Concurrent Program XXARINVOUTINT (DEDJTR AR Outbound Invoice File Create)
--  DESCRIPTION
--       Main program
-- --------------------------------------------------------------------------------------------------
  PROCEDURE create_outbound_file_cp(
      p_errbuf    OUT VARCHAR2,
      p_retcode   OUT VARCHAR2,
      p_trx_type  IN VARCHAR2 DEFAULT NULL,
      p_date_from IN VARCHAR2 DEFAULT NULL )
  IS
    l_selection_date DATE;
    l_outbound_dir   VARCHAR2(100);
    l_file_name      VARCHAR2(100);
    l_message        VARCHAR2(500);
    l_date_from      DATE;
  BEGIN
    -- Initialise
    g_request_id := fnd_global.conc_request_id;
    xxint_common_pkg.g_object_type := 'INVOICES';  -- Added as interface directories are repointed to NFS -- Rao -- 19-JUN-2017
    log_msg('===== Launch  - DEDJTR AR Outbound Invoice File Create ===== ');
    log_msg('===== Program Parameters ===== ');
    log_msg('p_trx_type = '||p_trx_type);
    log_msg('p_date_from = '||p_date_from);
    -- validate and format date
    IF p_date_from IS NOT NULL THEN
      BEGIN
        log_msg('Validating date. Checks the date format as YYYY/MM/DD HH24:MI:SS');
        l_date_from := to_date(p_date_from, 'YYYY/MM/DD HH24:MI:SS');
      EXCEPTION
      WHEN OTHERS THEN
        log_msg(g_error||'Invalid date program exiting');
        raise ex_invalid_date;
      END;
    END IF;
    -- validate transation type
    log_msg('Validating transaction type..calling validate_transaction_type()');
    validate_transaction_type(p_trx_type);
    -- extract the data
    log_msg('Executing extract. Calling extract_records()');
    extract_records(p_trx_type,l_date_from);
    p_retcode := 0;
  EXCEPTION
  WHEN ex_partial_success THEN
    p_errbuf  := '** Some Feeder System files were NOT created.  Please refer the log for more information';
    log_msg(p_errbuf);
    p_retcode := 1; -- warning
  WHEN ex_file_copy_error THEN
    p_errbuf  := '** Error while copying the files to destination. Please refer to the log.';
    log_msg(p_errbuf);
    p_retcode := 1; -- warning      
  WHEN ex_no_source_successful THEN    
    p_errbuf := g_error || 'No Feeder System file is created for the selected transaction type [' 
                        || NVL(p_trx_type,'(s) listed in the log.') || ']. Please refer the log for more information.';
    log_msg(p_errbuf);
    p_retcode := 2;
  WHEN ex_invalid_transation_type THEN
    p_errbuf := g_error || 'Invalid transaction type ' || p_trx_type;
    log_msg(p_errbuf);
    p_retcode := 2;
  WHEN ex_invalid_date THEN
    p_errbuf  := '** Date is not in the correct format of ''DD-MON-YYYY HH24:MI:SS''';
    log_msg(p_errbuf);
    p_retcode := 2; -- error
  WHEN ex_other_outbound_date THEN
    p_errbuf := g_error ||' occured while retriving last outbound date ' || p_trx_type ;
    log_msg(p_errbuf);
    p_retcode := 2;
  END create_outbound_file_cp;
END xxar_inv_outbound_pkg;
/