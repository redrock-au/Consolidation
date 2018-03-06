create or replace package rram_ar_trans_pkg
as
/* $Header: svn://d02584/consolrepos/branches/AR.03.01/arc/1.0.0/install/sql/RRAM_AR_TRANS_PKS.pls 1706 2017-07-12 04:37:42Z svnuser $ */
-- ============================================================================
--
--  PROGRAM:	  RRAM_AR_TRANS_PKS.pls
--
--  DESCRIPTION:
--	Creates package spec rram_ar_trans_pkg.
--		  This package implements the Oracle side of the RRAM Invoice Interface.
--
--  AUTHOR	DATE		    COMMENT
--  ----------- ----------  ----------------------------------------------------
--  sryan	13/01/2015	initial
--  khoh  16/07/2015  added a new global constant 'D'
-- ============================================================================

    -- Global constants
    G_INT_STATUS_NEW		      constant varchar2(1) := 'N';
    G_INT_STATUS_PROCESSED	  constant varchar2(1) := 'P';
    G_INT_STATUS_ERROR		    constant varchar2(1) := 'E';
    G_INT_STATUS_DUPLICATE    constant varchar2(1) := 'D';  -- Added by khoh on 16/07/2015

    -- ------------------------------------------------------------------------
    --	Procedure
    --	    import_trans
    --	Purpose
    --	    Implements the main logic of the invoice interface
    --	Parameters
    --	    p_debug	  Debug flag (Y|N) to output additional flow information
    --	    p_errors	  Boolean flag to indicate existence of errors
    --	Author	    Date		    Comment
    --	----------  ----------	-----------------------------------------------
    --	sryan	    13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure import_trans(
	p_debug 	in varchar2 default 'N',
	p_errors	out boolean);

    -- ------------------------------------------------------------------------
    --	Procedure
    --	    import_trans_cp
    --	Purpose
    --	    Concurrent program wrapper to call procedure import_trans
    --	    This program implements concurrent program RRAM_XXXXXXXXXX
    --	Parameters
    --	    p_errbuf	  Standard OUT parameter for the program completion message
    --	    p_retcode	  Standard OUT parameter for the program completion status
    --			  (0=normal, 1=warning, 2=error)
    --	    p_debug	  Debug flag (Y|N) to output additional flow information to
    --			  the log file
    --	Author	    Date		    Comment
    --	----------  ----------	-----------------------------------------------
    --	sryan	    13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure import_trans_cp(
	p_errbuf		    out varchar2,
      	p_retcode		    out number,
	p_debug 	      in varchar2 default 'N');

    -- ------------------------------------------------------------------------
    --	Procedure
    --	    submit_import_trans
    --	Purpose
    --	    Program wrapper to submit the RRAM Import Invoices concurrent
    --	    program (RRAM_XXXXX)
    --	Parameters
    --	    p_user	      User name from fnd_users
    --	    p_resp_id	      Responsibility Id
    --	    p_resp_appl_id    Responsibility Application Id
    --	    p_debug	      Debug flag (Y|N) to output additional flow information to
    --			      the log file
    --	    p_request_id      Returned concurrent request id OR error message
    --	Author	    Date		    Comment
    --	----------  ----------	-----------------------------------------------
    --	sryan	    13/01/2015	initial
    -- ------------------------------------------------------------------------
    procedure submit_import_trans(
	p_user		      in varchar2,
      	p_resp_id		    in number,
      	p_resp_appl_id	      in number,
	p_debug 	      in varchar2 default 'N',
	p_request_id	     out number);

    procedure submit_import_trans(
	p_user		      in varchar2,
      	p_resp_id		    in number,
      	p_resp_appl_id	      in number,
	p_debug 	      in varchar2 default 'N');

end rram_ar_trans_pkg;
/

