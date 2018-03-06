create or replace
package body arc_event_pkg
is
/* $Header: svn://d02584/consolrepos/branches/AR.09.03/arc/1.0.0/install/sql/ARC_EVENT_PKB.pls 1584 2017-07-07 04:15:10Z sryan $ */
    g_subscr_logging	    boolean := true;

    -- ------------------------------------------------------------------------
    --	Procedure
    --	    subscr_log
    --	Purpose
    --	    Logs subscription activity for troubleshooting purposes into
    --	    custom table rram_subscription_log
    --	    Variable g_subscr_logging must be set to true
    --	Parameters
    --	    p_mesesage		    Message to log
    --	Author	    Date	Comment
    --	----------  ----------	-----------------------------------------------
    --	sryan	    13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure subscr_log(p_message in varchar2)
    is
	pragma autonomous_transaction;
    begin
	if g_subscr_logging then
	    insert into rram_subscription_log(seq_id, message, tstamp)
	      values (rram_subscription_log_s1.nextval, substr(p_message,1,238), sysdate);
	end if;
	commit;
    exception
	when others then
	    rollback;
    end;

    -- ------------------------------------------------------------------------
    --	Function
    --	    cashapp_apply_rule
    --	Purpose
    --	    Workflow Event Subscription Rule function
    --	    Event: oracle.apps.ar.applications.CashApp.apply
    --	    This function updates the status of the RRAM Invoice Status table
    --	    after a receipt application.
    --	Parameters
    --	    p_subscription_guid     Unique subscription identifier
    --	    p_event		    Event message
    --	Returns
    --	    Status [SUCCESS|WARNING|ERROR]
    --	Author	    Date	Comment
    --	----------  ----------	-----------------------------------------------
    --	sryan	    13/01/2015	initial
    -- ------------------------------------------------------------------------
    function cashapp_apply_rule(p_subscription_guid in raw, p_event in out wf_event_t ) return varchar2
    is
	cursor c_cash_app(p_receivable_application_id in number) is
	    select rct.customer_trx_id
		 , rct.trx_number
		 , rctt.name as trx_type
		 , aps.amount_due_original
		 , aps.amount_applied
		 , aps.amount_credited
		 , aps.amount_adjusted
		 , aps.amount_due_remaining
	    from ar_receivable_applications ara
	       , ar_payment_schedules aps
	       , ra_customer_trx rct
	       , ra_cust_trx_types rctt
	    where ara.receivable_application_id = p_receivable_application_id
	      and aps.customer_trx_id = ara.applied_customer_trx_id
	      and rct.customer_trx_id = ara.applied_customer_trx_id
	      and rctt.cust_trx_type_id = rct.cust_trx_type_id
	      and rctt.name like '%RRAM%';

	l_rec_appl_id	    number;
	l_user_id	    number;
	r_cash_app	    c_cash_app%rowtype;
	l_status	    varchar2(10);

    begin
	--wf_log_pkg.init(1, null, wf_log_pkg.LEVEL_STATEMENT);
	--if wf_log_pkg.test(wf_log_pkg.LEVEL_STATEMENT, 'cashapp_apply_rule') then
	--    subscr_log('log level is working');
	--    wf_log_pkg.string(wf_log_pkg.LEVEL_STATEMENT, 'cashapp_apply_rule', '** BEGIN cashapp_apply_rule');
	--else
	--    subscr_log('log level is NOT working');
	--end if;

	l_rec_appl_id := wf_event.getValueForParameter('RECEIVABLE_APPLICATION_ID', p_event.getParameterList);
	l_user_id     := wf_event.getValueForParameter('USER_ID', p_event.getParameterList);

	subscr_log('cashapp_apply_rule: ' || 'l_rec_appl_id=' || l_rec_appl_id || '; ' || 'l_user_id='|| l_user_id);

	open c_cash_app(l_rec_appl_id);
	fetch c_cash_app into r_cash_app;
	if c_cash_app%notfound then
	    -- nothing to do
	    subscr_log('No record found');
	    l_status := 'SUCCESS';
	else
	    update rram_invoice_status
	       set last_update_date = sysdate
		 , last_updated_by = l_user_id
		 , amount_applied = r_cash_app.amount_applied
		 , amount_credited = r_cash_app.amount_credited
		 , amount_adjusted = r_cash_app.amount_adjusted
		 , amount_due_remaining = r_cash_app.amount_due_remaining
	     where invoice_id = r_cash_app.customer_trx_id;
	    --subscr_log('found '||sql%rowcount||' record');
	    l_status := 'SUCCESS';
	end if;
	close c_cash_app;
	return l_status;
    exception
	when others then
	    if c_cash_app%isopen then
		close c_cash_app;
	    end if;
	    subscr_log('error: '||sqlerrm);
	    wf_core.context('arc_event_pkg','cashapp_apply_rule', p_event.getEventName, p_subscription_guid);
	    wf_event.setErrorInfo(p_event, 'ERROR');
	    return 'ERROR';
    end cashapp_apply_rule;

    -- ------------------------------------------------------------------------
    --	Function
    --	    cashapp_unapply_rule
    --	Purpose
    --	    Workflow Event Subscription Rule function
    --	    Event: oracle.apps.ar.applications.CashApp.unapply
    --	    This function updates the status of the RRAM Invoice Status table
    --	    after a receipt application has been unapplied.
    --	Parameters
    --	    p_subscription_guid     Unique subscription identifier
    --	    p_event		    Event message
    --	Returns
    --	    Status [SUCCESS|WARNING|ERROR]
    --	Author	    Date	Comment
    --	----------  ----------	-----------------------------------------------
    --	sryan	    13/01/2015	initial
    -- ------------------------------------------------------------------------
    function cashapp_unapply_rule(p_subscription_guid in raw, p_event in out wf_event_t ) return varchar2
    is
	cursor c_cash_app(p_receivable_application_id in number) is
	    select rct.customer_trx_id
		 , rct.trx_number
		 , rctt.name as trx_type
		 , aps.amount_due_original
		 , aps.amount_applied
		 , aps.amount_credited
		 , aps.amount_adjusted
		 , aps.amount_due_remaining
	    from ar_receivable_applications ara
	       , ar_payment_schedules aps
	       , ra_customer_trx rct
	       , ra_cust_trx_types rctt
	    where ara.receivable_application_id = p_receivable_application_id
	      and aps.customer_trx_id = ara.applied_customer_trx_id
	      and rct.customer_trx_id = ara.applied_customer_trx_id
	      and rctt.cust_trx_type_id = rct.cust_trx_type_id
	      and rctt.name like '%RRAM%';

	l_rec_appl_id	    number;
	l_user_id	    number;
	r_cash_app	    c_cash_app%rowtype;
	l_status	    varchar2(10);

    begin
	l_rec_appl_id := wf_event.getValueForParameter('RECEIVABLE_APPLICATION_ID', p_event.getParameterList);
	l_user_id     := wf_event.getValueForParameter('USER_ID', p_event.getParameterList);

	subscr_log('cashapp_unapply_rule: ' || 'l_rec_appl_id=' || l_rec_appl_id || '; ' || 'l_user_id='|| l_user_id);

	open c_cash_app(l_rec_appl_id);
	fetch c_cash_app into r_cash_app;
	if c_cash_app%notfound then
	    -- nothing to do
	    subscr_log('No record found');
	    l_status := 'SUCCESS';
	else
	    update rram_invoice_status
	       set last_update_date = sysdate
		 , last_updated_by = l_user_id
		 , amount_applied = r_cash_app.amount_applied
		 , amount_credited = r_cash_app.amount_credited
		 , amount_adjusted = r_cash_app.amount_adjusted
		 , amount_due_remaining = r_cash_app.amount_due_remaining
	     where invoice_id = r_cash_app.customer_trx_id;
	    --subscr_log('found '||sql%rowcount||' record');
	    l_status := 'SUCCESS';
	end if;
	close c_cash_app;
	return l_status;
    exception
	when others then
	    if c_cash_app%isopen then
		close c_cash_app;
	    end if;
	    subscr_log('error: '||sqlerrm);
	    wf_core.context('arc_event_pkg','cashapp_unapply_rule', p_event.getEventName, p_subscription_guid);
	    wf_event.setErrorInfo(p_event, 'ERROR');
	    return 'ERROR';
    end cashapp_unapply_rule;

    -- ------------------------------------------------------------------------
    --	Function
    --	    credit_memo_complete_rule
    --	Purpose
    --	    Workflow Event Subscription Rule function
    --	    Event: oracle.apps.ar.transaction.CreditMemo.complete
    --	    This function updates the status of the RRAM Invoice Status table
    --	    after a completed credit memo is applied to a RRAM transaction.
    --	Parameters
    --	    p_subscription_guid     Unique subscription identifier
    --	    p_event		    Event message
    --	Returns
    --	    Status [SUCCESS|WARNING|ERROR]
    --	Author	    Date		    Comment
    --	----------  ----------	-----------------------------------------------
    --	sryan	    13/01/2015	initial
    -- ------------------------------------------------------------------------
    function credit_memo_complete_rule(p_subscription_guid in raw, p_event in out wf_event_t ) return varchar2
    is
	cursor c_cm_complete(p_customer_trx_id in number) is
	    select rct_inv.customer_trx_id
		 , rct_inv.trx_number
		 , rctt.name as trx_type
		 , aps.amount_due_original
		 , aps.amount_applied
		 , aps.amount_credited
		 , aps.amount_adjusted
		 , aps.amount_due_remaining
	    from ra_customer_trx rct
	       , ar_receivable_applications ara
	       , ar_payment_schedules aps
	       , ra_customer_trx rct_inv
	       , ra_cust_trx_types rctt
	    where rct.customer_trx_id = p_customer_trx_id
	    and ara.customer_trx_id = rct.customer_trx_id
	    and ara.applied_customer_trx_id = rct.previous_customer_trx_id
	    and ara.applied_payment_schedule_id = aps.payment_schedule_id
	    and rct_inv.customer_trx_id = ara.applied_customer_trx_id
	    and rctt.cust_trx_type_id = rct_inv.cust_trx_type_id
	    and rctt.name like '%RRAM%';

	l_customer_trx_id   number;
	l_user_id	    number;
	r_cm_complete	    c_cm_complete%rowtype;
	l_status	    varchar2(10);

    begin
	l_customer_trx_id := wf_event.getValueForParameter('CUSTOMER_TRX_ID', p_event.getParameterList);
	l_user_id	  := wf_event.getValueForParameter('USER_ID', p_event.getParameterList);

	subscr_log('credit_memo_complete_rule: ' || 'l_customer_trx_id=' || l_customer_trx_id || '; ' || 'l_user_id='|| l_user_id);

	open c_cm_complete(l_customer_trx_id);
	fetch c_cm_complete into r_cm_complete;
	if c_cm_complete%notfound then
	    -- nothing to do
	    subscr_log('No record found');
	    l_status := 'SUCCESS';
	else
	    update rram_invoice_status
	       set last_update_date = sysdate
		 , last_updated_by = l_user_id
		 , amount_applied = r_cm_complete.amount_applied
		 , amount_credited = r_cm_complete.amount_credited
		 , amount_adjusted = r_cm_complete.amount_adjusted
		 , amount_due_remaining = r_cm_complete.amount_due_remaining
	     where invoice_id = r_cm_complete.customer_trx_id;
	    --subscr_log('found '||sql%rowcount||' record');
	    l_status := 'SUCCESS';
	end if;
	close c_cm_complete;
	return l_status;
    exception
	when others then
	    if c_cm_complete%isopen then
		close c_cm_complete;
	    end if;
	    subscr_log('error: '||sqlerrm);
	    wf_core.context('arc_event_pkg','credit_memo_complete_rule', p_event.getEventName, p_subscription_guid);
	    wf_event.setErrorInfo(p_event, 'ERROR');
	    return 'ERROR';
    end credit_memo_complete_rule;

    -- ------------------------------------------------------------------------
    --	Function
    --	    credit_memo_incomplete_rule
    --	Purpose
    --	    Workflow Event Subscription Rule function
    --	    Event: oracle.apps.ar.transaction.CreditMemo.incomplete
    --	    This function updates the status of the RRAM Invoice Status table
    --	    after a credit memo is incompleted from a RRAM transaction.
    --	Parameters
    --	    p_subscription_guid     Unique subscription identifier
    --	    p_event		    Event message
    --	Returns
    --	    Status [SUCCESS|WARNING|ERROR]
    --	Author	    Date		    Comment
    --	----------  ----------	-----------------------------------------------
    --	sryan	    13/01/2015	initial
    -- ------------------------------------------------------------------------
    function credit_memo_incomplete_rule(p_subscription_guid in raw, p_event in out wf_event_t ) return varchar2
    is
	cursor c_cm_incomplete(p_customer_trx_id in number) is
	    select rct_inv.customer_trx_id
		 , rct_inv.trx_number
		 , rctt.name as trx_type
		 , aps.amount_due_original
		 , aps.amount_applied
		 , aps.amount_credited
		 , aps.amount_adjusted
		 , aps.amount_due_remaining
	    from ar_payment_schedules aps
	       , ra_customer_trx rct_inv
	       , ra_cust_trx_types rctt
	    where rct_inv.customer_trx_id = p_customer_trx_id
	    and aps.customer_trx_id = rct_inv.customer_trx_id
	    and rctt.cust_trx_type_id = rct_inv.cust_trx_type_id
	    and rctt.name like '%RRAM%';

	l_prev_trx_id	    number;
	l_user_id	    number;
	r_cm_complete	    c_cm_incomplete%rowtype;
	l_status	    varchar2(10);

    begin
	l_prev_trx_id	  := wf_event.getValueForParameter('PREV_TRX_ID', p_event.getParameterList);
	l_user_id	  := wf_event.getValueForParameter('USER_ID', p_event.getParameterList);

	subscr_log('credit_memo_incomplete_rule: ' || 'l_prev_trx_id=' || l_prev_trx_id || '; ' || 'l_user_id='|| l_user_id);

	open c_cm_incomplete(l_prev_trx_id);
	fetch c_cm_incomplete into r_cm_complete;
	if c_cm_incomplete%notfound then
	    -- nothing to do
	    subscr_log('No record found');
	    l_status := 'SUCCESS';
	else
	    update rram_invoice_status
	       set last_update_date = sysdate
		 , last_updated_by = l_user_id
		 , amount_applied = r_cm_complete.amount_applied
		 , amount_credited = r_cm_complete.amount_credited
		 , amount_adjusted = r_cm_complete.amount_adjusted
		 , amount_due_remaining = r_cm_complete.amount_due_remaining
	     where invoice_id = r_cm_complete.customer_trx_id;
	    --subscr_log('found '||sql%rowcount||' record');
	    l_status := 'SUCCESS';
	end if;
	close c_cm_incomplete;
	return l_status;
    exception
	when others then
	    if c_cm_incomplete%isopen then
		close c_cm_incomplete;
	    end if;
	    subscr_log('error: '||sqlerrm);
	    wf_core.context('arc_event_pkg','credit_memo_incomplete_rule', p_event.getEventName, p_subscription_guid);
	    wf_event.setErrorInfo(p_event, 'ERROR');
	    return 'ERROR';
    end credit_memo_incomplete_rule;

end arc_event_pkg;
/
