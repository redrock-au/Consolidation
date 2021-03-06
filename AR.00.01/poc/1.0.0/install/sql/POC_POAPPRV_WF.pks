create or replace PACKAGE POC_POAPPRV_WF AUTHID CURRENT_USER AS
/* $Header: svn://d02584/consolrepos/branches/AR.00.01/poc/1.0.0/install/sql/POC_POAPPRV_WF.pks 1492 2017-07-05 07:01:42Z svnuser $ */

PROCEDURE Print_Document(itemtype  in varchar2,
                         itemkey   in varchar2,
                         actid     in number,
                         funcmode  in varchar2,
                         resultout out varchar2);

PROCEDURE IsDocGenerated(itemtype  in varchar2,
                         itemkey   in varchar2,
                         actid     in number,
                         funcmode  in varchar2,
                         resultout out varchar2);

END POC_POAPPRV_WF;
