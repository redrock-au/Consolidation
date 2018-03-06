create or replace
package arc_event_pkg
as
/* $Header: svn://d02584/consolrepos/branches/AP.02.03/arc/1.0.0/install/sql/ARC_EVENT_PKS.pls 1442 2017-07-04 22:35:02Z svnuser $ */
    -- ------------------------------------------------------------------------
    --	Function
    --	    cashapp_apply_rule
    --	Purpose
    --	    Workflow Event Subscription Rule function
    --	    Event: oracle.apps.ar.application.CashApp.apply
    --	    This function updates the status of the RRAM Invoice Status table
    --	    after a receipt application.
    --	Parameters
    --	    p_subscription_guid     Unique subscription identifier
    --	    p_event		    Event message
    --	Returns
    --	    Status [SUCCESS|WARNING|ERROR]
    --	Author	    Date		    Comment
    --	----------  ----------	-----------------------------------------------
    --	sryan	    13/01/2015	initial
    -- ------------------------------------------------------------------------
    function cashapp_apply_rule(p_subscription_guid in raw, p_event in out wf_event_t ) return varchar2;

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
    --	Author	    Date		    Comment
    --	----------  ----------	-----------------------------------------------
    --	sryan	    13/01/2015	initial
    -- ------------------------------------------------------------------------
    function cashapp_unapply_rule(p_subscription_guid in raw, p_event in out wf_event_t ) return varchar2;

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
    function credit_memo_complete_rule(p_subscription_guid in raw, p_event in out wf_event_t ) return varchar2;

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
    function credit_memo_incomplete_rule(p_subscription_guid in raw, p_event in out wf_event_t ) return varchar2;
end;
/
show error
