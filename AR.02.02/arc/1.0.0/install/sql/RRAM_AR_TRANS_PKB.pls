create or replace package body rram_ar_trans_pkg
as
/* $Header: svn://d02584/consolrepos/branches/AR.02.02/arc/1.0.0/install/sql/RRAM_AR_TRANS_PKB.pls 2801 2017-10-13 04:12:47Z svnuser $ */
-- ============================================================================
--
--  PROGRAM:	  RRAM_AR_TRANS_PKB.pls
--
--  DESCRIPTION:
--      Creates package body rram_ar_trans_pkg.
--		  This package implements the Oracle side of the RRAM Invoice Interface.
--
--  AUTHOR      DATE		    COMMENT
--  ----------- ----------  ----------------------------------------------------
--  sryan       30/01/2015	initial
--  sryan       06/05/2015  replaced validation and error on duplicate transactions
--                          to updating the stage table with the existing transaction
--                          changed audit report to distinguish between New and Existing transactions
--  khoh        16/07/2015  added logic to reject duplicate transaction line
-- ============================================================================

    -- cursor for stage table rows
    cursor c_stage(p_interface_status in varchar2, p_conc_request_id in number default null) is
        select *
          from rram_ar_trans_stage
         where interface_status = p_interface_status
           and nvl(conc_request_id,-1) = nvl(p_conc_request_id, nvl(conc_request_id,-1))
         order by source_system_ref, line_number, stage_id;
         
    -- cursor to update duplicate transaction line in stage table
    cursor c_stage_dup(p_interface_status in varchar2, p_conc_request_id in number default null) is
         select *
           from rram_ar_trans_stage a
          where interface_status = p_interface_status
            and nvl(conc_request_id,-1) = nvl(p_conc_request_id, nvl(conc_request_id,-1))
            and (fee_number,line_number) in (
                select fee_number, line_number
                from rram_ar_trans_stage
                where interface_status = p_interface_status
                group by fee_number, line_number
                having count(*)>1)
            and stage_id <> (
                select min(stage_id)
                from rram_ar_trans_stage
                where interface_status = p_interface_status
                  and fee_number = a.fee_number
                  and line_number = a.line_number);

    -- custom types
    type t_derived_rec is record (
        batch_source_id         number,
        party_id                number,
        party_site_id           number,
        location_id             number,
        cust_acct_id            number,
        cust_acct_site_id       number,
        site_use_id             number,
        site_party_id           number,
        cust_trx_type_id        number,
        tax_code_id             number,
        tax_rate                number,
        tax_account_id          number,
        rev_gl_ccid             number,
        invoice_id              number,
        invoice_num             varchar2(30),
        uom_code                varchar2(3),
        stage_id                number -- used to initialize an instance
    );

    type t_derived_tbl is table of t_derived_rec index by binary_integer;

    -- collection types
    --type t_stage_tbl is table of c_stage%rowtype index by binary_integer;
    type t_stage_tbl        is table of c_stage%rowtype;
    type t_error_tbl is table of rram_interface_errors%rowtype index by binary_integer;

    -- global variables and constants
    g_error_tbl             t_error_tbl;
    g_max_fetch             constant number := 200;
    g_interface_type        constant varchar2(30) := 'ARTrans';
    g_deflt_uom_code        constant mtl_units_of_measure.uom_code%type := 'EA';
    g_request_id            number;
    g_default_source_id     number := 1062; -- 'MANUAL INVOICE'
    g_source_crn_identifier ra_batch_sources.attribute1%type;
    g_user_id               number;
    g_org_id                number;
    g_sob_id                number;
    g_coa_id                number;
    g_sob_currency          varchar2(15);
    g_conc_request_id       number;
    g_debug                 boolean := false;

    -- custom exceptions
    ex_invalid_apps_session         exception;
    ex_sob_not_found                exception;
    ex_source_not_found             exception;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      log_msg
    --  Purpose
    --      Logs messages to dbms_output or concurrent log if running as a concurrent program
    --  Parameters
    --      p_msg         Message to write
    --      p_proc_name   Name of the procedure where the message originates
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure log_msg(p_msg in varchar2, p_proc_name in varchar2 default null)
    is
        l_msg         varchar2(1000);
    begin
        if p_proc_name is not null then
            l_msg := p_proc_name || '() -> ' || p_msg;
        else
            l_msg := p_msg;
        end if;

        if nvl(g_conc_request_id,-1) = -1 then
            dbms_output.put_line(substr(l_msg,1,500));
        else
            fnd_file.put_line(fnd_file.log, substr(l_msg,1,500));
        end if;
    exception
        when others then
            fnd_file.put_line(fnd_file.log, sqlerrm);
            dbms_output.put_line(sqlerrm);
    end log_msg;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      debug_msg
    --  Purpose
    --      Logs debug messages if g_debug is on
    --  Parameters
    --      p_msg         Message to write
    --      p_proc_name   Name of the procedure where the message originates
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure debug_msg(p_msg in varchar2, p_proc_name in varchar2 default null)
    is
        l_msg         varchar2(1000);
    begin
        l_msg := to_char(sysdate,'HH24:MI:SS');
        if p_proc_name is not null then
            l_msg := l_msg || '  ' || p_proc_name || '() -> ' || p_msg;
        else
            l_msg := l_msg || '  ' || p_msg;
        end if;

        if g_debug then
            log_msg(l_msg);
        end if;
    end debug_msg;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      out_msg
    --  Purpose
    --      Writes messages to dbms_output or concurrent output file if running
    --      as a concurrent program
    --  Parameters
    --      p_msg         Message to write
    --      p_proc_name   Name of the procedure where the message originates
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure out_msg(p_msg in varchar2, p_proc_name in varchar2 default null)
    is
        l_msg     varchar2(500);
    begin
        if p_proc_name is not null then
            l_msg := p_proc_name || ': ' ||substr(p_msg,1,500);
        else
            l_msg := substr(p_msg,1,500);
        end if;

        if nvl(g_conc_request_id,-1) = -1 then
            dbms_output.put_line(l_msg);
        else
            fnd_file.put_line(fnd_file.output, l_msg);
        end if;
    end out_msg;

    -- ------------------------------------------------------------------------------------
    -- Procedure:   lookup_set_of_books
    -- Purpose:     Looks up set of books details.
    -- ------------------------------------------------------------------------------------
    procedure lookup_set_of_books(p_sob_id in number, p_sob_row in out nocopy gl_sets_of_books%rowtype)
    is
    begin
        select currency_code, chart_of_accounts_id
          into p_sob_row.currency_code
             , p_sob_row.chart_of_accounts_id
          from gl_sets_of_books
         where set_of_books_id = p_sob_id;
    exception
        when no_data_found then
            log_msg('Set of books '||p_sob_id||' could not be found!');
            raise ex_sob_not_found;
        when others then
            log_msg(sqlerrm, 'lookup_set_of_books');
            raise;
    end lookup_set_of_books;

    -- ------------------------------------------------------------------------------------
    -- Procedure:   lookup_source
    -- Purpose:     Looks up batch source details.
    -- ------------------------------------------------------------------------------------
    procedure lookup_source(p_source_id in number, p_batch_source_row in out nocopy ra_batch_sources%rowtype)
    is
    begin
        select batch_source_id, attribute1
          into p_batch_source_row.batch_source_id
             , p_batch_source_row.attribute1
          from ra_batch_sources
         where batch_source_id = p_source_id;
    exception
        when no_data_found then
            log_msg('Batch Source Id '||p_source_id||' could not be found!');
            raise ex_source_not_found;
        when others then
            log_msg(sqlerrm, 'lookup_source');
            raise;
    end lookup_source;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      initialise
    --  Purpose
    --      Resets globals and checks the apps session context
    --  Parameters
    --      p_debug       Debug flag (Y|N) to output additional flow information
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure initialise(p_debug in varchar2 default 'N')
    is
        l_sob_row           gl_sets_of_books%rowtype;
        l_source_row        ra_batch_sources%rowtype;
    begin
        g_user_id           := fnd_global.user_id;
        g_org_id            := fnd_global.org_id;
        g_conc_request_id   := fnd_global.conc_request_id;
        g_sob_id            := fnd_profile.value('GL_SET_OF_BKS_ID');
        lookup_set_of_books(g_sob_id, l_sob_row);
        g_coa_id            := l_sob_row.chart_of_accounts_id;
        g_sob_currency      := l_sob_row.currency_code;
        lookup_source(g_default_source_id, l_source_row);
        g_source_crn_identifier := l_source_row.attribute1;
        g_error_tbl.delete;

        if p_debug = 'Y' then
            g_debug := true;
            debug_msg('debug on');
        else
            g_debug := false;
        end if;

        if nvl(g_user_id,-1) = -1 or nvl(g_org_id,-1) = -1 then
            raise ex_invalid_apps_session;
        end if;
    exception
        when others then
            log_msg(sqlerrm, 'initialise');
            raise;
    end initialise;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      insert_errors
    --  Purpose
    --      Writes validation errors to the errors table
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure insert_errors
    is
    begin
        if g_error_tbl.count > 0 then
            forall i in 1..g_error_tbl.count
              insert into rram_interface_errors values g_error_tbl(i);
        end if;
    exception
        when others then
            log_msg(sqlerrm, 'insert_errors');
            raise;
    end insert_errors;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      add_error_record
    --  Purpose
    --      Adds an error message to the global error table collection
    --  Parameters
    --      p_stage_id    Identifier of the stage table row that caused the error
    --      p_error       Validation or generic error message
    --      p_api_error   Specific error from one of the debtor APIs
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure add_error_record(
        p_stage_id      in number,
        p_error         in varchar2,
        p_api_error     in varchar2 )
    is
        l_idx       number := g_error_tbl.count+1;
    begin
        g_error_tbl(l_idx).error_id         := rram_interface_errors_s1.nextval;
        g_error_tbl(l_idx).stage_id         := p_stage_id;
        g_error_tbl(l_idx).interface_type   := g_interface_type;
        g_error_tbl(l_idx).api_error        := substr(p_api_error,1,240);
        g_error_tbl(l_idx).error_message    := substr(p_error,1,240);
        g_error_tbl(l_idx).timestamp        := sysdate;
        g_error_tbl(l_idx).conc_request_id  := g_conc_request_id;
    exception
        when others then
            log_msg(sqlerrm, 'add_error_record');
            raise;
    end add_error_record;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      add_validation_error
    --  Purpose
    --      Adds a validation error message to the global error table collection
    --  Parameters
    --      p_stage_id    Identifier of the stage table row that caused the error
    --      p_error       Validation or generic error message
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure add_validation_error(p_stage_id in number, p_error in varchar2)
    is
    begin
        add_error_record(p_stage_id, p_error, null);
        log_msg('** Validation Error: '||p_error);
    exception
        when others then
            log_msg(sqlerrm, 'add_validation_error');
            raise;
    end add_validation_error;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      add_api_error
    --  Purpose
    --      Adds an API error message to the global error table collection
    --  Parameters
    --      p_stage_id    Identifier of the stage table row that caused the error
    --      p_api_error   API error
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure add_api_error(p_stage_id in number, p_api_error in varchar2)
    is
    begin
        add_error_record(p_stage_id, null, p_api_error);
        log_msg('** API Error: '||p_api_error);
    exception
        when others then
            log_msg(sqlerrm, 'add_api_error');
            raise;
    end add_api_error;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      update_stage_tbl_values
    --  Purpose
    --      Updates the interface_status column of stage table rows.
    --  Parameters
    --      p_stage_tbl   Stage table collection
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure update_stage_tbl_values(p_stage_tbl in out nocopy t_stage_tbl)
    is
    begin
        debug_msg('begin','update_stage_tbl_values');
        forall i in p_stage_tbl.first..p_stage_tbl.last
          update rram_ar_trans_stage
             set invoice_number     = p_stage_tbl(i).invoice_number,
                 invoice_id         = p_stage_tbl(i).invoice_id,
                 interface_status   = p_stage_tbl(i).interface_status,
                 conc_request_id    = g_conc_request_id,
                 last_update_date   = sysdate,
                 last_updated_by    = g_user_id
           where stage_id = p_stage_tbl(i).stage_id;
    exception
        when others then
            log_msg(sqlerrm, 'update_stage_tbl_values');
            raise;
    end update_stage_tbl_values;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      audit_report
    --  Purpose
    --      Writes an audit report to the concurrent request output file
    --  Parameters
    --      p_conc_request_id   Filters by the concurrent request id
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    --  sryan       06/05/2015  changed to distinguish between New and Existing transactions
    -- ------------------------------------------------------------------------
    procedure audit_report(p_conc_request_id in number)
    is
        l_new_count             number := 0;
        l_exist_count           number := 0;
        l_original_stage_id     number;
        l_action                varchar2(20);
        l_current_ref           rram_ar_trans_stage.source_system_ref%type;
        l_current_action        varchar2(10);

        cursor c_audit(p_conc_request_id in number)
        is
            select s.stage_id
                 , s.source_system_ref
                 , s.account_number
                 , s.party_site_number
                 , substr(nvl(hca.account_name, hp.party_name),1,28) as account_name
                 , rctt.name as trx_type_name
                 , rct.trx_number
                 , rct.customer_trx_id
                 , count(rctl.line_number) as line_count
                 , arps.amount_due_original as trx_amount
              from rram_ar_trans_stage s
                 , ra_customer_trx rct
                 , ra_customer_trx_lines rctl
                 , hz_cust_accounts hca
                 , ra_cust_trx_types rctt
                 , ar_payment_schedules arps
                 , hz_parties hp
             where s.conc_request_id = p_conc_request_id
               and s.line_number = 1
               and s.interface_status = G_INT_STATUS_PROCESSED
               and rct.customer_trx_id = s.invoice_id
               and rctl.customer_trx_id = rct.customer_trx_id
               and hca.cust_account_id = rct.bill_to_customer_id
               and hp.party_id = hca.party_id
               and rctt.cust_trx_type_id = rct.cust_trx_type_id
               and rctl.line_type <> 'TAX'
               and arps.customer_trx_id = rct.customer_trx_id
               and arps.status = 'OP'
               and arps.amount_due_original > 0
          group by s.stage_id, rct.trx_number, rct.customer_trx_id, rctt.name, s.account_number, s.party_site_number
                 , substr(nvl(hca.account_name, hp.party_name),1,28), s.source_system_ref, arps.amount_due_original
             order by 1;

        -- used to check whether the invoice id was already created by a previous stage row
        cursor c_original(p_invoice_id in number, p_stage_id in number)
        is
            select stage_id
              from rram_ar_trans_stage
             where invoice_id = p_invoice_id
               and interface_status = G_INT_STATUS_PROCESSED
               and stage_id < p_stage_id;


    begin
        -- report title
        out_msg( to_char(sysdate,'DD-MON-YYYY HH24:MM:SS')  || lpad(' ',33,' ') ||
            'RRAM Invoice Interface Audit Report' || lpad(' ',48,' ') ||
            'Request Id: '||p_conc_request_id);
        out_msg(' ');
        out_msg(' ');

        -- report heading
        out_msg(rpad('RRAM Reference',16,' ')   || '  ' ||
                lpad('Acct#',7,' ')             || '  ' ||
                lpad('Site#',8,' ')             || '  ' ||
                rpad('Account Name',30,' ')     || '  ' ||
                rpad('Action',8,' ')            || '  ' ||
                rpad('Type',20,' ')             || '  ' ||
                lpad('Trx Num',8,' ')           || '  ' ||
                lpad('Lines',5,' ')             || '  ' ||
                lpad('Amount',15,' ')
            );

        -- heading unerline
        out_msg(rpad('-',16,'-')  || '  ' ||
                lpad('-',7,'-')   || '  ' ||
                lpad('-',8,'-')   || '  ' ||
                rpad('-',30,'-')  || '  ' ||
                rpad('-',8,'-')   || '  ' ||
                rpad('-',20,'-')  || '  ' ||
                lpad('-',8,'-')   || '  ' ||
                lpad('-',5,'-')  || '  ' ||
                lpad('-',15,'-')
            );

        -- report content
        for r_audit in c_audit(p_conc_request_id)
        loop
            -- check to see whether the invoice_id was generated by a previous stage row
            l_original_stage_id := null;
            open c_original(r_audit.customer_trx_id, r_audit.stage_id);
            fetch c_original into l_original_stage_id;
            if l_original_stage_id is not null then
                l_exist_count := l_exist_count + 1;
                l_action := 'Existing';
            else
                l_new_count := l_new_count + 1;
                l_action := 'New';
            end if;
            close c_original;

            out_msg( rpad(r_audit.source_system_ref,16,' ') || '  ' ||
                lpad(r_audit.account_number,7,' ')        || '  ' ||
                lpad(r_audit.party_site_number,8,' ')     || '  ' ||
                rpad(r_audit.account_name,30,' ')         || '  ' ||
                rpad(l_action,8,' ')                      || '  ' ||
                rpad(r_audit.trx_type_name,20,' ')        || '  ' ||
                lpad(r_audit.trx_number,8,' ')            || '  ' ||
                lpad(r_audit.line_count,5,' ')            || '  ' ||
                lpad(to_char(r_audit.trx_amount,'999,999,990.00'),15,' ' ) /* TODO if time permis format this based on currency */
            );

        end loop;
        out_msg(' ');
        out_msg('Total New Transactions:   '|| l_new_count);
        out_msg('Total Existing Transactions:   '|| l_exist_count);
    exception
        when others then
            if c_original%isopen then
                close c_original;
            end if;
            log_msg(sqlerrm, 'audit_report');
            raise;
    end audit_report;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      error_report
    --  Purpose
    --      Writes an error report to the concurrent request output file
    --  Parameters
    --      p_conc_request_id   Filters by the concurrent request id
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    --  khoh        16/07/2015  added logic for duplicate transaction line
    -- ------------------------------------------------------------------------
    procedure error_report(p_conc_request_id in number)
    is
        l_error_count     number := 0;
        l_trans_count     number := 0;
        l_prev_stage_id   number := 0;
        
        --Modified by khoh on 16/07/2015
        cursor c_stage(p_conc_request_id in number)
        is  
            select s.source_system_ref
                 , s.account_number
                 , s.party_site_number
                 , nvl(substr(nvl(hca.account_name, hp.party_name),1,28),'-') as organization_name
                 , s.stage_id
                 , 'RRAM_AR_TRANS_STAGE' as interface_table
                 , decode(s.interface_status, 'D', 'Duplicate row', nvl(e.api_error, e.error_message)) as error_message  
              from rram_ar_trans_stage s
                 , hz_cust_accounts hca
                 , rram_interface_errors e
                 , hz_parties hp
             where s.conc_request_id = p_conc_request_id
               and (s.interface_status = G_INT_STATUS_ERROR or s.interface_status = G_INT_STATUS_DUPLICATE)
               and hca.account_number(+) = s.account_number
               and hp.party_id(+) = hca.party_id
               and e.stage_id (+) = s.stage_id
               and e.interface_type (+) = g_interface_type
               and e.conc_request_id (+) = s.conc_request_id
             order by s.stage_id;
    begin
        -- report heading
        out_msg(' ');
        out_msg('------------------------------------------------ Error Report ------------------------------------------------');
        out_msg(rpad('RRAM Reference',16,' ')   || '  ' ||
                rpad('Stage Table',19,' ')      || '  ' ||
                lpad('Id',6,' ')                || '  ' ||
                lpad('Acct#',7,' ')             || '  ' ||
                lpad('Site#',8,' ')             || '  ' ||
                rpad('Account Name',30,' ')     || '  ' ||
                rpad('Error Message',90,' ')
            );

        -- heading unerline
        out_msg(rpad('-',16,'-')  || '  ' ||
                rpad('-',19,'-')   || '  ' ||
                lpad('-',6,'-')   || '  ' ||
                lpad('-',7,'-')   || '  ' ||
                lpad('-',8,'-')   || '  ' ||
                rpad('-',30,'-')  || '  ' ||
                rpad('-',90,'-')
            );

        -- report content
        for r_stage in c_stage(p_conc_request_id)
        loop
            l_error_count := l_error_count + 1;
            if l_prev_stage_id != r_stage.stage_id then
                l_trans_count := l_trans_count + 1;
                out_msg( rpad(r_stage.source_system_ref,16,' ') || '  ' ||
                    rpad(r_stage.interface_table,19,' ')        || '  ' ||
                    lpad(r_stage.stage_id,6,' ')                || '  ' ||
                    lpad(r_stage.account_number,7,' ')          || '  ' ||
                    lpad(r_stage.party_site_number,8,' ')       || '  ' ||
                    rpad(r_stage.organization_name,30,' ')      || '  ' ||
                    rpad(r_stage.error_message,90,' ')
                    );
            else
                out_msg( rpad(' ' ,16,' ') || '  ' ||
                    rpad(' ',19,' ')       || '  ' ||
                    lpad(' ',6,' ')        || '  ' ||
                    lpad(' ',7,' ')        || '  ' ||
                    lpad(' ',8,' ')        || '  ' ||
                    rpad(' ',30,' ')       || '  ' ||
                    rpad(r_stage.error_message,90,' ')
                    );
            end if;
            l_prev_stage_id := r_stage.stage_id;
        end loop;
        out_msg(' ');
        out_msg('Total Errors: '||lpad(l_error_count,5,' '));
        out_msg('Total Lines:  '||lpad(l_trans_count,5,' '));
    exception
        when others then
            log_msg(sqlerrm, 'error_report');
            raise;
    end error_report;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      set_stage_row_status
    --  Purpose
    --      Updates the stage table rows with new values.
    --  Parameters
    --      p_stage_tbl         Stage table collection
    --      p_derived_tbl       Derived table collection
    --      p_trx_start_idx     Index of the first line of the invoice
    --      p_trx_end_idx       Index of the last line of the invoice
    --      p_status            New interface status value
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure set_stage_row_status(
        p_stage_tbl           in out nocopy t_stage_tbl,
        p_derived_tbl         in out nocopy t_derived_tbl,
        p_trx_start_idx       in number,
        p_trx_end_idx         in number,
        p_status              in varchar2
    )
    is
    begin
        for i in p_trx_start_idx..p_trx_end_idx
        loop
            p_stage_tbl(i).interface_status := p_status;
            p_stage_tbl(i).invoice_id := p_derived_tbl(p_trx_start_idx).invoice_id;
            p_stage_tbl(i).invoice_number := p_derived_tbl(p_trx_start_idx).invoice_num;
        end loop;
    exception
        when others then
            log_msg(sqlerrm, 'set_stage_row_status');
            raise;
    end set_stage_row_status;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      set_stage_rows_related_error
    --  Purpose
    --      Updates the stage table rows with new values.
    --  Parameters
    --      p_stage_tbl         Stage table collection
    --      p_trx_start_idx     Index of the first line of the invoice
    --      p_trx_end_idx       Index of the last line of the invoice
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure set_stage_rows_related_error(
        p_stage_tbl           in out nocopy t_stage_tbl,
        p_trx_start_idx       in number,
        p_trx_end_idx         in number )
    is
    begin
        for i in p_trx_start_idx..p_trx_end_idx
        loop
            if p_stage_tbl(i).interface_status = G_INT_STATUS_NEW then
                p_stage_tbl(i).interface_status := G_INT_STATUS_ERROR;
                add_validation_error(p_stage_tbl(i).stage_id, 'This line passed validation but a related line did not');
            end if;
        end loop;
    exception
        when others then
            log_msg(sqlerrm, 'set_stage_rows_related_error');
            raise;
    end set_stage_rows_related_error;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      lookup_user
    --  Purpose
    --      Looks up an applications user by user_name from the fnd_user table
    --      Must be an active user
    --  Parameters
    --      p_user_name         User name to lookup
    --      p_user_id           Returned user_id
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure lookup_user(p_user_name in varchar2, p_user_id out number)
    is
    begin
        select user_id into p_user_id
        from fnd_user
        where user_name = p_user_name
          and sysdate between start_date and nvl(end_date, sysdate+1);
    exception
        when no_data_found then
            p_user_id := null;
        when others then
            log_msg(sqlerrm, 'lookup_user');
            raise;
    end lookup_user;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      lookup_trx_type_by_name
    --  Purpose
    --      Looks up a transaction type by name
    --  Parameters
    --      p_cust_trx_type_name    Transaction Type name
    --      p_cust_trx_type_row     Transaction Type row
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure lookup_trx_type_by_name(p_cust_trx_type_name in varchar2, p_cust_trx_type_row in out nocopy ra_cust_trx_types%rowtype)
    is
    begin
        debug_msg('begin','lookup_trx_type_by_name');
        select cust_trx_type_id, status, start_date, end_date, type, name
         into p_cust_trx_type_row.cust_trx_type_id,
              p_cust_trx_type_row.status,
              p_cust_trx_type_row.start_date,
              p_cust_trx_type_row.end_date,
              p_cust_trx_type_row.type,
              p_cust_trx_type_row.name
          from ra_cust_trx_types
         where name =  p_cust_trx_type_name
           and nvl(status,'A') = 'A'
           and sysdate between start_date and nvl(end_date ,sysdate+1);
    exception
        when no_data_found then
            p_cust_trx_type_row.cust_trx_type_id := null;
            p_cust_trx_type_row.status := null;
            p_cust_trx_type_row.start_date := null;
            p_cust_trx_type_row.end_date := null;
        when others then
            log_msg(sqlerrm, 'lookup_trx_type_by_name');
            raise;
    end lookup_trx_type_by_name;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      lookup_trans_by_so
    --  Purpose
    --      Looks up a transaction by sales order
    --  Parameters
    --      p_so_number         Sales Order number
    --      p_customer_trx_row  Transaction row
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure lookup_trans_by_so(
        p_so_number             in varchar2,
        p_customer_trx_row      in out nocopy ra_customer_trx%rowtype)
    is
        cursor c_sales_order(p_so_number in varchar2)
        is
            select distinct rct.customer_trx_id, rct.creation_date, rct.trx_number
              from ra_customer_trx rct
                 , ra_customer_trx_lines rctl
             where rctl.customer_trx_id = rct.customer_trx_id
               and rctl.line_type = 'LINE'
               and rctl.sales_order = p_so_number;

        r_sales_order       c_sales_order%rowtype;
    begin
        debug_msg('begin','lookup_trans_by_so');
        open c_sales_order(p_so_number);
        fetch c_sales_order into r_sales_order;
        if c_sales_order%found then
            p_customer_trx_row.customer_trx_id := r_sales_order.customer_trx_id;
            p_customer_trx_row.creation_date := r_sales_order.creation_date;
            p_customer_trx_row.trx_number := r_sales_order.trx_number;
        else
            p_customer_trx_row.customer_trx_id := null;
            p_customer_trx_row.creation_date := null;
            p_customer_trx_row.trx_number := null;
        end if;
        close c_sales_order;
    exception
        when others then
            log_msg(sqlerrm, 'lookup_trans_by_so');
            if c_sales_order%isopen then
                close c_sales_order;
            end if;
            raise;
    end lookup_trans_by_so;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      lookup_account_by_number
    --  Purpose
    --      Looks up a customer account by account number
    --      Must be an active account
    --  Parameters
    --      p_account_number    Account number to lookup
    --      p_derived_rec       Derived values record
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure lookup_account_by_number(
        p_account_number    in varchar2,
        p_derived_rec       in out nocopy t_derived_rec  )
    is
    begin
        debug_msg('begin','lookup_account_by_number');
        if p_account_number is not null then
            select hca.party_id, hca.cust_account_id
              into p_derived_rec.party_id, p_derived_rec.cust_acct_id
              from hz_cust_accounts hca
             where hca.account_number = p_account_number
               and hca.status = 'A';
        end if;
    exception
        when no_data_found then
            debug_msg(p_account_number||' not found','lookup_account_by_number');
            p_derived_rec.party_id := null;
            p_derived_rec.cust_acct_id := null;
        when others then
            log_msg(sqlerrm, 'lookup_account_by_number');
            raise;
    end lookup_account_by_number;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      lookup_site_by_number
    --  Purpose
    --      Looks up an account site by Site Number
    --      Must be an active site
    --  Parameters
    --      p_site_number       Site Number
    --      p_derived_rec       Derived values record
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure lookup_site_by_number(
        p_site_number       in varchar2,
        p_derived_rec       in out nocopy t_derived_rec )
    is
    begin
        debug_msg('begin','lookup_site_by_number');
        if p_site_number is not null then
            select hcas.cust_acct_site_id, hcas.party_site_id, hps.location_id, hps.party_id
              into p_derived_rec.cust_acct_site_id
                 , p_derived_rec.party_site_id
                 , p_derived_rec.location_id
                 , p_derived_rec.site_party_id
              from hz_cust_acct_sites_all hcas
                 , hz_party_sites hps
             where hps.party_site_id = hcas.party_site_id
               and hps.party_site_number = p_site_number
               and hcas.org_id = g_org_id
               and hcas.status = 'A';
        end if;
    exception
        when no_data_found then
            debug_msg(p_site_number||' not found','lookup_site_by_number');
            p_derived_rec.cust_acct_site_id := null;
            p_derived_rec.party_site_id := null;
            p_derived_rec.location_id := null;
            p_derived_rec.site_party_id := null;
        when others then
            log_msg(sqlerrm, 'lookup_site_by_number');
            raise;
    end lookup_site_by_number;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      lookup_tax_code
    --  Purpose
    --      Looks up the tax code row by tax code.
    --  Parameters
    --      p_tax_code      Tax Code
    --      p_derived_rec   Derived values record
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure lookup_tax_code(
        p_tax_code          in varchar2,
        p_derived_rec       in out nocopy t_derived_rec )
    is
    begin
        debug_msg('begin','lookup_site_by_number');
        if p_tax_code is not null then
            select vat_tax_id
                 , tax_account_id
                 , tax_rate
              into p_derived_rec.tax_code_id
                 , p_derived_rec.tax_account_id
                 , p_derived_rec.tax_rate
             from ar_vat_tax
            where tax_code = p_tax_code
              and enabled_flag= 'Y'
              and org_id = g_org_id
              and sysdate between start_date and nvl(end_date, sysdate+1);
        end if;
    exception
        when no_data_found then
            debug_msg(p_tax_code||' not found','lookup_tax_code');
            p_derived_rec.tax_code_id := null;
            p_derived_rec.tax_account_id := null;
        when others then
            log_msg(sqlerrm, 'lookup_tax_code');
            raise;
    end lookup_tax_code;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      lookup_account_ccid
    --  Purpose
    --      Looks up the gl account code combination id of an account string.
    --  Parameters
    --      p_account_string    Account string
    --      p_ccid              Code combination id
    --      p_msg               Return error message from fnd_flex_ext.
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure lookup_account_ccid(p_account_string in varchar2, p_ccid out number, p_msg out varchar2)
    is
        l_ccid        number;
    begin
        debug_msg('begin','lookup_account_ccid');
        l_ccid := fnd_flex_ext.get_ccid('SQLGL', 'GL#', g_coa_id, to_char(sysdate,fnd_flex_ext.date_format), p_account_string);
        if nvl(l_ccid,0) = 0 then
            p_msg := substr(fnd_flex_ext.get_message,1,240);
            p_ccid := null;
        else
            p_ccid := l_ccid;
            p_msg := null;
        end if;
    exception
        when others then
            log_msg(sqlerrm, 'lookup_account_ccid');
            raise;
    end lookup_account_ccid;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      lookup_currency_by_code
    --  Purpose
    --      Looks up the currency from the currency code.
    --  Parameters
    --      p_currency_code     3 character currency code
    --      p_currency_row      Currencies Row
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure lookup_currency_by_code(p_currency_code in varchar2, p_currency_row in out nocopy fnd_currencies%rowtype)
    is
    begin
        debug_msg('begin','lookup_currency_by_code');
        select currency_code
          into p_currency_row.currency_code
          from fnd_currencies
         where currency_code = p_currency_code
           and enabled_flag = 'Y'
           and sysdate between nvl(start_date_active,sysdate-1) and nvl(end_date_active,sysdate+1)
           and currency_flag = 'Y';
    exception
        when no_data_found then
            p_currency_row.currency_code := null;
        when others then
            log_msg(sqlerrm, 'lookup_currency_by_code');
            raise;
    end lookup_currency_by_code;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      lookup_uom_by_code
    --  Purpose
    --      Looks up the unit of measure from the uom code.
    --  Parameters
    --      p_currency_code     3 character currency code
    --      p_currency_row      Currencies Row
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure lookup_uom_by_code(p_uom_code in varchar2, p_uom_row in out nocopy mtl_units_of_measure%rowtype)
    is
    begin
        debug_msg('begin','lookup_uom_by_code');
        select uom_code
          into p_uom_row.uom_code
          from mtl_units_of_measure
         where uom_code = p_uom_code
           and sysdate < nvl(disable_date,sysdate+1);
    exception
        when no_data_found then
            p_uom_row.uom_code := null;
        when others then
            log_msg(sqlerrm, 'lookup_uom_by_code');
            raise;
    end lookup_uom_by_code;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      lookup_site_use_by_use
    --  Purpose
    --      Looks up an account site use by use Location
    --      Must be an active site use and the primary
    --  Parameters
    --      p_use               Use Code, usually 'BILL-TO'
    --      p_derived_rec       Derived values record
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure lookup_site_use_by_use(
        p_use               in varchar2 default 'BILL_TO',
        p_derived_rec       in out nocopy t_derived_rec )
    is
    begin
        debug_msg('begin','lookup_site_use_by_use');
        if p_derived_rec.cust_acct_site_id is not null then
            select hcasu.site_use_id
              into p_derived_rec.site_use_id
              from hz_cust_site_uses hcasu
             where hcasu.cust_acct_site_id = p_derived_rec.cust_acct_site_id
               and hcasu.site_use_code = p_use
               and hcasu.status = 'A';
--               and hcasu.primary_flag = 'Y';
        end if;
    exception
        when no_data_found then
            debug_msg(p_use||' not found','lookup_site_use_by_use');
            p_derived_rec.site_use_id := null;
        when others then
            log_msg(sqlerrm, 'lookup_site_use_by_use');
            raise;
    end lookup_site_use_by_use;

    -- ------------------------------------------------------------------------
    --  Function
    --      get_trx_number
    --  Purpose
    --      Queries the invoice number from the id.
    --  Parameters
    --      p_cust_trx_id   Invoice Id
    --  Returns
    --      Invoice Number
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    function get_trx_number(p_cust_trx_id in number) return varchar2
    is
        l_trx_num         ra_customer_trx.trx_number%type;
    begin
        select trx_number into l_trx_num
          from ra_customer_trx
         where customer_trx_id = p_cust_trx_id;
        return l_trx_num;
    exception
        when no_data_found then
            return null;
        when others then
            log_msg(sqlerrm, 'get_trx_number');
            raise;
    end get_trx_number;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      validate_stage_row_columns
    --  Purpose
    --      Performs custom validation on a stage table row.
    --      Any lookups such as internals ids are stoted in a derived collection
    --  Parameters
    --      p_stage_tbl     Stage table collection
    --      p_derived_tbl   Derived values collection
    --      i               Index of stage table row to validate
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    --  sryan       06/05/2015  removed validation error if an existing invoice exists.
    --                          instead the stage table will be updated with the existing id and number
    -- ------------------------------------------------------------------------
    procedure validate_stage_row_columns(
        p_stage_tbl     in out nocopy t_stage_tbl,
        p_derived_tbl   in out nocopy t_derived_tbl,
        i               in number )
    is
        l_error_found                 boolean := false;
        l_cust_trx_type_row           ra_cust_trx_types%rowtype;
        l_currency_row                fnd_currencies%rowtype;
        l_customer_trx_row            ra_customer_trx%rowtype;
        l_uom_row                     mtl_units_of_measure%rowtype;
        l_fnd_flex_ext_msg            varchar2(240);
    begin
        debug_msg('begin','validate_stage_row_columns');

        -- Check whether the transaction already exists (by fee number)
        -- First by checking previous lines - if the fee number is the same and it has alreadt been found, don't look it up again
        if i > 1 and
            nvl(p_stage_tbl(i-1).fee_number,'xnull') = nvl(p_stage_tbl(i).fee_number,'ynull') and
            p_derived_tbl(i-1).invoice_id is not null and
            p_derived_tbl(i-1).invoice_num is not null
        then
            debug_msg('invoice already exists from lookup of a previous stage id '|| p_stage_tbl(i-1).stage_id
                ||' [trx_number='||p_derived_tbl(i-1).invoice_num||']','validate_stage_row_columns');
            p_derived_tbl(i).invoice_id := p_derived_tbl(i-1).invoice_id;
            p_derived_tbl(i).invoice_num := p_derived_tbl(i-1).invoice_num;
            debug_msg('no need for further validation','validate_stage_row_columns');
            return;
        else
            lookup_trans_by_so(p_stage_tbl(i).fee_number, l_customer_trx_row);
            if l_customer_trx_row.customer_trx_id is not null then
                debug_msg('invoice already exists [trx_number='||l_customer_trx_row.trx_number||']','validate_stage_row_columns');
                p_derived_tbl(i).invoice_id := l_customer_trx_row.customer_trx_id;
                p_derived_tbl(i).invoice_num := l_customer_trx_row.trx_number;
                debug_msg('no need for further validation','validate_stage_row_columns');
                return;
            end if;
        end if;

        -- Batch Source must be valid
        if p_stage_tbl(i).source_system = 'RRAM' then
            p_derived_tbl(i).batch_source_id := g_default_source_id;
        else
            add_validation_error(p_stage_tbl(i).stage_id, 'Invalid SOURCE_SYSTEM '''
                ||p_stage_tbl(i).source_system||'''');
            l_error_found := true;
        end if;

        -- Transation Type must be valid
        lookup_trx_type_by_name(p_stage_tbl(i).trans_type, l_cust_trx_type_row);
        if  l_cust_trx_type_row.cust_trx_type_id is not null then
            p_derived_tbl(i).cust_trx_type_id := l_cust_trx_type_row.cust_trx_type_id;
        else
            add_validation_error(p_stage_tbl(i).stage_id, 'Invalid TRANS_TYPE '''
                ||p_stage_tbl(i).trans_type||'''.  Not found');
            l_error_found := true;
        end if;

        -- Customer Account must exist
        lookup_account_by_number(p_stage_tbl(i).account_number, p_derived_tbl(i));
        if p_derived_tbl(i).cust_acct_id is null then
            add_validation_error(p_stage_tbl(i).stage_id, 'Invalid ACCOUNT_NUMBER '''
                || p_stage_tbl(i).account_number||'''.  Not found');
            l_error_found := true;
        end if;

        -- Party Site Number must exist in Oracle and be associated with the party
        if p_derived_tbl(i).cust_acct_id is not null then
            lookup_site_by_number(p_stage_tbl(i).party_site_number, p_derived_tbl(i));
            if p_derived_tbl(i).cust_acct_site_id is null then
                add_validation_error(p_stage_tbl(i).stage_id, 'Invalid PARTY_SITE_NUMBER '''
                    || p_stage_tbl(i).party_site_number||'''.  Not found');
                l_error_found := true;
            elsif p_derived_tbl(i).site_party_id <> p_derived_tbl(i).party_id then
                add_validation_error(p_stage_tbl(i).stage_id, 'Invalid ACCOUNT_NUMBER/PARTY_SITE_NUMBER combination');
                l_error_found := true;
            end if;
        end if;

        -- Site must have a Bill-to use
        if p_derived_tbl(i).cust_acct_site_id is not null then
            lookup_site_use_by_use('BILL_TO', p_derived_tbl(i));
            if p_derived_tbl(i).site_use_id is null then
                add_validation_error(p_stage_tbl(i).stage_id, 'Account Site '||p_stage_tbl(i).party_site_number
                    ||' does not have a primary Bill-To use defined');
                l_error_found := true;
            end if;
        end if;

        -- Tax Code must exist in Oracle
        lookup_tax_code(p_stage_tbl(i).tax_code, p_derived_tbl(i));
        if p_derived_tbl(i).tax_code_id is null then
            add_validation_error(p_stage_tbl(i).stage_id, 'Invalid TAX_CODE '''
                || p_stage_tbl(i).tax_code||'''.  Not found');
            l_error_found := true;
        end if;

        -- Currency Code must be valid
        lookup_currency_by_code(p_stage_tbl(i).currency_code, l_currency_row);
        if l_currency_row.currency_code is null then
            add_validation_error(p_stage_tbl(i).stage_id, 'Invalid CURRENCY_CODE '''
                || p_stage_tbl(i).currency_code||'''.  Not found');
            l_error_found := true;
        end if;

        -- Use the Unit of Measure if it exists, else use the default
        lookup_uom_by_code(p_stage_tbl(i).unit_of_measure, l_uom_row);
        if l_uom_row.uom_code is null then
            log_msg('UNIT_OF_MEASURE '''|| p_stage_tbl(i).unit_of_measure||'''.  Not found.  Using '||g_deflt_uom_code||' instead');
            p_derived_tbl(i).uom_code := g_deflt_uom_code;
        else
            p_derived_tbl(i).uom_code := l_uom_row.uom_code;
        end if;

        -- Revenue Account must be valid
        lookup_account_ccid(p_stage_tbl(i).revenue_account, p_derived_tbl(i).rev_gl_ccid, l_fnd_flex_ext_msg);
        if p_derived_tbl(i).rev_gl_ccid is null then
            add_validation_error(p_stage_tbl(i).stage_id, 'Invalid REVENUE_ACCOUNT '''
                || p_stage_tbl(i).revenue_account||'''.  '||l_fnd_flex_ext_msg);
            l_error_found := true;
        end if;

        debug_msg('cust_acct_id='||p_derived_tbl(i).cust_acct_id||'; '||
            'cust_acct_site_id='||p_derived_tbl(i).cust_acct_site_id||'; '||
            'site_use_id='||p_derived_tbl(i).site_use_id||'; '||
            'cust_trx_type_id='||p_derived_tbl(i).cust_trx_type_id||'; '||
            'tax_code_id='||p_derived_tbl(i).tax_code_id||'; '||
            'rev_gl_ccid='||p_derived_tbl(i).rev_gl_ccid||'; ', 'validate_stage_row_columns');

        -- mark the interface status as errored if validation errors occurred
        if l_error_found then
            p_stage_tbl(i).interface_status := G_INT_STATUS_ERROR;
        end if;
    exception
        when others then
            log_msg(sqlerrm, 'validate_stage_row_columns');
            raise;
    end validate_stage_row_columns;
    
    -- ------------------------------------------------------------------------
    --  Procedure
    --      generate_crn
    --  Purpose
    --      Calls the custom generate_crn API to generate a crn and update the transactions ATTRIBUTE7 column
    --  Parameters
    --      p_crn_identifier        CRN Identifier (first 3 digits of CRN)
    --      p_customer_trx_id       Transaction Id of invoice to update
    --  Author      Date		  Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       05/07/2017  Added to support CRN functionality (DTPLI consolidation project)
    -- ------------------------------------------------------------------------
    procedure generate_crn(p_crn_identifier in varchar2, p_customer_trx_id in number)
    is
       l_crn                  varchar2(20);
       l_status               varchar2(3);
       l_crn_msg              varchar2(100);
    begin
       l_crn := xxar_invoices_interface_pkg.generate_crn(p_crn_identifier, p_customer_trx_id, l_status, l_crn_msg);
       debug_msg('generate_crn status|message = ' || l_status || '|' || l_crn_msg, 'generate_crn');
       if l_status = 'S' then
           update ra_customer_trx
              set attribute7 = l_crn
            where customer_trx_id = p_customer_trx_id;
           debug_msg('Updated transaction CRN to ' || l_crn, 'generate_crn');
       end if;
    end generate_crn;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      create_single_invoice
    --  Purpose
    --      Calls the ar_invoice_api_pub API to create a single transaction
    --  Parameters
    --      p_batch_source_rec      API type for batch source
    --      p_trx_header_tbl        API type for invoice header
    --      p_trx_lines_tbl         API type for invoice lines
    --      p_trx_dist_tbl          API type for distributions
    --      p_trx_salescredits_tbl  API type for sales credits
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure create_single_invoice(
        p_batch_source_rec      in out nocopy ar_invoice_api_pub.batch_source_rec_type,
        p_trx_header_tbl        in out nocopy ar_invoice_api_pub.trx_header_tbl_type,
        p_trx_lines_tbl         in out nocopy ar_invoice_api_pub.trx_line_tbl_type,
        p_trx_dist_tbl          in out nocopy ar_invoice_api_pub.trx_dist_tbl_type,
        p_trx_salescredits_tbl  in out nocopy ar_invoice_api_pub.trx_salescredits_tbl_type,
        p_derived_rec           in out nocopy t_derived_rec,
        p_api_message           out varchar2 )
    is
        cursor c_list_errors is
          select trx_header_id, trx_line_id, trx_salescredit_id, trx_dist_id, error_message, invalid_value
            from ar_trx_errors_gt;

        l_customer_trx_id         number;
        l_return_status           varchar2(10);
        l_msg_count               number;
        l_msg_data                varchar2(800);
        l_cnt                     number:= 0;
    begin
        debug_msg('begin','create_single_invoice');

        ar_invoice_api_pub.create_single_invoice(
            p_api_version          => 1.0,
            p_init_msg_list        => fnd_api.g_true,
            p_batch_source_rec     => p_batch_source_rec,
            p_trx_header_tbl       => p_trx_header_tbl,
            p_trx_lines_tbl        => p_trx_lines_tbl,
            p_trx_dist_tbl         => p_trx_dist_tbl,
            p_trx_salescredits_tbl => p_trx_salescredits_tbl,
            x_customer_trx_id      => l_customer_trx_id,
            x_return_status        => l_return_status,
            x_msg_count            => l_msg_count,
            x_msg_data             => l_msg_data
        );

        --log_msg('API Result:');
        --log_msg('   l_customer_trx_id = '||l_customer_trx_id);
        --log_msg('   x_return_status = '||l_return_status);
        --log_msg('   x_msg_count = '||l_msg_count);
        --log_msg('   x_msg_data = '||l_msg_data);

         -- Check for errors
        if l_return_status = fnd_api.g_ret_sts_error or
            l_return_status = fnd_api.g_ret_sts_unexp_error
        then
            p_api_message := l_msg_data;
        else
            select count(*) into l_cnt from ar_trx_errors_gt;
            if l_cnt = 0 then
               p_api_message := null;
               p_derived_rec.invoice_id := l_customer_trx_id;
            else
               log_msg('FAILURE: Errors encountered, see list below:');
               for r_list_error in c_list_errors LOOP
                  dbms_output.put_line('----------------------------------------------------');
                  dbms_output.put_line('Header ID       = ' || to_char(r_list_error.trx_header_id));
                  dbms_output.put_line('Line ID         = ' || to_char(r_list_error.trx_line_id));
                  dbms_output.put_line('Sales Credit ID = ' || to_char(r_list_error.trx_salescredit_id));
                  dbms_output.put_line('Dist Id         = ' || to_char(r_list_error.trx_dist_id));
                  dbms_output.put_line('Message         = ' || substr(r_list_error.error_message,1,80));
                  dbms_output.put_line('Invalid Value   = ' || substr(r_list_error.invalid_value,1,80));
                  dbms_output.put_line('----------------------------------------------------');
                  p_api_message := substr(r_list_error.error_message,1,240);
                end loop;
            end if;
        end if;
    exception
        when others then
            log_msg(sqlerrm, 'create_single_invoice');
            raise;
    end create_single_invoice;

    -- ------------------------------------------------------------------------
    --  Function
    --      calculate_tax_excl_amount
    --  Purpose
    --      Calculates the GST exclusive amount from the inclusive amount and tax rate
    --  Parameters
    --      p_incl_amount       Tax inclusive amount
    --      p_tax_rate          Tax Rate (e.g. 10, 15)
    --  Returns
    --      Invoice Number
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    function calculate_tax_excl_amount(p_incl_amount in number, p_tax_rate in number) return number
    is
    begin
        debug_msg('begin','calculate_tax_excl_amount');
        return round( 100 * p_incl_amount / (100 + p_tax_rate),2);
    exception
        when others then
            log_msg(sqlerrm, 'calculate_tax_excl_amount');
            raise;
    end calculate_tax_excl_amount;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      map_invoice_api_types
    --  Purpose
    --      Maps stage table values to API types
    --  Parameters
    --      p_stage_tbl             Stage table collection
    --      p_derived_tbl           Derived values collection
    --      p_trx_start_idx         Index of the first line of the transaction
    --      p_trx_end_idx           Index of the last line of the transaction
    --      p_batch_source_rec      API type for batch source
    --      p_trx_header_tbl        API type for invoice header
    --      p_trx_lines_tbl         API type for invoice lines
    --      p_trx_dist_tbl          API type for distributions
    --      p_trx_salescredits_tbl  API type for sales credits
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure map_invoice_api_types(
        p_stage_tbl             in out nocopy t_stage_tbl,
        p_derived_tbl           in out nocopy t_derived_tbl,
        p_start_idx             in number,
        p_end_idx               in number,
        p_batch_source_rec      in out nocopy ar_invoice_api_pub.batch_source_rec_type,
        p_trx_header_tbl        in out nocopy ar_invoice_api_pub.trx_header_tbl_type,
        p_trx_lines_tbl         in out nocopy ar_invoice_api_pub.trx_line_tbl_type,
        p_trx_dist_tbl          in out nocopy ar_invoice_api_pub.trx_dist_tbl_type,
        p_trx_salescredits_tbl  in out nocopy ar_invoice_api_pub.trx_salescredits_tbl_type )
    is
        l_trx_date        date := sysdate;
        s                 number := p_start_idx;
        e                 number := p_end_idx;
        i                 number := 0; -- line number
    begin
        debug_msg('begin','map_invoice_api_types');
        -- batch source
        p_batch_source_rec.batch_source_id        := p_derived_tbl(s).batch_source_id;
        p_batch_source_rec.default_date           := l_trx_date;
        -- header --
        p_trx_header_tbl(1).trx_header_id         := 1001;  -- arbitrary, gets overriden by api
        p_trx_header_tbl(1).trx_date              := nvl(p_stage_tbl(s).trans_date,l_trx_date);
        p_trx_header_tbl(1).gl_date               := p_trx_header_tbl(1).trx_date;
        p_trx_header_tbl(1).bill_to_customer_id   := p_derived_tbl(s).cust_acct_id;
        p_trx_header_tbl(1).bill_to_site_use_id   := p_derived_tbl(s).site_use_id;
        p_trx_header_tbl(1).cust_trx_type_id      := p_derived_tbl(s).cust_trx_type_id;
        p_trx_header_tbl(1).trx_currency          := p_stage_tbl(s).currency_code;
        -- lines
        for k in p_start_idx..p_end_idx
        loop
            i := i + 1;
            p_trx_lines_tbl(i).trx_header_id      := p_trx_header_tbl(1).trx_header_id;
            p_trx_lines_tbl(i).trx_line_id        := i; -- arbitrary, gets overriden by api
            p_trx_lines_tbl(i).line_number        := i;
            p_trx_lines_tbl(i).description        := p_stage_tbl(k).description;
            p_trx_lines_tbl(i).quantity_invoiced  := p_stage_tbl(k).quantity;
            p_trx_lines_tbl(i).uom_code           := p_derived_tbl(k).uom_code;
            p_trx_lines_tbl(i).amount             := calculate_tax_excl_amount(p_stage_tbl(k).unit_price * p_stage_tbl(k).quantity, p_derived_tbl(k).tax_rate);
            p_trx_lines_tbl(i).unit_selling_price := p_trx_lines_tbl(i).amount;
            p_trx_lines_tbl(i).line_type          := 'LINE';
            p_trx_lines_tbl(i).sales_order        := p_stage_tbl(k).fee_number;
            p_trx_lines_tbl(i).vat_tax_id         := p_derived_tbl(k).tax_code_id;
            -- distributions --
            p_trx_dist_tbl(i).trx_dist_id         := i;  -- arbitrary, gets overriden by api
            p_trx_dist_tbl(i).trx_header_id       := p_trx_header_tbl(1).trx_header_id;
            p_trx_dist_tbl(i).trx_line_id         :=  p_trx_lines_tbl(i).trx_line_id;
            p_trx_dist_tbl(i).account_class       := 'REV';
            p_trx_dist_tbl(i).amount              := p_trx_lines_tbl(i).amount;
            p_trx_dist_tbl(i).code_combination_id := p_derived_tbl(k).rev_gl_ccid;
        end loop;
    exception
        when others then
            log_msg(sqlerrm, 'map_invoice_api_types');
            raise;
    end map_invoice_api_types;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      insert_invoice_status
    --  Purpose
    --      Inserts a row into the RRAM Invoice Status table
    --  Parameters
    --      p_stage_rec         Stage table record
    --      p_customer_trx_id   Transaction Id
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure insert_invoice_status(p_stage_rec in out nocopy c_stage%rowtype, p_customer_trx_id in number)
    is
    begin
        debug_msg('begin','map_invoice_api_types');
        insert into rram_invoice_status
        (
            invoice_id,
            invoice_number,
            source_system,
            source_system_ref,
            invoice_amount,
            amount_applied,
            amount_credited,
            amount_adjusted,
            amount_due_remaining,
            creation_date,
            created_by
        )
        select rct.customer_trx_id
             , rct.trx_number
             , p_stage_rec.source_system
             , p_stage_rec.source_system_ref
             , arps.amount_due_original
             , arps.amount_applied
             , arps.amount_credited
             , arps.amount_adjusted
             , arps.amount_due_remaining
             , sysdate
             , g_user_id
          from ra_customer_trx rct
             , ar_payment_schedules arps
         where rct.customer_trx_id = p_customer_trx_id
           and arps.customer_trx_id = rct.customer_trx_id
           and arps.status = 'OP';
        debug_msg('inserted '||sql%rowcount||' row into rram_invoice_status','insert_invoice_status');
    exception
        when others then
            log_msg(sqlerrm, 'insert_invoice_status');
            raise;
    end insert_invoice_status;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      create_transaction
    --  Purpose
    --      Maps stage table values to API types and then calls the API to
    --      create an AR transaction
    --  Parameters
    --      p_stage_tbl         Stage table collection
    --      p_derived_tbl       Derived values collection
    --      p_trx_start_idx     Index of the first line of the transaction
    --      p_trx_end_idx       Index of the last line of the transaction
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    --  sryan       05/07/2017   added generate_crn (dtpli consolidation project)
    -- ------------------------------------------------------------------------
    procedure create_transaction(
        p_stage_tbl         in out nocopy t_stage_tbl,
        p_derived_tbl       in out nocopy t_derived_tbl,
        p_start_idx         in number,
        p_end_idx           in number,
        p_error             out boolean)
    is
        l_batch_source_rec        ar_invoice_api_pub.batch_source_rec_type;
        l_trx_header_tbl          ar_invoice_api_pub.trx_header_tbl_type;
        l_trx_lines_tbl           ar_invoice_api_pub.trx_line_tbl_type;
        l_trx_dist_tbl            ar_invoice_api_pub.trx_dist_tbl_type;
        l_trx_salescredits_tbl    ar_invoice_api_pub.trx_salescredits_tbl_type;
        l_api_message             varchar2(240);
    begin
        debug_msg('begin','create_transaction');
        -- map api type values
        map_invoice_api_types(p_stage_tbl, p_derived_tbl, p_start_idx, p_end_idx,
            l_batch_source_rec, l_trx_header_tbl, l_trx_lines_tbl, l_trx_dist_tbl,
            l_trx_salescredits_tbl );
        -- create the invoice
        create_single_invoice(l_batch_source_rec, l_trx_header_tbl, l_trx_lines_tbl,
            l_trx_dist_tbl, l_trx_salescredits_tbl, p_derived_tbl(p_start_idx), l_api_message);
        if l_api_message is not null then
            add_api_error(p_stage_tbl(p_start_idx).stage_id, l_api_message);
            p_error := true;
        else
            p_error := false;
            if p_derived_tbl(p_start_idx).invoice_id is not null then
               p_derived_tbl(p_start_idx).invoice_num := get_trx_number(p_derived_tbl(p_start_idx).invoice_id);
            end if;
            insert_invoice_status(p_stage_tbl(p_start_idx), p_derived_tbl(p_start_idx).invoice_id);
            generate_crn(g_source_crn_identifier, p_derived_tbl(p_start_idx).invoice_id);
            log_msg('SUCCESS: Trx Number = '|| p_derived_tbl(p_start_idx).invoice_num
                || ' [customer_trx_id='|| p_derived_tbl(p_start_idx).invoice_id || ']' );
        end if;
    exception
        when others then
            log_msg(sqlerrm, 'create_transaction');
            raise;
    end create_transaction;

    -- ------------------------------------------------------------------------------------
    -- Procedure:   process_batch
    -- Purpose:     Processes a batch of stage table rows
    -- ------------------------------------------------------------------------------------
    procedure process_batch(p_stage_tbl in out nocopy t_stage_tbl)
    is
        l_current_header          varchar2(30); -- keeps track of the current agreement or reservation
        l_previous_header         varchar2(30); -- used as comparison with current to identify a new header
        l_trx_start_idx           number; -- index of first line in a transaction
        l_trx_end_idx             number; -- index of last line in a transaction
        l_invalid_line_found      boolean := false;
        l_derived_tbl             t_derived_tbl;
        l_error                   boolean := false;
    begin
        -- loop through batch of stage rows
        for i in p_stage_tbl.first..p_stage_tbl.last
        loop
            log_msg('StageId['|| p_stage_tbl(i).stage_id ||'] SourceSystemRef='|| p_stage_tbl(i).source_system_ref);
            l_current_header := p_stage_tbl(i).source_system_ref;
            if  l_current_header <> nvl(l_previous_header,'null') then
                debug_msg('new invoice','process_batch');
                -- we've come across a new header, create an invoice with what we have so far
                -- no need to do this if on the very first line of the batch and only do it when
                -- all lines are valid and a transaction doesn't already exist
                if (i > p_stage_tbl.first) then
                    if not l_invalid_line_found then
                        -- transaction may have been found during validation.
                        -- check for values in derived tbl and create a transaction only if they are null.
                        if l_derived_tbl(l_trx_start_idx).invoice_id is null and
                           l_derived_tbl(l_trx_start_idx).invoice_num is null
                        then
                            log_msg('Creating transaction for '||l_previous_header);
                            create_transaction(p_stage_tbl, l_derived_tbl, l_trx_start_idx, l_trx_end_idx, l_error);
                        else
                            log_msg('No need to create a transaction for '||l_previous_header);
                            l_error := false;
                        end if;
                        --
                        if l_error then
                            set_stage_row_status(p_stage_tbl, l_derived_tbl, l_trx_start_idx, l_trx_end_idx, G_INT_STATUS_ERROR);
                        else
                            set_stage_row_status(p_stage_tbl, l_derived_tbl, l_trx_start_idx, l_trx_end_idx, G_INT_STATUS_PROCESSED);
                        end if;
                    else
                        -- getting here means that at least one line in the invoice has failed validation
                        -- mark the other otherwise valid lines with an error
                        set_stage_rows_related_error(p_stage_tbl, l_trx_start_idx, l_trx_end_idx);
                    end if;
                end if;
                l_trx_start_idx := i;
                l_invalid_line_found := false;
            end if;
            -- validate columns
            validate_stage_row_columns(p_stage_tbl, l_derived_tbl, i);
            if p_stage_tbl(i).interface_status = G_INT_STATUS_ERROR then
                l_invalid_line_found := true;
            end if;
            -- keep track of the current header we're working on
            l_previous_header := l_current_header;
            -- make the transaction end index equal to the current index
            l_trx_end_idx := i;
        end loop;

        -- populate the remaining invoice lines
        if not l_invalid_line_found then
            -- transaction may have been found during validation.
            -- check for values in derived tbl and create a transaction only if they are null.
            if l_derived_tbl(l_trx_start_idx).invoice_id is null and
                l_derived_tbl(l_trx_start_idx).invoice_num is null
            then
                debug_msg('populating final invoice lines');
                debug_msg('l_trx_start_idx='||l_trx_start_idx);
                debug_msg('l_trx_end_idx='||l_trx_end_idx);
                l_error := false;
                create_transaction(p_stage_tbl, l_derived_tbl, l_trx_start_idx, l_trx_end_idx, l_error);
            else
                log_msg('No need to create a transaction for final sales order');
                l_error := false;
            end if;
            --
            if l_error then
                set_stage_row_status(p_stage_tbl, l_derived_tbl, l_trx_start_idx, l_trx_end_idx, G_INT_STATUS_ERROR);
            else
                set_stage_row_status(p_stage_tbl, l_derived_tbl, l_trx_start_idx, l_trx_end_idx, G_INT_STATUS_PROCESSED);
            end if;
        else
            -- getting here means that at least one line in the invoice has failed validation
            -- mark the other otherwise valid lines with an error
            set_stage_rows_related_error(p_stage_tbl, l_trx_start_idx, l_trx_end_idx);
        end if;
    exception
        when others then
            log_msg(sqlerrm, 'process_batch');
            raise;
    end process_batch;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      import_trans
    --  Purpose
    --      Implements the main logic of the invoice interface
    --  Parameters
    --      p_debug       Debug flag (Y|N) to output additional flow information
    --      p_errors      Boolean flag to indicate existence of errors
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    --  khoh        16/07/2015  added logic to reject duplicate transaction line rows before import 
    -- ------------------------------------------------------------------------
    procedure import_trans(
        p_debug         in varchar2 default 'N',
        p_errors        out boolean)
    is
        l_stage_tbl         t_stage_tbl;
        l_overflow_tbl      t_stage_tbl := t_stage_tbl();
        l_stage_rec         c_stage%rowtype;
        l_errors_found      boolean := false;
        l_count             number := 0;
        l_loop_num          number := 0;
        l_stage_rec_dup     c_stage_dup%rowtype;    -- Added by khoh on 16/07/2015
    begin
        -- initialise and validate session
        initialise(p_debug);
        debug_msg('begin','import_trans');
        
        -- Added by khoh on 16/07/2015
        -- update duplicate transaction line records to status 'D'
        open  c_stage_dup(G_INT_STATUS_NEW);
        loop
            fetch c_stage_dup into l_stage_rec_dup;
            exit when c_stage_dup%notfound;
            debug_msg('updating duplicate transaction line record l_stage_rec_dup.stage_id='||l_stage_rec_dup.stage_id,'import_trans');
            update rram_ar_trans_stage
            set interface_status = G_INT_STATUS_DUPLICATE, 
                 conc_request_id    = g_conc_request_id,
                 last_update_date   = sysdate,
                 last_updated_by    = g_user_id
            where stage_id = l_stage_rec_dup.stage_id;
        end loop;
        close c_stage_dup;
        -- 16/07/2015

        -- read stage table rows and process in batches of g_max_fetch
        open  c_stage(G_INT_STATUS_NEW);
        loop
            fetch c_stage bulk collect into l_stage_tbl limit g_max_fetch;
            exit when l_stage_tbl.count = 0;
            l_loop_num := l_loop_num + 1;
            debug_msg('bulk collect loop #'||l_loop_num||' size '||l_stage_tbl.count, 'import_trans');
            -- add the overflow record from the previous loop if there was one
            if l_overflow_tbl.count > 0 then
                debug_msg('adding overflow record','import_trans');
                l_stage_tbl := l_overflow_tbl multiset union all l_stage_tbl;
                l_overflow_tbl.delete;
            end if;
            -- keep fetching until we get to the end of the current invoice.
            -- this is required so that we don't process an invoice accross two batches
            loop
                fetch c_stage into l_stage_rec;
                exit when c_stage%notfound;
                debug_msg('fetched additional record l_stage_rec.stage_id='||l_stage_rec.stage_id);
                exit when l_stage_rec.source_system_ref <> l_stage_tbl(l_stage_tbl.last).source_system_ref;
                debug_msg('adding record='||l_stage_rec.stage_id||' to main collection.','import_trans');
                l_stage_tbl.extend;
                l_stage_tbl(l_stage_tbl.last) := l_stage_rec;
            end loop;
            -- keep track of the last additional record fetched - this is the start of a new invoice and must be added
            -- to the collection later (after the next bulk collect clause)
            if l_stage_rec.stage_id is not null then
                debug_msg('..adding overflow stage_id='||l_stage_rec.stage_id, 'import_trans');
                l_overflow_tbl.extend;
                l_overflow_tbl(1) := l_stage_rec;
                l_stage_rec := null;
            end if;
            --
            process_batch(l_stage_tbl);
            l_count := l_count + l_stage_tbl.count;
            update_stage_tbl_values(l_stage_tbl);
            if g_error_tbl.count > 0 then
                insert_errors;
                l_errors_found := true;
            end if;
            g_error_tbl.delete;
        end loop;
        close c_stage;

        if l_count > 0 then
            log_msg('Processed '||l_count||' rows');
        else
            log_msg('No rows to process');
        end if;

        p_errors := l_errors_found;
        debug_msg('import_trans -> end');
    exception
        when ex_invalid_apps_session then
            log_msg('No Applications session.  Run fnd_global.apps_initialize');
            raise;
        when ex_sob_not_found then
            log_msg('** EXCEPTION: Set of Books not found **');
            raise;
        when ex_source_not_found then
            log_msg('** EXCEPTION: Batch Source not found **');
            raise;
        when others then
            if c_stage%isopen then
                close c_stage;
            end if;
            log_msg(sqlerrm, 'import_trans');
            raise;
    end import_trans;
    
    -- ------------------------------------------------------------------------
    --  Procedure
    --      email_report_output
    --  Purpose
    --      Fires the below Reports and then emails them to given email address
    --  Parameters
    --      p_conc_request_id   Filters by the concurrent request id
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  Joy Pinto   03/10/2017	initial
    -- ------------------------------------------------------------------------
    procedure email_report_output(p_conc_request_id in number,
                                  l_errors_found OUT boolean,
                                  p_email_address in varchar2,
                                  p_email_subject IN varchar2,
                                  p_email_body IN varchar2)
    is        
       vv_conc_error              varchar2(1) := '2';
       vv_conc_success            varchar2(1) := '0';
       lv_po_enhanced             varchar2(10) := 'N';
       lv_app_short_name          varchar2(10) := 'ARC';
       lv_stg_templ_code          varchar2(100) := 'XXAR_RRAM_TRANS_STAGE_RPT_XML';
       lv_inv_templ_code          varchar2(100) := 'XXAR_RRAM_INV_STATUS_RPT_XML';
       lv_email_templ_code        varchar2(100) := 'ARCRAMSSENDMAIL';
       lv_option_return           boolean;
       srs_wait                   BOOLEAN;
       srs_phase                  VARCHAR2(30);
       srs_status                 VARCHAR2(30);
       srs_dev_phase              VARCHAR2(30);
       srs_dev_status             VARCHAR2(30);
       srs_message                VARCHAR2(240);
       ln_request_id              NUMBER;
       ln_request_id1             NUMBER;
       lv_completion_text         fnd_concurrent_requests.completion_text%TYPE;  
       lv_po_number               po_headers_all.segment1%TYPE;
       lv_stg_file_name           VARCHAR2(240);
       lv_invoice_file_name       VARCHAR2(240);
       lv_user_name               VARCHAR2(240);
    begin
    
      -- Set the template for DEDJTR RRAM Transactions Staging Table Extract
      lv_option_return := fnd_request.add_layout(
                                                 template_appl_name      => lv_app_short_name,
                                                 template_code           => lv_stg_templ_code,
                                                 template_language       => 'En',
                                                 template_territory      => 'US',
                                                 output_format           => 'EXCEL'
                                                );
       
      -- Fire the program DEDJTR RRAM Transactions Staging Table Extract 
      ln_request_id := fnd_request.submit_request(
                                                  application => lv_app_short_name,
                                                  program     => lv_stg_templ_code,
                                                  description => '',
                                                  argument1   => null,
                                                  argument2   => null,
                                                  ARGUMENT3   => p_conc_request_id
                                                );
       --
      COMMIT;   
      -- Set the template for DEDJTR RRAM Invoice Status Extract
      lv_option_return := fnd_request.add_layout(
                                                 template_appl_name      => lv_app_short_name,
                                                 template_code           => lv_inv_templ_code,
                                                 template_language       => 'En',
                                                 template_territory      => 'US',
                                                 output_format           => 'EXCEL'
                                                );
       
      -- Fire the program DEDJTR RRAM Invoice Status Extract
      ln_request_id1 := fnd_request.submit_request(
                                                   application => lv_app_short_name,
                                                   program     => lv_inv_templ_code,
                                                   description => '',
                                                   argument1   => null,
                                                   argument2   => null,
                                                   ARGUMENT3   => p_conc_request_id
                                                  );
       --
      commit;   
      
      IF p_email_address IS NOT NULL THEN
      
         lv_stg_file_name := lv_stg_templ_code||'_'||ln_request_id||'_1.EXCEL'; -- This is the name of the PDF file for "DEDJTR RRAM Transactions Staging Table Extract"
      
         lv_invoice_file_name := lv_inv_templ_code||'_'||ln_request_id1||'_1.EXCEL'; -- This is the name of the PDF file for "DEDJTR RRAM Invoice Status Extract"
      
         fnd_file.put_line(fnd_file.log, 'lv_transactions_file_name='||lv_stg_file_name);
      
         fnd_file.put_line(fnd_file.log, 'lv_invoice_file_name1='||lv_invoice_file_name);
    
      
         -- wait for request 1
         srs_wait := fnd_concurrent.wait_for_request(
                                                     ln_request_id,
                                                     10,
                                                     0,
                                                     srs_phase,
                                                     srs_status,
                                                     srs_dev_phase,
                                                     srs_dev_status,
                                                     srs_message
                                                     );   
                                              
         IF NOT (srs_dev_phase = 'COMPLETE' AND (srs_dev_status = 'NORMAL' OR srs_dev_status = 'WARNING')) THEN
            SELECT completion_text
            INTO   lv_completion_text
            FROM   fnd_concurrent_requests
            WHERE  request_id = ln_request_id;
         
            fnd_file.put_line(fnd_file.log, lv_completion_text);
            fnd_file.put_line(fnd_file.log,'DEDJTR RRAM Transactions Staging Table Extract failed, Please refer to the log file of request ID '||ln_request_id);
            l_errors_found := TRUE;
         ELSE
            -- Success wait for the second report
            fnd_file.put_line(fnd_file.log, lv_completion_text);
            fnd_file.put_line(fnd_file.log,'DEDJTR RRAM Transactions Staging Table Extract program completed successfully - request ID '||ln_request_id);
            
            srs_wait := fnd_concurrent.wait_for_request(
                                                        ln_request_id1,
                                                        10,
                                                        0,
                                                        srs_phase,
                                                        srs_status,
                                                        srs_dev_phase,
                                                        srs_dev_status,
                                                        srs_message
                                                       ); 
                                              
            IF NOT (srs_dev_phase = 'COMPLETE' AND (srs_dev_status = 'NORMAL' OR srs_dev_status = 'WARNING')) THEN
               SELECT completion_text
               INTO   lv_completion_text
               FROM   fnd_concurrent_requests
               WHERE  request_id = ln_request_id;
         
               fnd_file.put_line(fnd_file.log, lv_completion_text);
               fnd_file.put_line(fnd_file.log,'DEDJTR RRAM Invoice Status Extract failed, Please refer to the log file of request ID '||ln_request_id);                                              
                                              
            ELSE
               -- Success Send the email
               fnd_file.put_line(fnd_file.log, lv_completion_text);
               fnd_file.put_line(fnd_file.log,'DEDJTR RRAM Invoice Status Extract program completed successfully - request ID '||ln_request_id);                                  
            
               ln_request_id := fnd_request.submit_request(
                                                           application => lv_app_short_name,
                                                           program     => lv_email_templ_code,
                                                           description => '',
                                                           argument1   => p_email_address,
                                                           argument2   => lv_stg_file_name,
                                                           argument3   => lv_invoice_file_name,
                                                           argument4   => p_email_subject,
                                                           argument5   => p_email_body,
                                                           argument6   => ln_request_id,
                                                           argument7   => ln_request_id1
                                                           );
                              
               COMMIT;
               srs_wait := fnd_concurrent.wait_for_request(
                                                           ln_request_id,
                                                           10,
                                                           0,
                                                           srs_phase,
                                                           srs_status,
                                                           srs_dev_phase,
                                                           srs_dev_status,
                                                           srs_message
                                                          );      
                                              
               IF NOT (srs_dev_phase = 'COMPLETE' AND (srs_dev_status = 'NORMAL' OR srs_dev_status = 'WARNING')) THEN
                  SELECT completion_text
                  INTO   lv_completion_text
                  FROM   fnd_concurrent_requests
                  WHERE  request_id = ln_request_id;
         
                  fnd_file.put_line(fnd_file.log, lv_completion_text);
                  fnd_file.put_line(fnd_file.log,'DEDJTR Send RAMS Report by Email program failed, Please refer to the log file of request ID '||ln_request_id);
                  l_errors_found := TRUE;     
               ELSE
                  fnd_file.put_line(fnd_file.log, lv_completion_text);
                  fnd_file.put_line(fnd_file.log,'DEDJTR Send RAMS Report by Email completed successfully - request ID '||ln_request_id);               
               END IF;
            END IF;   
         END IF;
      END IF;
    exception
        when others then
            log_msg(sqlerrm, 'email_report_output');
            raise;
    end email_report_output;    

    -- ------------------------------------------------------------------------
    --  Procedure
    --      import_trans_cp
    --  Purpose
    --      Concurrent program wrapper to call procedure import_trans
    --      This program implements concurrent program RRAM_IMPORT_TRANS
    --  Parameters
    --      p_errbuf      Standard OUT parameter for the program completion message
    --      p_retcode     Standard OUT parameter for the program completion status
    --                    (0=normal, 1=warning, 2=error)
    --      p_debug       Debug flag (Y|N) to output additional flow information to
    --                    the log file
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure import_trans_cp(
        p_errbuf	            out varchar2,
      	p_retcode	            out number,
        p_debug               in varchar2 default 'N')
    is
        l_errors_found      boolean := false;
        lv_email_address    varchar2(100) := fnd_profile.value('ARC_RRAM_AUTOMATIC_EMAIL_RECIPIENTS');
        lv_email_subject    varchar2(240) := 'RRAM Oracle Staging Table Report and Payment Status Report generated on '||to_char(sysdate,'DD-MON-RRRR HH24:MI:SS');
        lv_email_body       varchar2(2000) := '';
    begin
        import_trans(p_debug, l_errors_found);
        audit_report(g_conc_request_id);
        error_report(g_conc_request_id);         
        email_report_output(g_conc_request_id,l_errors_found,lv_email_address,lv_email_subject,lv_email_body);
        
        --
        if l_errors_found then
            p_retcode := 1;
        else
           if lv_email_address IS NULL THEN
              p_retcode := 1;
              fnd_file.put_line(fnd_file.log, 'Emails not provided for the staging table report and payment status report in profile option ARC: RRAM Automatic email recipients');
           else
              p_retcode := 0;
           end if;
        end if;
    exception
        when others then
            p_errbuf := sqlerrm;
            p_retcode := 2;
    end import_trans_cp;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      submit_import_trans
    --  Purpose
    --      Program wrapper to submit the RRAM Import Invoices concurrent
    --      program (RRAM_IMPORT_TRANS)
    --  Parameters
    --      p_user            User name from fnd_users
    --      p_resp_id         Responsibility Id
    --      p_resp_appl_id    Responsibility Application Id
    --      p_debug           Debug flag (Y|N) to output additional flow information to
    --                        the log file
    --      p_request_id      Returned concurrent request id OR error message
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure submit_import_trans(
        p_user	              in varchar2,
      	p_resp_id	            in number,
      	p_resp_appl_id        in number,
        p_debug               in varchar2 default 'N',
        p_request_id         out number)
    is
        l_request_id        number;
        l_user_id           number;
    begin
        lookup_user(p_user, l_user_id);
        if l_user_id is not null then
            log_msg('Found User Id '||l_user_id||' for '||p_user);
            -- Initiaze the apps session using 50707 = Receivables Manager GUI-DOI, 222 = Receivables
            fnd_global.apps_initialize(l_user_id,50707,222);
            initialise(p_debug);

            l_request_id :=
                fnd_request.submit_request(
                    'ARC'          -- Application Short Name
                  , 'RRAM_IMPORT_TRANS'  -- Program Short Name
                  , null          -- Description
                  , null          -- Start time
                  , false         -- Subrequest
                  , 'Y'           -- P_DEBUG
                );
            log_msg('Request Id '||l_request_id);
            p_request_id := l_request_id;
        else
            log_msg('User '||p_user||' not found');
            p_request_id := -1;
        end if;
    exception
        when others then
            log_msg(sqlerrm, 'submit_import_trans(overloaded)');
            raise;
    end submit_import_trans;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      submit_import_trans (overloaded)
    --  Purpose
    --      Program wrapper to submit the RRAM Import Invoices concurrent
    --      program (RRAM_IMPORT_TRANS)
    --      This is an overloaded procedure that does not return the concurrent
    --      request id
    --  Parameters
    --      p_user            User name from fnd_users
    --      p_resp_id         Responsibility Id
    --      p_resp_appl_id    Responsibility Application Id
    --      p_debug           Debug flag (Y|N) to output additional flow information to
    --                        the log file
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure submit_import_trans(
        p_user	              in varchar2,
      	p_resp_id	            in number,
      	p_resp_appl_id        in number,
        p_debug               in varchar2 default 'N')
    is
        l_request_id        number;
    begin
        submit_import_trans(p_user, p_resp_id, p_resp_appl_id, p_debug, l_request_id);
    exception
        when others then
            log_msg(sqlerrm, 'submit_import_trans(overloaded)');
            raise;
    end submit_import_trans;

end rram_ar_trans_pkg;
/
