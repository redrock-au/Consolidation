create or replace PACKAGE POC_DOC_NOTIFICATION AUTHID CURRENT_USER AS
/* $Header: svn://d02584/consolrepos/branches/AP.03.02/poc/1.0.0/install/sql/POC_DOC_NOTIFICATION.pks 1071 2017-06-21 05:16:54Z svnuser $ */

-- Print_Document
-- IN
--   itemtype  --   itemkey  --   actid   --   funcmode
-- OUT
--   Resultout
--
--   Print Document.

procedure Print_Document(   itemtype        in varchar2,
                            itemkey         in varchar2,
                            actid           in number,
                            funcmode        in varchar2,
                            resultout       out varchar2    ) ;

Procedure IsDocGenerated(	itemtype        in varchar2,
                            itemkey         in varchar2,
                            actid           in number,
                            funcmode        in varchar2,
                            resultout       out varchar2    ) ;

end  POC_DOC_NOTIFICATION;
