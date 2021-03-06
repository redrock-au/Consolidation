create or replace package body rram_debtor_pkg
as
/* $Header: svn://d02584/consolrepos/branches/AP.03.01/arc/1.0.0/install/sql/RRAM_DEBTOR_PKB.pls 1066 2017-06-21 04:33:20Z svnuser $ */
-- ============================================================================
--
--  PROGRAM:	  RRAM_DEBTOR_PKB.pls
--
--  DESCRIPTION:
--      Creates package body rram_debtor_pkg.
--		  This package implements the Oracle side of the RRAM Debtor Interface.
--
--  AUTHOR      DATE		    COMMENT
--  ----------- ----------  ----------------------------------------------------
--  sryan       13/01/2015	initial
--  sryan       24/04/2015	added additional lookup for location by site number
-- ============================================================================

    -- cursor for stage table rows
    cursor c_stage(p_interface_status in varchar2, p_conc_request_id in number default null) is
        select *
          from rram_debtor_stage
         where interface_status = p_interface_status
           and nvl(conc_request_id,-1) = nvl(p_conc_request_id, nvl(conc_request_id,-1))
         order by stage_id;

    -- custom types
    type t_derived_rec is record (
        party_id                number,
        cust_acct_id            number,
        account_number          varchar2(30),
        party_site_id           number,
        cust_acct_site_id       number,
        party_site_number       number,
        location_id             number,
        site_use_id             number,
        profile_class_id        number,
        site_party_id           number, -- used to check that a site belongs to a party
        stage_id                number -- used to initialize an instance
    );

    type t_derived_tbl is table of t_derived_rec index by binary_integer;

    -- collection types
    type t_stage_tbl is table of c_stage%rowtype index by binary_integer;
    type t_error_tbl is table of rram_interface_errors%rowtype index by binary_integer;
    type t_audit_tbl is table of rram_debtor_audit%rowtype index by binary_integer;

    -- global variables and constants
    g_error_tbl             t_error_tbl;
    g_audit_tbl             t_audit_tbl;
    g_max_fetch             constant number := 200;
    g_interface_type        constant varchar2(30) := 'Debtor';
    g_request_id            number;
    g_valid_source          varchar2(240) := 'RRAM'; -- TODO: remove thsi after checking ORIG SOURCE setup.
    g_user_id               number;
    g_org_id                number;
    g_conc_request_id       number;
    g_debug                 boolean := false;
    g_created_by_module     constant varchar2(20) := 'TCA_V1_API';

    -- custom exceptions
    ex_invalid_apps_session         exception;
    ex_multiple_account_match       exception;
    ex_multiple_site_match          exception;
    ex_multiple_site_use_match      exception;

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
    begin
        g_user_id           := fnd_global.user_id;
        g_org_id            := fnd_global.org_id;
        g_conc_request_id   := fnd_global.conc_request_id;
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
    --  Function
    --      format
    --  Purpose
    --      Formats a varachar2 value into a dbms_output friendly form.
    --      dbms_output cannot print the fnd_api.g_miss_char value which is used
    --      by the APIs to denote a null value.
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    function format(p_unformatted in varchar2) return varchar2
    is
    begin
        return replace(p_unformatted, fnd_api.g_miss_char, 'Null');
    end;

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
    --      insert_debtor_audit
    --  Purpose
    --      Writes audit messages to the audits table
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure insert_debtor_audit(
        p_stage_id        in number,
        p_interface_type  in varchar2,
        p_action          in varchar2,
        p_tca_record      in varchar2,
        p_field_name      in varchar2 default null,
        p_orig_value      in varchar2 default null,
        p_new_value       in varchar2 default null )
    is
    begin
        insert into rram_debtor_audit(audit_id, stage_id, interface_type, conc_request_id,
            action, tca_record, field_name, orig_value, new_value )
        values (rram_debtor_audit_s1.nextval, p_stage_id, p_interface_type, g_conc_request_id,
            p_action, p_tca_record, p_field_name, p_orig_value, p_new_value );
    exception
        when others then
            log_msg(sqlerrm, 'insert_debtor_audit');
            raise;
    end insert_debtor_audit;

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
        g_error_tbl(l_idx).api_error        := p_api_error;
        g_error_tbl(l_idx).error_message    := p_error;
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
    --      assign_api_errors
    --  Purpose
    --      Retrives API error messages from the stack and adds them to the global
    --      errors table
    --  Parameters
    --      p_stage_id    Identifier of the stage table row that caused the error
    --      p_msg_count   Number of API errors returned from the API
    --      p_msg_data    API error if p_msg_count=1
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure assign_api_errors(
        p_stage_id      in number,
        p_msg_count     in number,
        p_msg_data      in varchar2)
    is
        l_error_msg       varchar2(255);
    begin
        if p_msg_count = 1 then
            add_api_error(p_stage_id, p_msg_data);
        elsif p_msg_count > 1 then
            for i in 1..p_msg_count
            loop
                l_error_msg := substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),1,255);
                add_api_error(p_stage_id, l_error_msg);
            end loop;
        end if;
    exception
        when others then
            log_msg(sqlerrm, 'assign_api_errors');
            raise;
    end assign_api_errors;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      compare_and_update_varchar
    --  Purpose
    --      Compares two varchar2 values and copies new to existing if they differ
    --      FND_API.G_MISS_CHAR is used to denote a Null value for the API.
    --  Parameters
    --      p_new_val         New value
    --      p_existing_val    Existing number to compare with.  Gets updated if found to be different
    --      p_dirty_value     Flag to indicate whether the new value was different [true|false]
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure compare_and_update_varchar(
        p_new_val           in varchar2,
        p_existing_val      in out varchar2,
        p_field_name        in varchar2 default null,
        p_dirty_value       out boolean )
    is
        l_dirty_value       boolean := false;
    begin
        --debug_msg('comparing '''||nvl(p_new_val,'Null')||''' with '''||replace(p_existing_val,chr(0), 'Null')||'''');
        if p_new_val is null then
            if nvl(p_existing_val, fnd_api.g_miss_char) <> fnd_api.g_miss_char then
                l_dirty_value := true;
                log_msg('updating '||nvl(p_field_name,'value')||' from '''|| p_existing_val || ''' to Null');
                p_existing_val := FND_API.G_MISS_CHAR;
            end if;
        else
            if
               ( p_existing_val is null or
                 p_existing_val <> p_new_val )
            then
                l_dirty_value := true;
                log_msg('updating '||nvl(p_field_name,'value')||' from '''|| replace(p_existing_val, fnd_api.g_miss_char, 'Null') || ''' to ''' || p_new_val || '''');
                p_existing_val := p_new_val;
            end if;
        end if;
        p_dirty_value := l_dirty_value;
    exception
        when others then
            log_msg(sqlerrm, 'compare_and_update_varchar');
            raise;
    end compare_and_update_varchar;

    -- ------------------------------------------------------------------------
    --  Function
    --      get_allow_change_option
    --  Purpose
    --      Returns the AR System Option 'Allow Change to Printed Transactions'
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    function get_allow_change_option return varchar2
    is
        l_val     varchar2(1);
    begin
        select change_printed_invoice_flag into l_val from ar_system_parameters;
        return l_val;
    exception
        when others then
            log_msg(sqlerrm, 'get_allow_change_option');
            raise;
    end get_allow_change_option;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      set_allow_change_option
    --  Purpose
    --      Updates the AR System Option 'Allow Change to Printed Transactions'
    --  Parameters
    --      p_option         Value to set [Y|N]
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure set_allow_change_option(p_option in varchar2)
    is
    begin
        if p_option in ('Y','N') then
            update ar_system_parameters set change_printed_invoice_flag = p_option where change_printed_invoice_flag <> p_option;
            log_msg('updated '||sql%rowcount||' row setting system option change_printed_invoice_flag = '||p_option);
        else
            log_msg('Invalid system option change_printed_invoice_flag value '''||p_option||'''.  Must be Y or N');
            return;
        end if;
    exception
        when others then
            log_msg(sqlerrm, 'set_allow_change_option');
            raise;
    end set_allow_change_option;

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
          update rram_debtor_stage
             set account_number     = p_stage_tbl(i).account_number,
                 cust_account_id    = p_stage_tbl(i).cust_account_id,
                 party_site_number  = p_stage_tbl(i).party_site_number,
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
    --      delete_redundant_rows
    --  Purpose
    --      Deletes rows from stage table if they were not used to create/update
    --      debtors
    --  Parameters
    --      p_stage_tbl   Stage table collection
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       19/06/2017	New requirement as part of DSDBI Consolidation project
    -- ------------------------------------------------------------------------
    procedure delete_redundant_rows(p_delete_count out number)
    is
    begin
        delete from rram_debtor_stage 
         where stage_id not in 
            ( select stage_id 
                from rram_debtor_audit 
               where interface_type = 'Debtor' );
        p_delete_count := sql%rowcount;
    end delete_redundant_rows;

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
    -- ------------------------------------------------------------------------
    procedure audit_report(p_conc_request_id in number)
    is
        l_new_debtor_count      number := 0;
        l_new_site_count        number := 0;
        l_update_count          number := 0;
        l_current_ref           rram_debtor_stage.source_system_ref%type;
        l_current_action        varchar2(10);
        l_unchanged_count       number := 0;

        cursor c_audit(p_conc_request_id in number)
        is
            -- debtors interface
            select a.audit_id, s.stage_id, decode(a.action,'N','New','U','Update','Unchanged') as action
                 , a.tca_record
                 , a.field_name
                 , substr(a.orig_value,1,25) as orig_value
                 , substr(a.new_value,1,25) as new_value
                 , nvl(to_char(s.account_number),'-') as account_number
                 , nvl(to_char(s.party_site_number),'-') as party_site_number
                 , substr(s.organization_name,1,28) as organization_name
                 , s.source_system_ref
                 , 'Debtor' as interface_type
              from rram_debtor_audit a
                 , rram_debtor_stage s
             where s.conc_request_id = p_conc_request_id
               and a.interface_type(+) = g_interface_type
               and a.conc_request_id(+) = s.conc_request_id
               and s.stage_id = a.stage_id(+)
            union
            -- sites interface
            select a.audit_id, s.stage_id, decode(a.action,'N','New','U','Update','Unchanged') as action
                 , a.tca_record
                 , a.field_name
                 , substr(a.orig_value,1,25) as orig_value
                 , substr(a.new_value,1,25) as new_value
                 , nvl(to_char(s.account_number),'-') as account_number
                 , nvl(to_char(s.party_site_number),'-') as party_site_number
                 , substr(hca.account_name,1,28) as organization_name
                 , s.source_system_ref
                 , 'DebtorSite' as interface_type
              from rram_debtor_audit a
                 , rram_site_stage s
                 , hz_cust_accounts hca
             where s.conc_request_id = p_conc_request_id
               and a.interface_type(+) = 'DebtorSite'
               and a.conc_request_id(+) = s.conc_request_id
               and s.stage_id = a.stage_id(+)
               and hca.account_number = s.account_number
             order by 1,2;
    begin
        -- report title
        out_msg( to_char(sysdate,'DD-MON-YYYY HH24:MI:SS')  || lpad(' ',33,' ') ||
            'RRAM Debtor Interface Audit Report' || lpad(' ',48,' ') ||
            'Request Id: '||p_conc_request_id);
        out_msg(' ');
        out_msg(' ');

        -- report heading
        out_msg(rpad('RRAM Reference',18,' ')   || '  ' ||
                lpad('Acct#',7,' ')             || '  ' ||
                lpad('Site#',8,' ')             || '  ' ||
                rpad('Account Name',30,' ')     || '  ' ||
                rpad('Action',9,' ')            || '  ' ||
                rpad('Record',20,' ')           || '  ' ||
                rpad('Field',20,' ')            || '  ' ||
                rpad('Old Value',27,' ')        || '  ' ||
                rpad('New Value',27,' ' )
            );

        -- heading unerline
        out_msg(rpad('-',18,'-')  || '  ' ||
                lpad('-',7,'-')   || '  ' ||
                lpad('-',8,'-')   || '  ' ||
                rpad('-',30,'-')  || '  ' ||
                rpad('-',9,'-')   || '  ' ||
                rpad('-',20,'-')  || '  ' ||
                rpad('-',20,'-')  || '  ' ||
                rpad('-',27,'-')  || '  ' ||
                rpad('-',27,'-' )
            );

        -- report content
        for r_audit in c_audit(p_conc_request_id)
        loop
            out_msg( rpad(r_audit.source_system_ref,18,' ') || '  ' ||
                lpad(r_audit.account_number,7,' ')        || '  ' ||
                lpad(r_audit.party_site_number,8,' ')     || '  ' ||
                rpad(r_audit.organization_name,30,' ')    || '  ' ||
                rpad(r_audit.action,9,' ')                || '  ' ||
                rpad(r_audit.tca_record,20,' ')           || '  ' ||
                rpad(r_audit.field_name,20,' ')           || '  ' ||
                rpad(r_audit.orig_value,27,' ')           || '  ' ||
                rpad(r_audit.new_value,27,' ' )
            );

            -- count the number of debtors created or updated
            if ( nvl(l_current_ref,'Null') <> r_audit.source_system_ref or
                 nvl(l_current_action,'Null') <> r_audit.action )
            then
                if r_audit.action = 'New' and r_audit.interface_type = 'Debtor' then
                    l_new_debtor_count := l_new_debtor_count + 1;
                elsif r_audit.action = 'New' and r_audit.interface_type = 'DebtorSite' then
                    l_new_site_count := l_new_site_count + 1;
                elsif r_audit.action = 'Update' then
                    l_update_count := l_update_count + 1;
                elsif r_audit.action = 'Unchanged' then
                    l_unchanged_count := l_unchanged_count + 1;
                end if;
                l_current_ref := r_audit.source_system_ref;
                l_current_action := r_audit.action;
            end if;
        end loop;
        out_msg(' ');
        out_msg('Total New Debtors:       '|| l_new_debtor_count);
        out_msg('Total New Sites:         '|| l_new_site_count);
        out_msg('Total Updated Debtors:   '|| l_update_count);
        out_msg('Total Unchanged Debtors: '|| l_unchanged_count);
    exception
        when others then
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
    -- ------------------------------------------------------------------------
    procedure error_report(p_conc_request_id in number)
    is
        l_error_count     number := 0;
        l_debtor_count    number := 0;

        cursor c_stage(p_conc_request_id in number)
        is
            select s.source_system_ref
                 , nvl(to_char(s.account_number),'-') as account_number
                 , nvl(to_char(s.party_site_number),'-') as party_site_number
                 , substr(s.organization_name,1,28) as organization_name
                 , s.stage_id
                 , g_interface_type as interface_type
                 , 'RRAM_DEBTOR_STAGE' as interface_table
              from rram_debtor_stage s
             where s.conc_request_id = p_conc_request_id
               and s.interface_status = 'E'
            union
            select s.source_system_ref
                 , nvl(to_char(s.account_number),'-') as account_number
                 , nvl(to_char(s.party_site_number),'-') as party_site_number
                 , nvl(substr(hca.account_name,1,28),'-') as organization_name
                 , s.stage_id
                 , 'DebtorSite' as interface_type
                 , 'RRAM_SITE_STAGE' as interface_table
              from rram_site_stage s
                 , hz_cust_accounts hca
             where s.conc_request_id = p_conc_request_id
               and hca.account_number(+) = s.account_number
               and s.interface_status = 'E'
             order by 1;

        cursor c_errors(p_stage_id in number, p_interface_type in varchar2)
        is
            select e.error_message, e.api_error, e.error_id
              from rram_interface_errors e
             where e.stage_id = p_stage_id
               and e.interface_type = p_interface_type
             order by e.error_id;
    begin
        -- report heading
        out_msg(' ');
        out_msg('------------------------------------------------ Error Report ------------------------------------------------');
        out_msg(rpad('RRAM Reference',15,' ')   || '  ' ||
                rpad('Stage Table',17,' ')      || '  ' ||
                lpad('Id',6,' ')                || '  ' ||
                lpad('Acct#',7,' ')             || '  ' ||
                lpad('Site#',8,' ')             || '  ' ||
                rpad('Account Name',30,' ')
            );

        -- heading unerline
        out_msg(rpad('-',15,'-')  || '  ' ||
                rpad('-',17,'-')   || '  ' ||
                lpad('-',6,'-')   || '  ' ||
                lpad('-',7,'-')   || '  ' ||
                lpad('-',8,'-')   || '  ' ||
                rpad('-',30,'-')
            );

        -- report content
        for r_stage in c_stage(p_conc_request_id)
        loop
            l_debtor_count := l_debtor_count + 1;
            out_msg( rpad(r_stage.source_system_ref,15,' ') || '  ' ||
                rpad(r_stage.interface_table,17,' ')        || '  ' ||
                lpad(r_stage.stage_id,6,' ')                || '  ' ||
                lpad(r_stage.account_number,7,' ')          || '  ' ||
                lpad(r_stage.party_site_number,8,' ')       || '  ' ||
                rpad(r_stage.organization_name,30,' ')
                );
            for r_error in c_errors(r_stage.stage_id, r_stage.interface_type)
            loop
                l_error_count := l_error_count + 1;
                out_msg('  => '||nvl(r_error.api_error, r_error.error_message));
            end loop;
        end loop;
        out_msg(' ');
        out_msg('Total Errors:  '||l_error_count);
        out_msg('Total Debtors: '||l_debtor_count);
    exception
        when others then
            log_msg(sqlerrm, 'error_report');
            raise;
    end error_report;

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
            debug_msg(p_user_name||' not found','lookup_user');
            p_user_id := null;
        when others then
            log_msg(sqlerrm, 'lookup_user');
            raise;
    end lookup_user;

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
            select hca.party_id, hca.cust_account_id, hca.account_number
              into p_derived_rec.party_id, p_derived_rec.cust_acct_id, p_derived_rec.account_number
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
    --      lookup_account_by_orig_sys_ref
    --  Purpose
    --      Looks up a customer account by original system reference
    --      Must be an active account
    --  Parameters
    --      p_source_sys_ref    Original System Reference
    --      p_source_system     Source System
    --      p_derived_rec       Derived values record
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure lookup_account_by_orig_sys_ref(
        p_source_sys_ref    in varchar2,
        p_source_system     in varchar2,
        p_derived_rec       in out nocopy t_derived_rec )
    is
    begin
        debug_msg('begin','lookup_account_by_orig_sys_ref');
        if p_source_sys_ref is not null and
           p_source_system is not null
        then
            select osr_p.owner_table_id, osr_ca.owner_table_id, hca.account_number
              into p_derived_rec.party_id, p_derived_rec.cust_acct_id, p_derived_rec.account_number
              from hz_orig_sys_references osr_p
                 , hz_orig_sys_references osr_ca
                 , hz_cust_accounts hca
             where osr_p.orig_system = p_source_system
               and osr_p.orig_system_reference = p_source_sys_ref
               and osr_p.owner_table_name = 'HZ_PARTIES'
               and osr_ca.orig_system = osr_p.orig_system
               and osr_ca.owner_table_name = 'HZ_CUST_ACCOUNTS'
               and osr_ca.orig_system_reference = osr_p.orig_system_reference
               and hca.cust_account_id = osr_ca.owner_table_id
               and hca.status = 'A';
        end if;
    exception
        when no_data_found then
            debug_msg(p_source_sys_ref||'|'||p_source_system||' not found','lookup_account_by_orig_sys_ref');
            p_derived_rec.party_id := null;
            p_derived_rec.cust_acct_id := null;
        when others then
            log_msg(sqlerrm, 'lookup_account_by_orig_sys_ref');
            raise;
    end lookup_account_by_orig_sys_ref;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      lookup_account_by_rram_ref
    --  Purpose
    --      Looks up a customer account by RRAM Reference flexfield
    --      Must be an active account
    --  Parameters
    --      p_rram_ref          RRAM Reference
    --      p_derived_rec       Derived values record
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure lookup_account_by_rram_ref(
        p_rram_ref          in varchar2,
        p_derived_rec       in out nocopy t_derived_rec )
    is
    begin
        debug_msg('begin','lookup_account_by_rram_ref');
        if p_rram_ref is not null then
            select hca.party_id, hca.cust_account_id, hca.account_number
              into p_derived_rec.party_id, p_derived_rec.cust_acct_id, p_derived_rec.account_number
              from hz_cust_accounts hca
             where hca.attribute2 = p_rram_ref -- TODO: ensure this attribute column is correct after DFF config in DTPLI
               and hca.status = 'A';
        end if;
    exception
        when no_data_found then
            debug_msg(p_rram_ref||' not found','lookup_account_by_rram_ref');
            p_derived_rec.party_id := null;
            p_derived_rec.cust_acct_id := null;
        when too_many_rows then
            debug_msg('multiple accounts with rram reference '''||p_rram_ref||''' exist','lookup_account_by_rram_ref');
            p_derived_rec.party_id := null;
            p_derived_rec.cust_acct_id := null;
            raise ex_multiple_account_match;
        when others then
            log_msg(sqlerrm, 'lookup_account_by_rram_ref');
            raise;
    end lookup_account_by_rram_ref;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      lookup_account_by_name
    --  Purpose
    --      Looks up a customer account by Account Name
    --      Must be an active account
    --  Parameters
    --      p_account_name      Account Name
    --      p_derived_rec       Derived values record
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure lookup_account_by_name(
        p_account_name      in varchar2,
        p_derived_rec       in out nocopy t_derived_rec )
    is
    begin
        debug_msg('begin','lookup_account_by_name');
        if p_account_name is not null then
            select hca.party_id, hca.cust_account_id, hca.account_number
              into p_derived_rec.party_id, p_derived_rec.cust_acct_id, p_derived_rec.account_number
              from hz_cust_accounts hca
             where upper(hca.account_name) = trim(upper(p_account_name))
               and hca.status = 'A';
        end if;
    exception
        when no_data_found then
            debug_msg(p_account_name||' not found','lookup_account_by_name');
            p_derived_rec.party_id := null;
            p_derived_rec.cust_acct_id := null;
        when too_many_rows then
            debug_msg('multiple accounts with name '''||p_account_name||''' exist','lookup_account_by_name');
            p_derived_rec.party_id := null;
            p_derived_rec.cust_acct_id := null;
            raise ex_multiple_account_match;
        when others then
            log_msg(sqlerrm, 'lookup_account_by_name');
            raise;
    end lookup_account_by_name;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      lookup_account_by_party_name
    --  Purpose
    --      Looks up a customer account by Account Name
    --      Must be an active account
    --  Parameters
    --      p_party_name        Party Name
    --      p_derived_rec       Derived values record
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure lookup_account_by_party_name(
        p_party_name        in varchar2,
        p_derived_rec       in out nocopy t_derived_rec )
    is
    begin
        debug_msg('begin','lookup_account_by_party_name');
        if p_party_name is not null then
            select hca.party_id, hca.cust_account_id, hca.account_number
              into p_derived_rec.party_id, p_derived_rec.cust_acct_id, p_derived_rec.account_number
              from hz_cust_accounts hca
                 , hz_parties hp
             where hp.party_id = hca.party_id
               and upper(hp.party_name) = trim(upper(p_party_name))
               and hca.status = 'A';
        end if;
    exception
        when no_data_found then
            debug_msg(p_party_name||' not found','lookup_account_by_party_name');
            p_derived_rec.party_id := null;
            p_derived_rec.cust_acct_id := null;
        when too_many_rows then
            debug_msg('multiple accounts with party name '''||p_party_name||''' exist','lookup_account_by_party_name');
            p_derived_rec.party_id := null;
            p_derived_rec.cust_acct_id := null;
            raise ex_multiple_account_match;
        when others then
            log_msg(sqlerrm, 'lookup_account_by_party_name');
            raise;
    end lookup_account_by_party_name;

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
            select hcas.cust_acct_site_id, hcas.party_site_id, hps.location_id, hps.party_id, hps.party_site_number
              into p_derived_rec.cust_acct_site_id
                 , p_derived_rec.party_site_id
                 , p_derived_rec.location_id
                 , p_derived_rec.site_party_id
                 , p_derived_rec.party_site_number
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
        when too_many_rows then
            debug_msg('multiple sites with site number '''||p_site_number||''' exist','lookup_site_by_number');
            p_derived_rec.cust_acct_site_id := null;
            p_derived_rec.party_site_id := null;
            p_derived_rec.location_id := null;
            p_derived_rec.site_party_id := null;
            raise ex_multiple_site_match;
        when others then
            log_msg(sqlerrm, 'lookup_site_by_number');
            raise;
    end lookup_site_by_number;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      lookup_site_by_orig_sys_ref
    --  Purpose
    --      Looks up an account site by Original System Reference
    --      Must be an active site
    --  Parameters
    --      p_source_sys_ref    Original System Reference
    --      p_source_system     Source System
    --      p_derived_rec       Derived values record
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure lookup_site_by_orig_sys_ref(
        p_source_sys_ref    in varchar2,
        p_source_system     in varchar2,
        p_derived_rec       in out nocopy t_derived_rec )
    is
    begin
        debug_msg('begin','lookup_site_by_orig_sys_ref');
        if p_source_sys_ref is not null and
           p_source_system is not null
        then
            select osr_ps.owner_table_id
                 , osr_cas.owner_table_id
                 , hps.location_id
                 , hps.party_id
                 , hps.party_site_number
              into p_derived_rec.party_site_id
                 , p_derived_rec.cust_acct_site_id
                 , p_derived_rec.location_id
                 , p_derived_rec.site_party_id
                 , p_derived_rec.party_site_number
              from hz_orig_sys_references osr_ps
                 , hz_orig_sys_references osr_cas
                 , hz_party_sites hps
                 , hz_cust_acct_sites_all hcas
            where osr_ps.orig_system_reference = p_source_sys_ref
              and osr_ps.orig_system = p_source_system
              and osr_ps.owner_table_name = 'HZ_PARTY_SITES'
              and osr_cas.orig_system = osr_ps.orig_system
              and osr_cas.owner_table_name = 'HZ_CUST_ACCT_SITES_ALL'
              and osr_cas.orig_system_reference = osr_ps.orig_system_reference
              and hps.party_site_id = osr_ps.owner_table_id
              and hcas.cust_acct_site_id = osr_cas.owner_table_id
              and hcas.status = 'A';
        end if;
    exception
        when no_data_found then
            debug_msg(p_source_sys_ref||'|'||p_source_system||' not found','lookup_site_by_orig_sys_ref');
            p_derived_rec.cust_acct_site_id := null;
            p_derived_rec.party_site_id := null;
            p_derived_rec.location_id := null;
            p_derived_rec.site_party_id := null;
        when others then
            log_msg(sqlerrm, 'lookup_site_by_orig_sys_ref');
            raise;
    end lookup_site_by_orig_sys_ref;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      lookup_site_by_rram_ref
    --  Purpose
    --      Looks up an account site by RRAM Reference flexfield
    --      Must be an active site
    --  Parameters
    --      p_rram_ref          RRAM Reference
    --      p_derived_rec       Derived values record
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure lookup_site_by_rram_ref(
        p_rram_ref          in varchar2,
        p_derived_rec       in out nocopy t_derived_rec )
    is
    begin
        debug_msg('begin','lookup_site_by_rram_ref');
        if p_rram_ref is not null then
            select hcas.cust_acct_site_id, hcas.party_site_id, hps.location_id, hps.party_id, hps.party_site_number
              into p_derived_rec.cust_acct_site_id
                 , p_derived_rec.party_site_id
                 , p_derived_rec.location_id
                 , p_derived_rec.site_party_id
                 , p_derived_rec.party_site_number
              from hz_cust_acct_sites_all hcas
                 , hz_party_sites hps
             where hps.party_site_id = hcas.party_site_id
               and hcas.attribute3 = p_rram_ref  -- TODO: ensure this attribute column is correct after DFF config in DTPLI
               and hcas.org_id = g_org_id
               and hcas.status = 'A';
        end if;
    exception
        when no_data_found then
            debug_msg(p_rram_ref||' not found','lookup_site_by_rram_ref');
            p_derived_rec.cust_acct_site_id := null;
            p_derived_rec.party_site_id := null;
            p_derived_rec.location_id := null;
            p_derived_rec.site_party_id := null;
        when too_many_rows then
            debug_msg('multiple sites with rram reference '''||p_rram_ref||''' exist','lookup_site_by_rram_ref');
            p_derived_rec.cust_acct_site_id := null;
            p_derived_rec.party_site_id := null;
            p_derived_rec.location_id := null;
            p_derived_rec.site_party_id := null;
            raise ex_multiple_site_match;
        when others then
            log_msg(sqlerrm, 'lookup_site_by_rram_ref');
            raise;
    end lookup_site_by_rram_ref;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      lookup_site_by_tax_reg
    --  Purpose
    --      Looks up an account site by ABN/ACN
    --      Must be an active site
    --  Parameters
    --      p_tax_reg           ABN or ACN
    --      p_derived_rec       Derived values record
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure lookup_site_by_tax_reg(
        p_tax_reg           in varchar2,
        p_derived_rec       in out nocopy t_derived_rec )
    is
    begin
        debug_msg('begin','lookup_site_by_tax_reg');
        if p_tax_reg is not null then
            select hcas.cust_acct_site_id, hcas.party_site_id, hps.location_id
                 , hps.party_id, hcsu.site_use_id, hps.party_site_number
              into p_derived_rec.cust_acct_site_id
                 , p_derived_rec.party_site_id
                 , p_derived_rec.location_id
                 , p_derived_rec.site_party_id
                 , p_derived_rec.site_use_id
                 , p_derived_rec.party_site_number
              from hz_cust_acct_sites_all hcas
                 , hz_party_sites hps
                 , hz_cust_site_uses hcsu
             where hps.party_site_id = hcas.party_site_id
               and hcsu.cust_acct_site_id = hcas.cust_acct_site_id
               and hcsu.tax_reference = p_tax_reg
               and hcas.org_id = g_org_id
               and hcas.status = 'A';
        end if;
    exception
        when no_data_found then
            debug_msg(p_tax_reg||' not found','lookup_site_by_tax_reg');
            p_derived_rec.cust_acct_site_id := null;
            p_derived_rec.party_site_id := null;
            p_derived_rec.location_id := null;
            p_derived_rec.site_party_id := null;
        when too_many_rows then
            debug_msg('multiple sites with abn/acn '''||p_tax_reg||''' exist','lookup_site_by_tax_reg');
            p_derived_rec.cust_acct_site_id := null;
            p_derived_rec.party_site_id := null;
            p_derived_rec.location_id := null;
            p_derived_rec.site_party_id := null;
            raise ex_multiple_site_match;
        when others then
            log_msg(sqlerrm, 'lookup_site_by_tax_reg');
            raise;
    end lookup_site_by_tax_reg;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      lookup_site_use_by_tax_reg
    --  Purpose
    --      Looks up an account site use by ABN/ACN
    --      Must be an active site use
    --  Parameters
    --      p_tax_reg           ABN or ACN
    --      p_derived_rec       Derived values record
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure lookup_site_use_by_tax_reg(
        p_tax_reg           in varchar2,
        p_derived_rec       in out nocopy t_derived_rec )
    is
    begin
        debug_msg('begin','lookup_site_use_by_tax_reg');
        if ( p_derived_rec.cust_acct_site_id is not null and
             p_tax_reg is not null )
        then
            select hcasu.site_use_id
              into p_derived_rec.site_use_id
              from hz_cust_site_uses hcasu
             where hcasu.cust_acct_site_id = p_derived_rec.cust_acct_site_id
               and hcasu.status = 'A'
               and hcasu.tax_reference = p_tax_reg;
        end if;
    exception
        when no_data_found then
            debug_msg(p_tax_reg||' not found','lookup_site_use_by_tax_reg');
            p_derived_rec.site_use_id := null;
        when too_many_rows then
            debug_msg('multiple site uses with abn/acn '''||p_tax_reg||''' exist','lookup_site_use_by_tax_reg');
            p_derived_rec.site_use_id := null;
            raise ex_multiple_site_use_match;
        when others then
            log_msg(sqlerrm, 'lookup_site_use_by_tax_reg');
            raise;
    end lookup_site_use_by_tax_reg;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      lookup_site_use_by_location
    --  Purpose
    --      Looks up an account site use by use Location
    --      Must be an active site use
    --  Parameters
    --      p_location          Use Location
    --      p_derived_rec       Derived values record
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure lookup_site_use_by_location(
        p_location          in varchar2,
        p_derived_rec       in out nocopy t_derived_rec )
    is
    begin
        debug_msg('begin','lookup_site_use_by_location');
        if p_derived_rec.cust_acct_site_id is not null then
            select hcasu.site_use_id
              into p_derived_rec.site_use_id
              from hz_cust_site_uses hcasu
             where hcasu.cust_acct_site_id = p_derived_rec.cust_acct_site_id
               and hcasu.location = p_location
               and hcasu.status = 'A';
        end if;
    exception
        when no_data_found then
            debug_msg(p_location||' not found','lookup_site_use_by_location');
            p_derived_rec.site_use_id := null;
        when others then
            log_msg(sqlerrm, 'lookup_site_use_by_location');
            raise;
    end lookup_site_use_by_location;

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
        p_use               in varchar2 default 'BILL-TO',
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
    --  Procedure
    --      lookup_site_use
    --  Purpose
    --      Looks up an account site by ABN/ACN
    --      Must be an active and be the primary use
    --  Parameters
    --      p_stage_row         Stage table row
    --      p_derived_rec       Derived values record
    --      p_use               Usage (Business Purpose, defaults to BILL_TO)
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    --  sryan       24/04/2015	added additional lookup for location by site number
    -- ------------------------------------------------------------------------
    procedure lookup_site_use(
        p_stage_row         in out nocopy c_stage%rowtype,
        p_derived_rec       in out nocopy t_derived_rec,
        p_use               in varchar2 default 'BILL_TO' )
    is
        l_id_location       varchar2(30) := p_stage_row.source_system || '-' || p_derived_rec.cust_acct_site_id;
        l_num_location      varchar2(30) := p_stage_row.source_system || '-' || p_derived_rec.party_site_number;
    begin
        debug_msg('begin','lookup_site_use');
        -- lookup_customer_site() may already have looked up the site use if it found
        -- the site by abn/acn.  check this as there may not be a need do anything
        if p_derived_rec.site_use_id is not null then
            debug_msg('p_derived_rec.site_use_id already has value '||p_derived_rec.site_use_id);
            return;
        end if;

        -- lookup by use location
        lookup_site_use_by_location(l_id_location, p_derived_rec);
        if p_derived_rec.site_use_id is not null then
            log_msg('Site Use found by Location '''||l_id_location||'''');
            return;
        else
            lookup_site_use_by_location(l_num_location, p_derived_rec);
            if p_derived_rec.site_use_id is not null then
                log_msg('Site Use found by Location '''||l_num_location||'''');
                return;
            end if;
        end if;

        -- lookup by abn/acn
        lookup_site_use_by_tax_reg(p_stage_row.abn, p_derived_rec);
        if p_derived_rec.site_use_id is not null then
            log_msg('Site Use found by ABN/ACN '''||p_stage_row.abn||'''');
            return;
        end if;

        -- lookup by use code (defaults to bill-to lookup)
        lookup_site_use_by_use(p_use, p_derived_rec);
        if p_derived_rec.site_use_id is not null then
            log_msg('Site Use found by '''||p_use||'''');
            return;
        end if;
    exception
        when others then
            log_msg(sqlerrm, 'lookup_site_use');
            raise;
    end lookup_site_use;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      lookup_customer_site
    --  Purpose
    --      Looks up the Account Site via various methods
    --      Order of lookups:
    --        1. By Party Site Number
    --        2. By Original System Reference
    --        3. RRAM Reference Flexfield
    --        4. ABN/ACN
    --  Parameters
    --      p_stage_row         Stage table row
    --      p_derived_rec       Derived values record
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure lookup_customer_site(
        p_stage_row         in out nocopy c_stage%rowtype,
        p_derived_rec       in out nocopy t_derived_rec )
    is
    begin
        debug_msg('begin','lookup_customer_site');
        -- lookup by party site number
        if p_stage_row.party_site_number is not null then
            lookup_site_by_number(p_stage_row.party_site_number, p_derived_rec);
            if p_derived_rec.cust_acct_site_id is not null then
                log_msg('Cust Account Site found by Party Site Number');
                return;
            end if;
        end if;

        -- lookup by original system reference
        if ( p_stage_row.source_system_ref is not null and
                p_stage_row.source_system is not null )
        then
            lookup_site_by_orig_sys_ref(
                p_stage_row.source_system_ref,
                p_stage_row.source_system,
                p_derived_rec );
            if p_derived_rec.cust_acct_site_id is not null then
                log_msg('Cust Account Site found by Original System Reference');
                return;
            end if;
        end if;

        -- lookup by rram reference flexfield
        if p_stage_row.source_system_ref is not null then
            lookup_site_by_rram_ref(p_stage_row.source_system_ref, p_derived_rec);
            if p_derived_rec.cust_acct_site_id is not null then
                log_msg('Cust Account Site found by RRAM Reference Flexfield');
                return;
            end if;
        end if;

        -- lookup by abn/acn
        if p_stage_row.abn is not null then
            lookup_site_by_tax_reg(p_stage_row.abn, p_derived_rec);
            if p_derived_rec.cust_acct_site_id is not null then
                log_msg('Cust Account Site found by ABN/ACN');
                return;
            end if;
        end if;

    exception
        when others then
            log_msg(sqlerrm, 'lookup_customer_site');
            raise;
    end lookup_customer_site;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      lookup_customer_account
    --  Purpose
    --      Looks up the Customer Account via various methods
    --      Order of lookups:
    --        1. By Account Number
    --        2. By Original System Reference
    --        3. RRAM Reference Flexfield
    --        4. Account Name (non-case sensitive; leading and trailing spaces trimmed)
    --  Parameters
    --      p_stage_row         Stage table row
    --      p_derived_rec       Derived values record
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure lookup_customer_account(
        p_stage_row         in out nocopy c_stage%rowtype,
        p_derived_rec       in out nocopy t_derived_rec )
    is
    begin
        debug_msg('begin','lookup_customer_account');
        -- lookup by account number
        if p_stage_row.account_number is not null then
            lookup_account_by_number(p_stage_row.account_number, p_derived_rec);
            if p_derived_rec.cust_acct_id is not null then
                log_msg('Cust Account found by Account Number');
                return;
            end if;
        end if;

        -- lookup by original system reference
        if ( p_stage_row.source_system_ref is not null and
             p_stage_row.source_system is not null )
        then
            lookup_account_by_orig_sys_ref(
                p_stage_row.source_system_ref,
                p_stage_row.source_system,
                p_derived_rec );
            if p_derived_rec.cust_acct_id is not null then
                log_msg('Cust Account found by Original System Reference');
                return;
            end if;
        end if;

        -- lookup by rram reference flexfield
        if p_stage_row.source_system_ref is not null then
            lookup_account_by_rram_ref(p_stage_row.source_system_ref, p_derived_rec);
            if p_derived_rec.cust_acct_id is not null then
                log_msg('Cust Account found by RRAM Reference Flexfield');
                return;
            end if;
        end if;

        -- lookup by organization name match
        if p_stage_row.organization_name is not null then
            lookup_account_by_name(p_stage_row.organization_name, p_derived_rec);
            if p_derived_rec.cust_acct_id is not null then
                log_msg('Cust Account found by Organization Name match');
                return;
            end if;
        end if;

        -- lookup by party name match
        if p_stage_row.organization_name is not null then
            lookup_account_by_party_name(p_stage_row.organization_name, p_derived_rec);
            if p_derived_rec.cust_acct_id is not null then
                log_msg('Cust Account found by Party Name match');
                return;
            end if;
        end if;

    exception
        when others then
            log_msg(sqlerrm, 'lookup_customer_account');
            raise;
    end lookup_customer_account;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      lookup_debtor
    --  Purpose
    --      Looks up required TCA Ids for a Debtor (bill-to customer account)
    --      Returns values are placed in the derived record corresponding to
    --      the stage table row.
    --      (party_id, party_site_id, cust_acct_id, cust_acct_site_id,
    --       location_id, party_site_id, site_use_id)
    --  Parameters
    --      p_stage_tbl         Stage table collection
    --      p_derived_tbl       Derived values collection
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure lookup_debtor(
        p_stage_tbl         in out nocopy t_stage_tbl,
        p_derived_tbl       in out nocopy t_derived_tbl,
        i                   in number )
    is
    begin
        debug_msg('begin','lookup_debtor');
        -- customer account (gets party_id, cust_acct_id)
        lookup_customer_account(p_stage_tbl(i), p_derived_tbl(i));
        if p_derived_tbl(i).cust_acct_id is not null then
            -- customer account site
            -- (gets party_site_id, cust_acct_site_id, location_id, party_site_id)
            lookup_customer_site(p_stage_tbl(i), p_derived_tbl(i));
            if p_derived_tbl(i).cust_acct_site_id is not null then
                -- site_use_id may already have been found by abn lookup of cust site
                if p_derived_tbl(i).site_use_id is null then
                    -- site bill-to use (gets site_use_id)
                    lookup_site_use(p_stage_tbl(i), p_derived_tbl(i));
                    if p_derived_tbl(i).site_use_id is null then
                        log_msg('Site Use not found');
                    end if;
                end if;
            else
                log_msg('Cust Account Site not found');
            end if;
        else
            log_msg('Cust Account not found');
        end if;
    exception
        when others then
            log_msg(sqlerrm, 'lookup_debtor');
            raise;
    end lookup_debtor;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      get_lookup_value_row
    --  Purpose
    --      Retrieves a lookup value row
    --  Parameters
    --      p_lookup_code       Lookup Code
    --      p_lookup_type       Lookup Type
    --      p_lookup_value_row  Returned row
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure get_lookup_value_row(
        p_lookup_code in varchar2,
        p_lookup_type in varchar2,
        p_lookup_value_row in out nocopy fnd_lookup_values_vl%rowtype )
    is
    begin
        select lookup_code, meaning
          into p_lookup_value_row.lookup_code
             , p_lookup_value_row.meaning
          from fnd_lookup_values_vl
         where lookup_type = p_lookup_type
           and lookup_code = p_lookup_code
           and enabled_flag = 'Y'
           and sysdate between nvl(start_date_active, sysdate-1) and nvl(end_date_active, sysdate+1);
    exception
        when no_data_found then
            p_lookup_value_row.lookup_code:= null;
            p_lookup_value_row.meaning := null;
        when others then
            log_msg(sqlerrm, 'get_lookup_value_row');
            raise;
    end get_lookup_value_row;

    -- ------------------------------------------------------------------------
    --  Function
    --      valid_source_system
    --  Purpose
    --      Determines whether a source system value is valid
    --  Parameters
    --      p_source_system     Source System value
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    function valid_source_system(p_source_system in varchar2) return boolean
    is
        l_lookup_row      fnd_lookup_values_vl%rowtype;
        l_retval          boolean := false;
    begin
        -- if the source system matches an already validated source system then its valid
        if p_source_system = g_valid_source then
            l_retval := true;
        else
            -- lookup the source from ar lookup type ORIG_SYSTEM
            get_lookup_value_row(p_source_system, 'ORIG_SYSTEM', l_lookup_row);
            if l_lookup_row.lookup_code is not null then
                l_retval := true;
                -- set the valid source value
                g_valid_source := p_source_system;
            else
                l_retval := false;
            end if;
        end if;
        return l_retval;
    exception
        when others then
            log_msg(sqlerrm, 'valid_source_system');
            raise;
    end valid_source_system;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      lookup_profile_class
    --  Purpose
    --      Looks up a Profile Class row
    --  Parameters
    --      p_profile_class       Name of the profile class to lookup
    --      p_profile_class_row   Returned row
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure lookup_profile_class(
        p_profile_class         in varchar2,
        p_profile_class_row     in out nocopy hz_cust_profile_classes%rowtype )
    is
    begin
        debug_msg('begin','lookup_profile_class');
        select profile_class_id, name
          into p_profile_class_row.profile_class_id
             , p_profile_class_row.name
          from hz_cust_profile_classes
         where name = p_profile_class
           and status = 'A';
    exception
        when no_data_found then
            p_profile_class_row.name := null;
            p_profile_class_row.profile_class_id := null;
        when others then
            log_msg(sqlerrm, 'lookup_profile_class');
            raise;
    end lookup_profile_class;

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
    -- ------------------------------------------------------------------------
    procedure validate_stage_row_columns(
        p_stage_tbl       in out nocopy t_stage_tbl,
        p_derived_tbl     in out nocopy t_derived_tbl,
        i                 in number )
    is
        l_profile_class_row           hz_cust_profile_classes%rowtype;
        l_party_site_row              hz_party_sites%rowtype;
        l_error_found                 boolean := false;
    begin
        debug_msg('begin','validate_stage_row_columns');
        -- Source System must be a valid Oracle source
        if not valid_source_system(p_stage_tbl(i).source_system) then
            add_validation_error(p_stage_tbl(i).stage_id, 'Invalid SOURCE_SYSTEM '''
                ||p_stage_tbl(i).source_system||'''.  Not found');
            l_error_found := true;
        end if;

        -- Lookup Party/Account/Site/Bill-To
        begin
            lookup_debtor(p_stage_tbl, p_derived_tbl, i);
        exception
            when ex_multiple_account_match then
                add_validation_error(p_stage_tbl(i).stage_id, 'Multiple Account match');
                p_stage_tbl(i).interface_status := G_INT_STATUS_ERROR;
                return;
            when ex_multiple_site_match then
                add_validation_error(p_stage_tbl(i).stage_id, 'Multiple Site match');
                p_stage_tbl(i).interface_status := G_INT_STATUS_ERROR;
                return;
            when ex_multiple_site_use_match then
                add_validation_error(p_stage_tbl(i).stage_id, 'Multiple Site Use match');
                p_stage_tbl(i).interface_status := G_INT_STATUS_ERROR;
                return;
        end;

        debug_msg('party_id='||p_derived_tbl(i).party_id || '; ' ||
            'party_site_id='||p_derived_tbl(i).party_site_id || '; ' ||
            'cust_acct_id='||p_derived_tbl(i).cust_acct_id || '; ' ||
            'cust_acct_site_id='||p_derived_tbl(i).cust_acct_site_id || '; ' ||
            'location_id='||p_derived_tbl(i).location_id || '; ' ||
            'site_use_id='||p_derived_tbl(i).site_use_id || '; ' ||
            'site_party_id='||p_derived_tbl(i).site_party_id
            ,'lookup_debtor');

        -- The Party Site must belong to the Party
        if ( p_derived_tbl(i).site_party_id is not null and
             p_derived_tbl(i).party_id is not null and
             ( p_derived_tbl(i).site_party_id <> p_derived_tbl(i).party_id )
            )
        then
            add_validation_error(p_stage_tbl(i).stage_id, 'Invalid ACCOUNT_NUMBER/PARTY_SITE_NUMBER combination');
            l_error_found := true;
        end if;

        -- Account Number if provided must exist in Oracle
        if p_stage_tbl(i).account_number is not null and p_derived_tbl(i).party_id is null then
            add_validation_error(p_stage_tbl(i).stage_id, 'Invalid ACCOUNT_NUMBER '''
                || p_stage_tbl(i).account_number||'''.  Not found');
            l_error_found := true;
        end if;

        -- Party Site Number if provided must exist in Oracle and be associated with the party
        if p_stage_tbl(i).party_site_number is not null and p_derived_tbl(i).party_site_id is null then
            add_validation_error(p_stage_tbl(i).stage_id, 'Invalid PARTY_SITE_NUMBER '''
                || p_stage_tbl(i).party_site_number||'''.  Not found');
            l_error_found := true;
        end if;

        -- Profile Class if provided must be a valid Oracle profile class
        if p_stage_tbl(i).profile_class is not null then
            lookup_profile_class(p_stage_tbl(i).profile_class, l_profile_class_row);
            if l_profile_class_row.profile_class_id is not null then
                p_derived_tbl(i).profile_class_id := l_profile_class_row.profile_class_id;
            else
                add_validation_error(p_stage_tbl(i).stage_id, 'Invalid PROFILE_CLASS '''
                    || p_stage_tbl(i).profile_class||'''.  Not found');
                l_error_found := true;
            end if;
        end if;

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
    --      map_org_party_values
    --  Purpose
    --      Maps stage table values to the Organization API record.
    --  Parameters
    --      p_stage_row         Stage table row
    --      p_organization_rec  API record for an organization
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure map_org_party_values(
        p_stage_row           in out nocopy c_stage%rowtype,
        p_derived_rec         in out nocopy t_derived_rec,
        p_organization_rec    in out nocopy hz_party_v2pub.organization_rec_type )
    is
    begin
        debug_msg('begin','map_org_party_values');
        p_organization_rec.organization_name      := p_stage_row.organization_name;
        p_organization_rec.created_by_module      := g_created_by_module;
        p_organization_rec.party_rec.orig_system  := p_stage_row.source_system;
        p_organization_rec.party_rec.orig_system_reference := p_stage_row.source_system_ref;
        p_organization_rec.party_rec.status       := 'A';
        p_organization_rec.party_rec.party_id     := p_derived_rec.party_id; -- will have a value for updates
    exception
        when others then
            log_msg(sqlerrm, 'map_org_party_values');
            raise;
    end map_org_party_values;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      map_location_values
    --  Purpose
    --      Maps stage table values to the Location API record.
    --  Parameters
    --      p_stage_row         Stage table row
    --      p_location_rec      API record for a Location
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure map_location_values(
        p_stage_row           in out nocopy c_stage%rowtype,
        p_derived_rec         in out nocopy t_derived_rec,
        p_location_rec        in out nocopy hz_location_v2pub.location_rec_type )
    is
    begin
        debug_msg('begin','map_location_values');
        p_location_rec.country                  := p_stage_row.country;
        p_location_rec.address1                 := p_stage_row.address_line1;
        p_location_rec.address2                 := p_stage_row.address_line2;
        p_location_rec.address3                 := p_stage_row.address_line3;
        p_location_rec.city                     := p_stage_row.city;
        p_location_rec.state                    := p_stage_row.state;
        p_location_rec.postal_code              := p_stage_row.postcode;
        p_location_rec.created_by_module        := g_created_by_module;
        p_location_rec.location_id              := p_derived_rec.location_id; -- will have a value for updates
    exception
        when others then
            log_msg(sqlerrm, 'map_location_values');
            raise;
    end map_location_values;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      map_cust_acct_values
    --  Purpose
    --      Maps stage table values to the Customer Account API record.
    --  Parameters
    --      p_stage_row         Stage table row
    --      p_derived_rec       Derived or looked up values
    --      p_cust_acct_rec     API record for a Customer Account
    --      p_organization_rec  API record for an Organization Account
    --      p_cust_profile_rec  API record for a Customer Profile
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure map_cust_acct_values(
        p_stage_row         in out nocopy c_stage%rowtype,
        p_derived_rec       in out nocopy t_derived_rec,
        p_cust_acct_rec     in out nocopy hz_cust_account_v2pub.cust_account_rec_type,
        p_organization_rec  in out nocopy hz_party_v2pub.organization_rec_type,
        p_cust_profile_rec  in out nocopy hz_customer_profile_v2pub.customer_profile_rec_type )
    is
    begin
        debug_msg('begin','map_cust_acct_values');
        p_cust_profile_rec.profile_class_id     := p_derived_rec.profile_class_id;
        p_cust_acct_rec.account_name            := p_organization_rec.organization_name;
        p_cust_acct_rec.status                  := 'A';
        p_cust_acct_rec.customer_type           := 'R'; -- for external
        p_cust_acct_rec.attribute_category      := 'RRAMS';
        p_cust_acct_rec.attribute2              := p_stage_row.source_system_ref;
        p_cust_acct_rec.status                  := 'A';
        p_cust_acct_rec.created_by_module       := g_created_by_module;
        p_cust_acct_rec.orig_system             := p_stage_row.source_system;
        p_cust_acct_rec.orig_system_reference   := p_stage_row.source_system_ref;
        p_cust_acct_rec.cust_account_id         := p_derived_rec.cust_acct_id; -- will have a value for updates
    exception
        when others then
            log_msg(sqlerrm, 'map_cust_acct_values');
            raise;
    end map_cust_acct_values;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      map_cust_acct_site_values
    --  Purpose
    --      Maps stage table values to the Customer Account Site API record.
    --  Parameters
    --      p_stage_row           Stage table row
    --      p_derived_rec         Derived or looked up values
    --      p_cust_acct_site_rec  API record for a Customer Account Site
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure map_cust_acct_site_values(
        p_stage_row           in out nocopy c_stage%rowtype,
        p_derived_rec         in out nocopy t_derived_rec,
        p_cust_acct_site_rec  in out nocopy hz_cust_account_site_v2pub.cust_acct_site_rec_type )
    is
    begin
        debug_msg('begin','map_cust_acct_site_values');
        p_cust_acct_site_rec.status                  := 'A';
        p_cust_acct_site_rec.created_by_module       := g_created_by_module;
        p_cust_acct_site_rec.attribute_category      := 'RRAMS';
        p_cust_acct_site_rec.attribute1              := 'PRINT'; -- transmission method (dtpli mandatory)
        p_cust_acct_site_rec.attribute3              := p_stage_row.source_system_ref;
        p_cust_acct_site_rec.orig_system             := p_stage_row.source_system;
        p_cust_acct_site_rec.orig_system_reference   := p_stage_row.source_system_ref;
        p_cust_acct_site_rec.cust_acct_site_id       := p_derived_rec.cust_acct_site_id; -- will have a value for updates
    exception
        when others then
            log_msg(sqlerrm, 'map_cust_acct_site_values');
            raise;
    end map_cust_acct_site_values;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      map_cust_acct_site_use_values
    --  Purpose
    --      Maps stage table values to the Customer Account Site Usage API record.
    --  Parameters
    --      p_stage_row           Stage table row
    --      p_derived_rec         Derived or looked up values
    --      p_cust_acct_site_rec  API record for a Customer Account Site
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure map_cust_acct_site_use_values(
        p_stage_row           in out nocopy c_stage%rowtype,
        p_derived_rec         in out nocopy t_derived_rec,
        p_cust_site_use_rec   in out nocopy hz_cust_account_site_v2pub.cust_site_use_rec_type )
    is
        l_location          varchar2(30) := p_stage_row.source_system || '-' || p_cust_site_use_rec.cust_acct_site_id;
    begin
        debug_msg('begin','map_cust_acct_site_use_values');
        debug_msg('l_location='||l_location,'map_cust_acct_site_use_values');
        p_cust_site_use_rec.status             := 'A';
        p_cust_site_use_rec.created_by_module  := g_created_by_module;
        p_cust_site_use_rec.site_use_code      := 'BILL_TO';
        p_cust_site_use_rec.location           := l_location;
        p_cust_site_use_rec.tax_reference      := p_stage_row.abn;
        p_cust_site_use_rec.primary_flag       := 'Y';
        p_cust_site_use_rec.site_use_id        := p_derived_rec.site_use_id;
    exception
        when others then
            log_msg(sqlerrm, 'map_cust_acct_site_use_values');
            raise;
    end map_cust_acct_site_use_values;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      create_org_party
    --  Purpose
    --      Wrapper procedure to create a Party of type Organization
    --  Parameters
    --      p_stage_row         Stage table row
    --      p_organization_rec  API record for an organization
    --      p_success           Success flag [true|false]
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure create_org_party(
        p_stage_row           in out nocopy c_stage%rowtype,
        p_organization_rec    in out nocopy hz_party_v2pub.organization_rec_type,
        p_success             out boolean )
    is
        l_return_status         varchar2(30);
        l_msg_count             number := 0;
        l_msg_data              varchar2(300);
        l_party_id              number;
        l_party_number          varchar2(30);
        l_profile_id            number;
    begin
        debug_msg('begin','create_org_party');
        hz_party_v2pub.create_organization(
              p_init_msg_list                         => FND_API.G_TRUE,
              p_organization_rec                      => p_organization_rec,
              x_party_id                              => l_party_id,
              x_party_number                          => l_party_number,
              x_profile_id                            => l_profile_id,
              x_return_status                         => l_return_status,
              x_msg_count                             => l_msg_count,
              x_msg_data                              => l_msg_data
          );
        log_msg('Create_Organization API Result:');
        if l_return_status = fnd_api.g_ret_sts_success then
            log_msg('   x_party_id = ' || l_party_id);
            log_msg('   x_party_number = ' || l_party_number);
            log_msg('   x_profile_id = ' || l_profile_id);
            p_organization_rec.party_rec.party_id := l_party_id;
            p_organization_rec.party_rec.party_number := l_party_number;
            p_success := true;
        else
            log_msg('   Failed with ' || l_msg_count || ' error(s)');
            assign_api_errors(p_stage_row.stage_id, l_msg_count, l_msg_data);
            p_success := false;
        end if;
    exception
        when others then
            log_msg(sqlerrm, 'create_org_party');
            raise;
    end create_org_party;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      create_location
    --  Purpose
    --      Wrapper procedure to create a Location
    --  Parameters
    --      p_stage_row         Stage table row
    --      p_location_rec      API record for a Location
    --      p_success           Success flag [true|false]
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure create_location(
        p_stage_row       in out nocopy c_stage%rowtype,
        p_location_rec    in out nocopy hz_location_v2pub.location_rec_type,
        p_success         out boolean )
    is
        l_return_status         varchar2(30);
        l_msg_count             number := 0;
        l_msg_data              varchar2(300);
        l_location_id           number;
    begin
        debug_msg('begin','create_location');
        hz_location_v2pub.create_location(
              p_init_msg_list                         => FND_API.G_TRUE,
              p_location_rec                          => p_location_rec,
              x_location_id                           => l_location_id,
              x_return_status                         => l_return_status,
              x_msg_count                             => l_msg_count,
              x_msg_data                              => l_msg_data
          );
        log_msg('Create_Location API Result:');
        if l_return_status = fnd_api.g_ret_sts_success then
            log_msg('   x_location_id = ' || l_location_id);
            p_location_rec.location_id := l_location_id;
            p_success := true;
        else
            log_msg('   Failed with ' || l_msg_count || ' error(s)');
            assign_api_errors(p_stage_row.stage_id, l_msg_count, l_msg_data);
            p_success := false;
        end if;
    exception
        when others then
            log_msg(sqlerrm, 'create_location');
            raise;
    end create_location;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      create_party_site
    --  Purpose
    --      Wrapper procedure to create a Party Site
    --  Parameters
    --      p_stage_row         Stage table row
    --      p_party_site_rec    API record for a Party Site
    --      p_success           Success flag [true|false]
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure create_party_site(
        p_stage_row       in out nocopy c_stage%rowtype,
        p_party_site_rec  in out nocopy hz_party_site_v2pub.party_site_rec_type,
        p_success         out boolean )
    is
        l_return_status         varchar2(30);
        l_msg_count             number := 0;
        l_msg_data              varchar2(300);
        l_party_site_id         number;
        l_party_site_number     varchar2(30);
    begin
        debug_msg('begin','create_party_site');
        p_party_site_rec.identifying_address_flag := 'Y';
        p_party_site_rec.orig_system_reference    := p_stage_row.source_system_ref;
        p_party_site_rec.orig_system              := p_stage_row.source_system;
        p_party_site_rec.status                 := 'A';
        p_party_site_rec.created_by_module      := g_created_by_module;

        hz_party_site_v2pub.create_party_site(
              p_init_msg_list                         => FND_API.G_TRUE,
              p_party_site_rec                        => p_party_site_rec,
              x_party_site_id                         => l_party_site_id,
              x_party_site_number                     => l_party_site_number,
              x_return_status                         => l_return_status,
              x_msg_count                             => l_msg_count,
              x_msg_data                              => l_msg_data
          );

        log_msg('Create_Party_Site API Result:');
        if l_return_status = fnd_api.g_ret_sts_success then
            log_msg('   x_party_site_id = ' || l_party_site_id);
            log_msg('   x_party_site_number = ' || l_party_site_number);
            p_party_site_rec.party_site_id := l_party_site_id;
            p_party_site_rec.party_site_number := l_party_site_number;
            p_success := true;
        else
            log_msg('   Failed with ' || l_msg_count || ' error(s)');
            assign_api_errors(p_stage_row.stage_id, l_msg_count, l_msg_data);
            p_success := false;
        end if;

    exception
        when others then
            log_msg(sqlerrm, 'create_party_site');
            raise;
    end create_party_site;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      create_org_cust_account
    --  Purpose
    --      Wrapper procedure to create a Customer Account
    --  Parameters
    --      p_stage_row         Stage table row
    --      p_cust_acct_rec     API record for a Customer Account
    --      p_organization_rec  API record for an Organization Account
    --      p_cust_profile_rec  API record for a Customer Profile
    --      p_success           Success flag [true|false]
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure create_org_cust_account(
        p_stage_row         in out nocopy c_stage%rowtype,
        p_cust_acct_rec     in out nocopy hz_cust_account_v2pub.cust_account_rec_type,
        p_organization_rec  in out nocopy hz_party_v2pub.organization_rec_type,
        p_cust_profile_rec  in out nocopy hz_customer_profile_v2pub.customer_profile_rec_type,
        p_success           out boolean )
    is
        l_return_status         varchar2(30);
        l_msg_count             number := 0;
        l_msg_data              varchar2(300);
        l_cust_account_id       number;
        l_account_number        varchar2(30);
        l_party_id              number;
        l_party_number          varchar2(30);
        l_profile_id            number;
    begin
        debug_msg('begin','create_org_cust_account');
        hz_cust_account_v2pub.create_cust_account(
              p_init_msg_list                         => FND_API.G_TRUE,
              p_cust_account_rec                      => p_cust_acct_rec,
              p_organization_rec                      => p_organization_rec,
              p_customer_profile_rec                  => p_cust_profile_rec,
              p_create_profile_amt                    => FND_API.G_TRUE,
              x_cust_account_id                       => l_cust_account_id,
              x_account_number                        => l_account_number,
              x_party_id                              => l_party_id,
              x_party_number                          => l_party_number,
              x_profile_id                            => l_profile_id,
              x_return_status                         => l_return_status,
              x_msg_count                             => l_msg_count,
              x_msg_data                              => l_msg_data
          );

        log_msg('Create_Cust_Account API Result:');
        if l_return_status = fnd_api.g_ret_sts_success then
            log_msg('   x_cust_account_id = ' || l_cust_account_id);
            log_msg('   x_account_number = ' || l_account_number);
            log_msg('   x_party_id = ' || l_party_id);
            log_msg('   x_party_number = ' || l_party_number);
            log_msg('   x_profile_id = ' || l_profile_id);
            p_cust_acct_rec.cust_account_id := l_cust_account_id;
            p_cust_acct_rec.account_number  := l_account_number;
            p_success := true;
        else
            log_msg('   Failed with ' || l_msg_count || ' error(s)');
            assign_api_errors(p_stage_row.stage_id, l_msg_count, l_msg_data);
            p_success := false;
        end if;

    exception
        when others then
            log_msg(sqlerrm, 'create_org_cust_account');
            raise;
    end create_org_cust_account;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      create_cust_acct_site
    --  Purpose
    --      Wrapper procedure to create a Customer Account Site
    --  Parameters
    --      p_stage_row               Stage table row
    --      p_cust_account_site_rec   API record for a Customer Account Site
    --      p_success                 Success flag [true|false]
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure create_cust_acct_site(
        p_stage_row               in out nocopy c_stage%rowtype,
        p_cust_account_site_rec   in out nocopy hz_cust_account_site_v2pub.cust_acct_site_rec_type,
        p_success                 out boolean )
    is
        l_return_status         varchar2(30);
        l_msg_count             number := 0;
        l_msg_data              varchar2(300);
        l_cust_acct_site_id     number;
    begin
        debug_msg('begin','create_cust_acct_site');
        hz_cust_account_site_v2pub.create_cust_acct_site(
              p_init_msg_list                         => FND_API.G_TRUE,
              p_cust_acct_site_rec                    => p_cust_account_site_rec,
              x_cust_acct_site_id                     => l_cust_acct_site_id,
              x_return_status                         => l_return_status,
              x_msg_count                             => l_msg_count,
              x_msg_data                              => l_msg_data
          );

        log_msg('Create_Cust_Acct_Site API Result:');
        if l_return_status = fnd_api.g_ret_sts_success then
            log_msg('   x_cust_acct_site_id = ' || l_cust_acct_site_id);
            p_cust_account_site_rec.cust_acct_site_id := l_cust_acct_site_id;
            p_success := true;
        else
            log_msg('   Failed with ' || l_msg_count || ' error(s)');
            assign_api_errors(p_stage_row.stage_id, l_msg_count, l_msg_data);
            p_success := false;
        end if;

    exception
        when others then
            log_msg(sqlerrm, 'create_cust_acct_site');
            raise;
    end create_cust_acct_site;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      create_cust_acct_site_use
    --  Purpose
    --      Wrapper procedure to create a Customer Account Site Bill-To Usage
    --  Parameters
    --      p_stage_row               Stage table row
    --      p_cust_site_use_rec       API record for a Customer Account Site Usage
    --      p_cust_profile_rec        API record for a Customer Profile
    --      p_success                 Success flag [true|false]
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure create_cust_acct_site_use(
        p_stage_row               in out nocopy c_stage%rowtype,
        p_cust_site_use_rec       in out nocopy hz_cust_account_site_v2pub.cust_site_use_rec_type,
        p_cust_profile_rec        in out nocopy hz_customer_profile_v2pub.customer_profile_rec_type,
        p_success                 out boolean )
    is
        l_return_status         varchar2(30);
        l_msg_count             number := 0;
        l_msg_data              varchar2(300);
        l_site_use_id           number;
    begin
        debug_msg('begin','create_cust_acct_site_use');

        hz_cust_account_site_v2pub.create_cust_site_use(
              p_init_msg_list                         => FND_API.G_TRUE,
              p_cust_site_use_rec                     => p_cust_site_use_rec,
              p_customer_profile_rec                  => p_cust_profile_rec,
              p_create_profile                        => FND_API.G_TRUE,
              p_create_profile_amt                    => FND_API.G_TRUE,
              x_site_use_id                           => l_site_use_id,
              x_return_status                         => l_return_status,
              x_msg_count                             => l_msg_count,
              x_msg_data                              => l_msg_data
          );

        log_msg('Create_Cust_Acct_Site_Use API Result:');
        if l_return_status = fnd_api.g_ret_sts_success then
            log_msg('   x_site_use_id = ' || l_site_use_id);
            p_cust_site_use_rec.site_use_id := l_site_use_id;
            p_success := true;
        else
            log_msg('   Failed with ' || l_msg_count || ' error(s)');
            assign_api_errors(p_stage_row.stage_id, l_msg_count, l_msg_data);
            p_success := false;
        end if;

    exception
        when others then
            log_msg(sqlerrm, 'create_cust_acct_site_use');
            raise;
    end create_cust_acct_site_use;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      create_customer
    --  Purpose
    --      Encapsulates the calling of receivables APIs to create a single customer
    --      Performs operations in an autonomous transaction to ensure all or none
    --      processing.
    --  Parameters
    --      p_stage_row         Stage table row with new values
    --      p_derived_rec       Derived or looked up values
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure create_customer(
        p_stage_row         in out nocopy c_stage%rowtype,
        p_derived_rec       in out nocopy t_derived_rec
        )
    is
        pragma autonomous_transaction;
        l_organization_rec        hz_party_v2pub.organization_rec_type;
        l_location_rec            hz_location_v2pub.location_rec_type;
        l_party_site_rec          hz_party_site_v2pub.party_site_rec_type;
        l_cust_acct_rec           hz_cust_account_v2pub.cust_account_rec_type;
        l_cust_profile_rec        hz_customer_profile_v2pub.customer_profile_rec_type;
        l_cust_account_site_rec   hz_cust_account_site_v2pub.cust_acct_site_rec_type;
        l_cust_site_use_rec       hz_cust_account_site_v2pub.cust_site_use_rec_type;
        l_success                 boolean := true;
    begin
        debug_msg('begin','create_customer');
        -- --------------------------- Party ---------------------------- --
        if p_derived_rec.party_id is null then
            log_msg('Creating Organization party');
            map_org_party_values(p_stage_row, p_derived_rec, l_organization_rec);
            create_org_party(p_stage_row, l_organization_rec, l_success);
            if not l_success then
                p_stage_row.interface_status := G_INT_STATUS_ERROR;
                rollback;
                return;
            else
                insert_debtor_audit(p_stage_row.stage_id, g_interface_type, 'N', 'Party');
            end if;
        else
            -- this is when we're reusing an existing party
            l_organization_rec.party_rec.party_id := p_derived_rec.party_id;
        end if;
        -- -------------------------- Location -------------------------- --
        log_msg('Creating Location');
        map_location_values(p_stage_row, p_derived_rec, l_location_rec);
        create_location(p_stage_row, l_location_rec, l_success);
        if not l_success then
            p_stage_row.interface_status := G_INT_STATUS_ERROR;
            rollback;
            return;
        else
            insert_debtor_audit(p_stage_row.stage_id, g_interface_type, 'N', 'Location');
        end if;
        -- ------------------------- Party Site ------------------------- --
        log_msg('Creating Party Site');
        l_party_site_rec.party_id     := l_organization_rec.party_rec.party_id;
        l_party_site_rec.location_id  := l_location_rec.location_id;
        create_party_site(p_stage_row, l_party_site_rec, l_success);
        if not l_success then
            p_stage_row.interface_status := G_INT_STATUS_ERROR;
            rollback;
            return;
        else
            insert_debtor_audit(p_stage_row.stage_id, g_interface_type, 'N', 'PartySite');
        end if;
        -- ------------------------ Cust Account ------------------------ --
        if p_derived_rec.cust_acct_id is null then
            log_msg('Creating Customer Account');
            map_cust_acct_values(p_stage_row, p_derived_rec, l_cust_acct_rec, l_organization_rec, l_cust_profile_rec);
            create_org_cust_account(p_stage_row, l_cust_acct_rec, l_organization_rec, l_cust_profile_rec, l_success);
            if not l_success then
                p_stage_row.interface_status := G_INT_STATUS_ERROR;
                rollback;
                return;
            else
                insert_debtor_audit(p_stage_row.stage_id, g_interface_type, 'N', 'CustAccount');
            end if;
        else
            -- this is when we're reusing an existing account
            l_cust_acct_rec.cust_account_id := p_derived_rec.cust_acct_id;
            map_cust_acct_values(p_stage_row, p_derived_rec, l_cust_acct_rec, l_organization_rec, l_cust_profile_rec);
        end if;
        -- ---------------------- Cust Account Site --------------------- --
        log_msg('Creating Customer Account Site');
        map_cust_acct_site_values(p_stage_row, p_derived_rec, l_cust_account_site_rec);
        l_cust_account_site_rec.cust_account_id := l_cust_acct_rec.cust_account_id;
        l_cust_account_site_rec.party_site_id   := l_party_site_rec.party_site_id;
        create_cust_acct_site(p_stage_row, l_cust_account_site_rec, l_success);
        if not l_success then
            p_stage_row.interface_status := G_INT_STATUS_ERROR;
            rollback;
            return;
        else
            insert_debtor_audit(p_stage_row.stage_id, g_interface_type, 'N', 'CustAccountSite');
        end if;
        -- -------------------- Cust Account Site Use ------------------- --
        log_msg('Creating Customer Account Site Use');
        l_cust_site_use_rec.cust_acct_site_id := l_cust_account_site_rec.cust_acct_site_id;
        map_cust_acct_site_use_values(p_stage_row, p_derived_rec, l_cust_site_use_rec);
        create_cust_acct_site_use(p_stage_row, l_cust_site_use_rec, l_cust_profile_rec, l_success);
        if not l_success then
            p_stage_row.interface_status := G_INT_STATUS_ERROR;
            rollback;
            return;
        else
            insert_debtor_audit(p_stage_row.stage_id, g_interface_type, 'N', 'CustAccountSiteUse');
        end if;

        -- update the stage table rows with the Oracle generated or derived values
        p_stage_row.account_number := nvl(l_cust_acct_rec.account_number, p_derived_rec.account_number);
        p_stage_row.cust_account_id := l_cust_acct_rec.cust_account_id;
        p_stage_row.party_site_number := nvl(l_party_site_rec.party_site_number, p_derived_rec.party_site_number);

        commit;
    exception
        when others then
            rollback;
            log_msg(sqlerrm, 'create_customer');
            raise;
    end create_customer;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      update_org_party
    --  Purpose
    --      Wrapper procedure to update a Party of type Organization
    --  Parameters
    --      p_stage_row         Stage table row
    --      p_organization_rec  API record for an organization
    --      p_success           Success flag [true|false]
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure update_org_party(
        p_stage_row         in out nocopy c_stage%rowtype,
        p_organization_rec  in out nocopy hz_party_v2pub.organization_rec_type,
        p_success           out boolean )
    is
        l_existing_org_rec      hz_party_v2pub.organization_rec_type;
        l_original_org_rec      hz_party_v2pub.organization_rec_type;
        l_return_status         varchar2(30);
        l_profile_id            number;
        l_obj_version           number;
        l_miss_char             varchar2(1) := fnd_api.g_miss_char;
        l_msg_count             number := 0;
        l_msg_data              varchar2(300);
        l_record_changed        boolean := false;
        l_value_changed         boolean := false;
    begin
        debug_msg('begin', 'update_org_party');
        p_success := true;
        -- query the existing organization
        hz_party_v2pub.get_organization_rec (
              p_init_msg_list         => FND_API.G_TRUE,
              p_party_id              => p_organization_rec.party_rec.party_id,
              p_content_source_type   => hz_party_v2pub.G_MISS_CONTENT_SOURCE_TYPE,
              x_organization_rec      => l_existing_org_rec,
              x_return_status         => l_return_status,
              x_msg_count             => l_msg_count,
              x_msg_data              => l_msg_data
        );

        if l_return_status <> FND_API.G_RET_STS_SUCCESS then
            -- this really should not get here because we have already queried the party_id.  included for completeness
            log_msg('Could not find the Organization party using party_id '||
                p_organization_rec.party_rec.party_id ||'.  Cannot perform update');
            return;
        end if;

        l_original_org_rec := l_existing_org_rec;

        -- Determine whether the new values differ from the existing
        -- If so, override the existing values with the new
        -- Organization Name --
        debug_msg('comparing organization name');
        compare_and_update_varchar(p_organization_rec.organization_name, l_existing_org_rec.organization_name, 'organization name', l_value_changed);
        if l_value_changed then
            l_record_changed := true;
            insert_debtor_audit(p_stage_row.stage_id, g_interface_type, 'U', 'Party', 'Party Name',
                l_original_org_rec.organization_name, l_existing_org_rec.organization_name);
        end if;

        -- call the update api only if dirty vales were found
        if l_record_changed then

            -- get object version number of the tca record
            select object_version_number into l_obj_version
             from hz_parties
             where party_id = p_organization_rec.party_rec.party_id;

            hz_party_v2pub.update_organization (
                  p_init_msg_list               => FND_API.G_TRUE,
                  p_organization_rec            => l_existing_org_rec,
                  p_party_object_version_number => l_obj_version,
                  x_profile_id                  => l_profile_id,
                  x_return_status               => l_return_status,
                  x_msg_count                   => l_msg_count,
                  x_msg_data                    => l_msg_data
            );

            log_msg('Update_Organization API Result:');
            if l_return_status = fnd_api.g_ret_sts_success then
                log_msg('   x_profile_id = ' || l_profile_id);
                log_msg('   obj_version = ' || l_obj_version);
                p_success := true;
            else
                log_msg('   Failed with ' || l_msg_count || ' error(s)');
                assign_api_errors(p_stage_row.stage_id, l_msg_count, l_msg_data);
                p_success := false;
            end if;
        else
            log_msg('Party has not changed');
        end if;

    exception
        when others then
            log_msg(sqlerrm, 'update_org_party');
            raise;
    end update_org_party;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      update_org_cust_account
    --  Purpose
    --      Wrapper procedure to update a Customer Account
    --  Parameters
    --      p_stage_row         Stage table row
    --      p_cust_acct_rec     API record for a Customer Account
    --      p_success           Success flag [true|false]
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure update_org_cust_account(
        p_stage_row         in out nocopy c_stage%rowtype,
        p_cust_acct_rec     in out nocopy hz_cust_account_v2pub.cust_account_rec_type,
        p_success           out boolean )
    is
        l_existing_acct_rec     hz_cust_account_v2pub.cust_account_rec_type;
        l_original_acct_rec     hz_cust_account_v2pub.cust_account_rec_type;
        l_existing_prof_rec     hz_customer_profile_v2pub.customer_profile_rec_type;
        l_obj_version           number;
        l_record_changed        boolean := false;
        l_value_changed         boolean := false;
        l_miss_char             varchar2(1) := fnd_api.g_miss_char;
        l_return_status         varchar2(30);
        l_msg_count             number := 0;
        l_msg_data              varchar2(300);
    begin
        debug_msg('begin', 'update_org_cust_account');
        p_success := true;
        -- query the existing organization account
        hz_cust_account_v2pub.get_cust_account_rec (
              p_init_msg_list         => FND_API.G_TRUE,
              p_cust_account_id       => p_cust_acct_rec.cust_account_id,
              x_cust_account_rec      => l_existing_acct_rec,
              x_customer_profile_rec  => l_existing_prof_rec,
              x_return_status         => l_return_status,
              x_msg_count             => l_msg_count,
              x_msg_data              => l_msg_data
        );

        if l_return_status <> FND_API.G_RET_STS_SUCCESS then
            -- this really should not get here because we have already queried the cust_account_id.  included for completeness
            log_msg('Could not find the Customer Account using cust_account_id '||
                p_cust_acct_rec.cust_account_id ||'.  Cannot perform update');
            assign_api_errors(p_stage_row.stage_id, l_msg_count, l_msg_data);
            return;
        end if;

        l_original_acct_rec := l_existing_acct_rec;

        -- Determine whether the new values differ from the existing
        -- If so, override the existing values with the new
        -- Account Name --
        debug_msg('comparing account name');
        compare_and_update_varchar(p_cust_acct_rec.account_name, l_existing_acct_rec.account_name, 'account name', l_value_changed);
        if l_value_changed then
            l_record_changed := true;
            insert_debtor_audit(p_stage_row.stage_id, g_interface_type, 'U', 'CustAccount', 'Account Name',
                format(l_original_acct_rec.account_name), format(l_existing_acct_rec.account_name));
        end if;

        -- RRAM Reference --
        -- TODO: Put this back once the DFFs are defined in DTPLI --
        /*
        debug_msg('comparing rram reference');
        compare_and_update_varchar(p_cust_acct_rec.attribute2, l_existing_acct_rec.attribute2, 'rram reference', l_value_changed);
        if l_value_changed then
            l_record_changed := true;
            insert_debtor_audit(p_stage_row.stage_id, g_interface_type, 'U', 'CustAccount', 'RRAM Reference',
                format(l_original_acct_rec.attribute2), format(l_existing_acct_rec.attribute2));
        end if;
        */

        -- call the update api only if dirty vales were found
        if l_record_changed then

            -- get object version number of the tca record
            select object_version_number into l_obj_version
             from hz_cust_accounts
             where cust_account_id = p_cust_acct_rec.cust_account_id;

            hz_cust_account_v2pub.update_cust_account (
                  p_init_msg_list               => FND_API.G_TRUE,
                  p_cust_account_rec            => l_existing_acct_rec,
                  p_object_version_number       => l_obj_version,
                  x_return_status               => l_return_status,
                  x_msg_count                   => l_msg_count,
                  x_msg_data                    => l_msg_data
            );

            log_msg('Update_Cust_Account API Result:');
            if l_return_status = fnd_api.g_ret_sts_success then
                log_msg('   obj_version = ' || l_obj_version);
                p_success := true;
            else
                log_msg('   Failed with ' || l_msg_count || ' error(s)');
                assign_api_errors(p_stage_row.stage_id, l_msg_count, l_msg_data);
                p_success := false;
            end if;
        else
            log_msg('Account has not changed');
        end if;

    exception
        when others then
            log_msg(sqlerrm, 'update_org_cust_account');
            raise;
    end update_org_cust_account;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      update_cust_acct_site
    --  Purpose
    --      Wrapper procedure to update a Customer Account
    --  Parameters
    --      p_stage_row                 Stage table row
    --      p_cust_account_site_rec     API record for a Customer Account Site
    --      p_success                   Success flag [true|false]
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure update_cust_acct_site(
        p_stage_row                 in out nocopy c_stage%rowtype,
        p_cust_account_site_rec     in out nocopy hz_cust_account_site_v2pub.cust_acct_site_rec_type,
        p_success                   out boolean )
    is
        l_existing_acct_site_rec    hz_cust_account_site_v2pub.cust_acct_site_rec_type;
        l_original_acct_site_rec    hz_cust_account_site_v2pub.cust_acct_site_rec_type;
        l_obj_version           number;
        l_record_changed        boolean := false;
        l_value_changed         boolean := false;
        l_miss_char             varchar2(1) := fnd_api.g_miss_char;
        l_return_status         varchar2(30);
        l_msg_count             number := 0;
        l_msg_data              varchar2(300);
    begin
        debug_msg('begin', 'update_cust_acct_site');
        p_success := true;
        -- query the existing account site
        hz_cust_account_site_v2pub.get_cust_acct_site_rec (
              p_init_msg_list         => FND_API.G_TRUE,
              p_cust_acct_site_id     => p_cust_account_site_rec.cust_acct_site_id,
              x_cust_acct_site_rec    => l_existing_acct_site_rec,
              x_return_status         => l_return_status,
              x_msg_count             => l_msg_count,
              x_msg_data              => l_msg_data
        );

        if l_return_status <> FND_API.G_RET_STS_SUCCESS then
            -- this really should not get here because we have already queried the cust_account_id.  included for completeness
            log_msg('Could not find the Customer Account Site using cust_acct_site_id '||
                p_cust_account_site_rec.cust_acct_site_id ||'.  Cannot perform update');
            return;
        end if;

        l_original_acct_site_rec := l_existing_acct_site_rec;

        -- Determine whether the new values differ from the existing
        -- If so, override the existing values with the new
        
        -- RRAMS Reference --
        -- TODO: Put this back once the DFFs are defined in DTPLI --
        /*
        debug_msg('comparing site rram reference');
        compare_and_update_varchar(p_cust_account_site_rec.attribute3, l_existing_acct_site_rec.attribute3, 'site rram reference', l_value_changed);
        if l_value_changed then
            l_record_changed := true;
            insert_debtor_audit(p_stage_row.stage_id, g_interface_type, 'U', 'CustAccountSite', 'RRAM Reference',
                format(l_original_acct_site_rec.attribute3), format(l_existing_acct_site_rec.attribute3));
        end if;
        */
        
        -- call the update api only if dirty vales were found
        if l_record_changed then

            -- get object version number of the tca record
            select object_version_number into l_obj_version
             from hz_cust_acct_sites_all
             where cust_acct_site_id = p_cust_account_site_rec.cust_acct_site_id;

            hz_cust_account_site_v2pub.update_cust_acct_site (
                  p_init_msg_list           => FND_API.G_TRUE,
                  p_cust_acct_site_rec      => l_existing_acct_site_rec,
                  p_object_version_number   => l_obj_version,
                  x_return_status           => l_return_status,
                  x_msg_count               => l_msg_count,
                  x_msg_data                => l_msg_data
            );

            log_msg('Update_Account_Site API Result:');
            if l_return_status = fnd_api.g_ret_sts_success then
                log_msg('   obj_version = ' || l_obj_version);
                p_success := true;
            else
                log_msg('   Failed with ' || l_msg_count || ' error(s)');
                assign_api_errors(p_stage_row.stage_id, l_msg_count, l_msg_data);
                p_success := false;
            end if;
        else
            log_msg('Account Site has not changed');
        end if;
    exception
        when others then
            log_msg(sqlerrm, 'update_cust_acct_site');
            raise;
    end update_cust_acct_site;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      update_location
    --  Purpose
    --      Wrapper procedure to update a Location
    --  Parameters
    --      p_stage_row           Stage table row
    --      p_location_rec        API record for a Location
    --      p_success             Success flag [true|false]
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure update_location(
        p_stage_row         in out nocopy c_stage%rowtype,
        p_location_rec      in out nocopy hz_location_v2pub.location_rec_type,
        p_success           out boolean )
    is
        l_existing_loc_rec      hz_location_v2pub.location_rec_type;
        l_original_loc_rec      hz_location_v2pub.location_rec_type;
        l_obj_version           number;
        l_return_status         varchar2(30);
        l_msg_count             number := 0;
        l_msg_data              varchar2(300);
        l_value_changed         boolean := false;
        l_record_changed        boolean := false;
        l_allow_change          varchar2(1);
    begin
        debug_msg('begin', 'update_location');
        p_success := true;
        -- query the existing location
        hz_location_v2pub.get_location_rec(
              p_init_msg_list         => FND_API.G_TRUE,
              p_location_id           => p_location_rec.location_id,
              x_location_rec          => l_existing_loc_rec,
              x_return_status         => l_return_status,
              x_msg_count             => l_msg_count,
              x_msg_data              => l_msg_data
        );

        if l_return_status <> FND_API.G_RET_STS_SUCCESS then
            log_msg('Could not find the Location using location_id '|| p_location_rec.location_id ||
                '.  Cannot perform update');
            p_success := false;
            return;
        end if;

        l_original_loc_rec := l_existing_loc_rec;

        -- Copy the new values to the existing if they differ.
        debug_msg('comparing address1');
        compare_and_update_varchar(p_location_rec.address1, l_existing_loc_rec.address1, 'address1', l_value_changed);
        if l_value_changed then
            l_record_changed := true;
            insert_debtor_audit(p_stage_row.stage_id, g_interface_type, 'U', 'Location', 'Address1',
                format(l_original_loc_rec.address1), format(l_existing_loc_rec.address1));
        end if;

        debug_msg('comparing address2');
        compare_and_update_varchar(p_location_rec.address2, l_existing_loc_rec.address2, 'address2', l_value_changed);
        if l_value_changed then
            l_record_changed := true;
            insert_debtor_audit(p_stage_row.stage_id, g_interface_type, 'U', 'Location', 'Address2',
                format(l_original_loc_rec.address2), format(l_existing_loc_rec.address2));
        end if;

        debug_msg('comparing address3');
        compare_and_update_varchar(p_location_rec.address3, l_existing_loc_rec.address3, 'address3', l_value_changed);
        if l_value_changed then
            l_record_changed := true;
            insert_debtor_audit(p_stage_row.stage_id, g_interface_type, 'U', 'Location', 'Address3',
                format(l_original_loc_rec.address3), format(l_existing_loc_rec.address3));
        end if;

        debug_msg('comparing city');
        compare_and_update_varchar(p_location_rec.city, l_existing_loc_rec.city, 'city', l_value_changed);
        if l_value_changed then
            l_record_changed := true;
            insert_debtor_audit(p_stage_row.stage_id, g_interface_type, 'U', 'Location', 'City',
                format(l_original_loc_rec.city), format(l_existing_loc_rec.city));
        end if;

        debug_msg('comparing state');
        compare_and_update_varchar(p_location_rec.state, l_existing_loc_rec.state, 'state', l_value_changed);
        if l_value_changed then
            l_record_changed := true;
            insert_debtor_audit(p_stage_row.stage_id, g_interface_type, 'U', 'Location', 'State',
                format(l_original_loc_rec.state), format(l_existing_loc_rec.state));
        end if;

        debug_msg('comparing post code');
        compare_and_update_varchar(p_location_rec.postal_code, l_existing_loc_rec.postal_code, 'post code', l_value_changed);
        if l_value_changed then
            l_record_changed := true;
            insert_debtor_audit(p_stage_row.stage_id, g_interface_type, 'U', 'Location', 'Post Code',
                format(l_original_loc_rec.postal_code), format(l_existing_loc_rec.postal_code));
        end if;

        debug_msg('comparing country');
        compare_and_update_varchar(p_location_rec.country, l_existing_loc_rec.country, 'Country', l_value_changed);
        if l_value_changed then
            l_record_changed := true;
            insert_debtor_audit(p_stage_row.stage_id, g_interface_type, 'U', 'Location', 'Post Code',
                format(l_original_loc_rec.country), format(l_existing_loc_rec.country));
        end if;

        -- call the update api only if one or more vales were changed
        if l_record_changed then

            -- get object version number of the tca record
            select object_version_number into l_obj_version
             from hz_locations
             where location_id = p_location_rec.location_id;

            -- check the system option 'Allow Change to Printed Transactions'
            -- if its 'N' then change it to 'Y' to avoid error ARP-AR-294464
            l_allow_change := get_allow_change_option;
            if l_allow_change = 'N' then
                set_allow_change_option('Y');
            end if;

            hz_location_v2pub.update_location (
                p_init_msg_list         => FND_API.G_TRUE,
                p_location_rec          => l_existing_loc_rec,
                p_object_version_number => l_obj_version,
                x_return_status         => l_return_status,
                x_msg_count             => l_msg_count,
                x_msg_data              => l_msg_data
            );

            log_msg('Update_Location API Result:');
            if l_return_status = fnd_api.g_ret_sts_success then
                log_msg('   obj_version = ' || l_obj_version);
                p_success := true;
            else
                log_msg('   Failed with ' || l_msg_count || ' error(s)');
                assign_api_errors(p_stage_row.stage_id, l_msg_count, l_msg_data);
                p_success := false;
            end if;
            -- change system option back to what is was originally
            set_allow_change_option(l_allow_change);
        else
            log_msg('Address has not changed.');
        end if;

    exception
        when others then
            log_msg(sqlerrm, 'update_location');
            raise;
    end update_location;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      update_acct_site_use
    --  Purpose
    --      Wrapper procedure to update an Account Site Usage (Bill-To)
    --  Parameters
    --      p_stage_row           Stage table row
    --      p_cust_site_use_rec   API record for a Customer Account Site Usage
    --      p_success             Success flag [true|false]
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure update_acct_site_use(
        p_stage_row                 in out nocopy c_stage%rowtype,
        p_cust_site_use_rec         in out nocopy hz_cust_account_site_v2pub.cust_site_use_rec_type,
        p_success                   out boolean )
    is
        l_existing_site_use_rec     hz_cust_account_site_v2pub.cust_site_use_rec_type;
        l_original_site_use_rec     hz_cust_account_site_v2pub.cust_site_use_rec_type;
        l_existing_profile_rec      hz_customer_profile_v2pub.customer_profile_rec_type;
        l_obj_version               number;
        l_record_changed            boolean := false;
        l_value_changed             boolean := false;
        l_miss_char                 varchar2(1) := fnd_api.g_miss_char;
        l_return_status             varchar2(30);
        l_msg_count                 number := 0;
        l_msg_data                  varchar2(300);
    begin
        debug_msg('begin', 'update_acct_site_use');
        p_success := true;
        -- query the existing account site use
        hz_cust_account_site_v2pub.get_cust_site_use_rec(
              p_init_msg_list         => FND_API.G_TRUE,
              p_site_use_id           => p_cust_site_use_rec.site_use_id,
              x_cust_site_use_rec     => l_existing_site_use_rec,
              x_customer_profile_rec  => l_existing_profile_rec,
              x_return_status         => l_return_status,
              x_msg_count             => l_msg_count,
              x_msg_data              => l_msg_data
        );

        if l_return_status <> FND_API.G_RET_STS_SUCCESS then
            log_msg('Could not find the Account Site Usage using cust_acct_site_id '|| p_cust_site_use_rec.site_use_id ||
                '.  Cannot perform update');
            assign_api_errors(p_stage_row.stage_id, l_msg_count, l_msg_data);
            p_success := false;
            return;
        end if;

        l_original_site_use_rec := l_existing_site_use_rec;

        -- Copy the new values to the existing if they differ.
        debug_msg('comparing tax reference');
        compare_and_update_varchar(p_cust_site_use_rec.tax_reference,l_existing_site_use_rec.tax_reference, 'tax reference', l_value_changed);
        if l_value_changed then
            l_record_changed := true;
            insert_debtor_audit(p_stage_row.stage_id, g_interface_type, 'U', 'CustAccountSiteUse', 'Tax Registration',
                format(l_original_site_use_rec.tax_reference), format(l_existing_site_use_rec.tax_reference));
        end if;

        if l_record_changed then

            -- get object version number of the tca record
            select object_version_number into l_obj_version
             from hz_cust_site_uses
             where site_use_id = l_existing_site_use_rec.site_use_id;

            hz_cust_account_site_v2pub.update_cust_site_use (
                p_init_msg_list         => FND_API.G_TRUE,
                p_cust_site_use_rec     => l_existing_site_use_rec,
                p_object_version_number => l_obj_version,
                x_return_status         => l_return_status,
                x_msg_count             => l_msg_count,
                x_msg_data              => l_msg_data
            );

            log_msg('Update_Site_Use API Result:');
            if l_return_status = fnd_api.g_ret_sts_success then
                log_msg('   obj_version = ' || l_obj_version);
                p_success := true;
            else
                log_msg('   Failed with ' || l_msg_count || ' error(s)');
                assign_api_errors(p_stage_row.stage_id, l_msg_count, l_msg_data);
                p_success := false;
            end if;
        else
            log_msg('Site Use has not changed.');
        end if;
    exception
        when others then
            log_msg(sqlerrm, 'update_acct_site_use');
            raise;
    end update_acct_site_use;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      update_customer
    --  Purpose
    --      Main logic to update a single customer
    --      Encapsulates the calling of receivables APIs to update a single customer
    --      processing.
    --  Parameters
    --      p_stage_row         Stage table row with new values
    --      p_derived_rec       Derived or looked up values
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    --  sryan       24/04/2015	added cust_acct_site_id value to l_cust_site_use_rec 
    -- ------------------------------------------------------------------------
    procedure update_customer(
        p_stage_row         in out nocopy c_stage%rowtype,
        p_derived_rec       in out nocopy t_derived_rec
        )
    is
        pragma autonomous_transaction;
        l_organization_rec        hz_party_v2pub.organization_rec_type;
        l_cust_acct_rec           hz_cust_account_v2pub.cust_account_rec_type;
        l_cust_profile_rec        hz_customer_profile_v2pub.customer_profile_rec_type;
        l_cust_account_site_rec   hz_cust_account_site_v2pub.cust_acct_site_rec_type;
        l_location_rec            hz_location_v2pub.location_rec_type;
        l_cust_site_use_rec       hz_cust_account_site_v2pub.cust_site_use_rec_type;
        l_success                 boolean := true;
    begin
        debug_msg('begin','update_customer');
        -- ----------------------- Update Party ------------------------- --
        map_org_party_values(p_stage_row, p_derived_rec, l_organization_rec);
        --log_msg('Updating Party');
        update_org_party(p_stage_row, l_organization_rec, l_success);
        if not l_success then
            rollback;
            p_stage_row.interface_status := G_INT_STATUS_ERROR;
            return;
        end if;
        -- ---------------------- Update Account ------------------------ --
        map_cust_acct_values(p_stage_row, p_derived_rec, l_cust_acct_rec, l_organization_rec, l_cust_profile_rec);
        --log_msg('Updating Customer Account');
        update_org_cust_account(p_stage_row, l_cust_acct_rec, l_success);
        if not l_success then
            rollback;
            p_stage_row.interface_status := G_INT_STATUS_ERROR;
            return;
        end if;
        -- ------------------- Update Account Site ---------------------- --
        map_cust_acct_site_values(p_stage_row, p_derived_rec, l_cust_account_site_rec);
        if p_derived_rec.cust_acct_site_id is not null then
            --log_msg('Updating Customer Account Site');
            update_cust_acct_site(p_stage_row, l_cust_account_site_rec, l_success);
        else
            debug_msg('creating the remainder of the debtor');
            create_customer(p_stage_row, p_derived_rec);
            commit;
            return;
        end if;
        if not l_success then
            rollback;
            p_stage_row.interface_status := G_INT_STATUS_ERROR;
            return;
        end if;
        -- --------------------- Update Location ------------------------ --
        map_location_values(p_stage_row, p_derived_rec, l_location_rec);
        --log_msg('Updating Location');
        update_location(p_stage_row, l_location_rec, l_success);
        if not l_success then
            rollback;
            p_stage_row.interface_status := G_INT_STATUS_ERROR;
            return;
        end if;
        -- ----------------- Update Account Site Usage ------------------- --
        l_cust_site_use_rec.cust_acct_site_id := l_cust_account_site_rec.cust_acct_site_id; --SR
        map_cust_acct_site_use_values(p_stage_row, p_derived_rec, l_cust_site_use_rec);
        if p_derived_rec.site_use_id is not null then
            --log_msg('Updating Site Use');
            update_acct_site_use(p_stage_row, l_cust_site_use_rec, l_success);
        else
            -- the site use was never found so create a new site use
            l_cust_site_use_rec.cust_acct_site_id := l_cust_account_site_rec.cust_acct_site_id;
            map_cust_acct_site_use_values(p_stage_row, p_derived_rec, l_cust_site_use_rec);
            create_cust_acct_site_use(p_stage_row, l_cust_site_use_rec, l_cust_profile_rec, l_success);
            insert_debtor_audit(p_stage_row.stage_id, g_interface_type, 'N', 'CustAccountSiteUse');
        end if;
        if not l_success then
            rollback;
            p_stage_row.interface_status := G_INT_STATUS_ERROR;
            return;
        end if;

        p_stage_row.account_number := p_derived_rec.account_number;
        p_stage_row.cust_account_id := p_derived_rec.cust_acct_id;
        p_stage_row.party_site_number := p_derived_rec.party_site_number;

        commit;
    exception
        when others then
            log_msg(sqlerrm, 'update_customer');
            raise;
    end update_customer;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      process_batch
    --  Purpose
    --      Processes a batch of stage table rows
    --  Parameters
    --      p_stage_tbl   Stage table collection of a batch of g_max_fetch
    --                    stage table rows
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure process_batch(p_stage_tbl in out nocopy t_stage_tbl)
    is
        l_derived_tbl         t_derived_tbl;
    begin
        debug_msg('begin','process_batch');
        for i in p_stage_tbl.first..p_stage_tbl.last
        loop
            log_msg('StageId['|| p_stage_tbl(i).stage_id ||'] SourceSystemRef='|| p_stage_tbl(i).source_system_ref);
            -- initialize derived stable
            l_derived_tbl(i).stage_id := p_stage_tbl(i).stage_id;

            -- validate (includes looking up customer)
            log_msg('Validating fields');
            validate_stage_row_columns(p_stage_tbl, l_derived_tbl, i);
            if p_stage_tbl(i).interface_status = G_INT_STATUS_ERROR then
                continue;
            end if;
            log_msg('All valid');

            -- determine action to take
            if l_derived_tbl(i).party_id is null then
                create_customer(p_stage_tbl(i), l_derived_tbl(i));
            else
                update_customer(p_stage_tbl(i), l_derived_tbl(i));
            end if;

            -- mark row as successfully processed
            if p_stage_tbl(i).interface_status = G_INT_STATUS_NEW then
                p_stage_tbl(i).interface_status := G_INT_STATUS_PROCESSED;
            end if;
            log_msg('');
        end loop;
    exception
        when others then
            log_msg(sqlerrm, 'process_batch');
            raise;
    end process_batch;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      import_debtors
    --  Purpose
    --      Implements the main logic of the debtor interface
    --  Parameters
    --      p_debug       Debug flag (Y|N) to output additional flow information
    --      p_errors      Boolean flag to indicate existence of errors
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure import_debtors(
        p_debug         in varchar2 default 'N',
        p_errors        out boolean)
    is
        l_stage_tbl         t_stage_tbl;
        l_errors_found      boolean := false;
        l_count             number := 0;
        l_redundant_count   number := 0;
    begin
        -- initialise and validate session
        initialise(p_debug);
        debug_msg('begin','import_debtors');

        -- read stage table rows and process in batches of g_max_fetch
        open  c_stage(G_INT_STATUS_NEW);
        loop
            fetch c_stage bulk collect into l_stage_tbl limit g_max_fetch;
            exit when l_stage_tbl.count = 0;
            l_count := l_count + l_stage_tbl.count;
            process_batch(l_stage_tbl);
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
            -- Most of the rows are not actually required because Actian populates the debtors table with data
            -- for every new/updated financial transaction, regardless of whether the debtor itself was modified
            -- in Salesforce.  Delete these redundant rows.
            delete_redundant_rows(l_redundant_count);
            log_msg('Deleted ' || l_redundant_count || ' redundant debtor stage rows');
        else
            log_msg('No rows to process');
        end if;

        p_errors := l_errors_found;
        debug_msg('import_debtors -> end');
    exception
        when ex_invalid_apps_session then
            log_msg('No Applications session.  Run fnd_global.apps_initialize');
        when others then
            if c_stage%isopen then
                close c_stage;
            end if;
            log_msg(sqlerrm, 'import_debtors');
            raise;
    end import_debtors;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      import_debtors_cp
    --  Purpose
    --      Concurrent program wrapper to call procedure import_debtors
    --      This program implements concurrent program RRAM_IMPORT_DEBTORS
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
    procedure import_debtors_cp(
        p_errbuf	            out varchar2,
      	p_retcode	            out number,
        p_debug               in varchar2 default 'N')
    is
        l_debtor_errors_found   boolean := false;
        l_site_errors_found     boolean := false;
    begin
        import_debtors(p_debug, l_debtor_errors_found);
        log_msg('+--------------------------------------- Debtor Site Interface ----------------------------------------+');
        rram_debtor_site_pkg.import_debtor_sites(p_debug, l_site_errors_found);
        audit_report(g_conc_request_id);
        error_report(g_conc_request_id);
        --
        if l_debtor_errors_found or l_site_errors_found then
            p_retcode := 1;
        else
            p_retcode := 0;
        end if;
    exception
        when others then
            p_errbuf := sqlerrm;
            p_retcode := 2;
    end import_debtors_cp;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      submit_import_debtors
    --  Purpose
    --      Program wrapper to submit the RRAM Import Debtors concurrent
    --      program (RRAM_IMPORT_DEBTORS)
    --  Parameters
    --      p_user            User name from fnd_user
    --      p_resp_id         Responsibility Id
    --      p_resp_appl_id    Responsibility Application Id
    --      p_debug           Debug flag (Y|N) to output additional flow information to
    --                        the log file
    --      p_request_id      The concurrent request id of the submitted job
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure submit_import_debtors(
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

          -- submit the request
            l_request_id :=
                fnd_request.submit_request(
                    'ARC'          -- Application Short Name
                  , 'RRAM_IMPORT_DEBTORS'  -- Program Short Name
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
            log_msg(sqlerrm, 'submit_import_debtors');
            raise;
    end;

    -- ------------------------------------------------------------------------
    --  Procedure
    --      submit_import_debtors (overloaded)
    --  Purpose
    --      Program wrapper to submit the RRAM Import Debtors concurrent
    --      program (RRAM_IMPORT_DEBTORS)
    --      This is an overloaded procedure that does not return the concurrent
    --      request id
    --  Parameters
    --      p_user            User name from fnd_user
    --      p_resp_id         Responsibility Id
    --      p_resp_appl_id    Responsibility Application Id
    --      p_debug           Debug flag (Y|N) to output additional flow information to
    --                        the log file
    --  Author      Date		    Comment
    --  ----------  ----------  -----------------------------------------------
    --  sryan       13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure submit_import_debtors(
        p_user	              in varchar2,
      	p_resp_id	            in number,
      	p_resp_appl_id        in number,
        p_debug               in varchar2 default 'N')
    is
        l_request_id        number;
    begin
        submit_import_debtors(p_user, p_resp_id, p_resp_appl_id, p_debug, l_request_id);
    exception
        when others then
            log_msg(sqlerrm, 'submit_import_debtors(overloaded)');
            raise;
    end submit_import_debtors;

end rram_debtor_pkg;
/
