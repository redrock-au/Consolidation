create or replace PACKAGE        "POC_IP5_CUSTOM" AUTHID CURRENT_USER AS
/* $Header: svn://d02584/consolrepos/branches/AR.03.01/poc/1.0.0/install/sql/POC_IP5_CUSTOM.pks 1706 2017-07-12 04:37:42Z svnuser $ */

/****************************************************************************
**
**  Filename: POC_IP5_CUSTOM.pks
**
**  Location: $POC_TOP/install/sql
**
**  Spec    :
**
**  Purpose : Called from various iProc workflows.  Custom version of standard
**            package.
**
**  Author:   Jon Bartlett (Red Rock) + others
**
**  History:

**   22-JUN-2001 G. Richards     Created
**   01-AUG-2001 G. Richards     Added new functions.  See tags GKR01AUG01
**   22-JUN-2001 G. Richards     Created
**   01-AUG-2001 G. Richards     Added new functions.  See tags GKR01AUG01
**   01-FEB-2009 B. Freshwater   OPM Project
**   12-Feb-2009 J.Bartlett     (Red Rock)
**
**      Merged Lotus Notes Removal code and OPM changes into one package
**       ready for LNR go-live post OPM go-live.  OPM changes marked BHF.
**
**
****************************************************************************/


PROCEDURE set_item_tk(itemtype  in varchar2,
                      itemkey   in varchar2,
                      actid     in number,
                      funcmode  in varchar2,
                      resultout out varchar2);

FUNCTION calculate_gst_incl_amount(p_document_id number) return number;

-- Procedure takes PO_REQUISITION_LINES.ATTRIBUTE11 and 12 where the
-- requisition line = 1 and populates PO_REQUISITION_HEADERS.ATTRIBUTE1 and 2
-- with the details.  It sets PO_REQUISITION_LINES.ATTRIBUTE11 and 12 to null.
-- This is bringing the transmission method and details across from the line
-- to the header level.
PROCEDURE adjust_attributes(itemtype        in  varchar2,
                            itemkey         in  varchar2,
                            actid           in  number,
                            funcmode        in  varchar2,
                            resultout       out varchar2);

-- Checks all distributes on a requisition and checks of the second segment
-- = 00000  If so it reports back on all distribution lines that have that
-- second segment = 00000
PROCEDURE check_for_invalid_acct(itemtype        in  varchar2,
                                 itemkey         in  varchar2,
                                 actid           in  number,
                                 funcmode        in  varchar2,
                                 resultout       out varchar2);

-- GKR01AUG01 Procedure sets the user name to "firstname surname"
-- calculates the GST inclusive amount, gets the vendors name and
-- requisition number for the Approved PO
PROCEDURE set_po_approved_atts(itemtype        in  varchar2,
                               itemkey         in  varchar2,
                               actid           in  number,
                               funcmode        in  varchar2,
                               resultout       out varchar2);

-- GKR01AUG01 Gets the user name in the format of "firstname surname"
-- will return null if it cannot be retrieved
FUNCTION get_full_name(p_employee_id number)return varchar2;

-- GKR01AUG01 Sets user display name to "firstname surname"
PROCEDURE set_req_notif_atts(itemtype  in  varchar2,
                             itemkey   in  varchar2,
                             actid     in  number,
                             funcmode  in  varchar2,
                             resultout out varchar2);

-- GKR240501 Procedure declared see actual procedure code for more details
PROCEDURE VALIDATE_TRANS_METHOD(x_trans_method in     varchar2,
                                x_trans_detail in     varchar2,
                                x_return_code  in out number,
                                x_error_msg    in out varchar2);

-- GKR190601 Procedure declared see actual procedure code for more details
PROCEDURE GET_DEFAULT_TRANS_METHOD(x_site_id      in     number,
                                   x_trans_method    out varchar2,
                                   x_trans_detail    out varchar2,
                                   x_return_code  in out number,
                                   x_error_msg    in out varchar2);

/****************************************************************************
**
**  Procedure:    set_poreqcha_notif_attribute
**  Author:       Jon Bartlett (Red Rock) 19th September 2008
**  Purpose:      Used to set required values on Req Change Notification (poreqcha)
**
****************************************************************************/
PROCEDURE set_poreqcha_notif_attribute(itemtype  in  varchar2,
                                       itemkey   in  varchar2,
                                       actid     in  number,
                                       funcmode  in  varchar2,
                                       resultout out varchar2);

/****************************************************************************
**
**  Procedure:    set_poreqcha_notif_attribute
**  Author:       Jon Bartlett (Red Rock) 18th November 2008
**  Purpose:      Used to set required values on Req Change Notification (poreqcha)
**
****************************************************************************/
PROCEDURE submit_po_print (ERRBUF         OUT VARCHAR2,
                           RETCODE        OUT VARCHAR2,
                           p_po_header_id IN  VARCHAR2
                           );

/****************************************************************************
**
**  Procedure:    post_approval_notif
**  Author:       Jon Bartlett (Red Rock) 19th November 2008
**  Purpose:      Used to implement functionality to prevent approver from
**                 rejecting notification without entering a reason.
**
****************************************************************************/
PROCEDURE post_approval_notif(itemtype   in varchar2,
                              itemkey    in varchar2,
                              actid      in number,
                              funcmode   in varchar2,
                              resultout  out NOCOPY varchar2);

/****************************************************************************
**
**  Function:    get_serv_req_supplier
**  Author:      Jon Bartlett (Red Rock) 25th March 2009
**  Purpose:     Returns supplier name for Service Requisition.
**               If greater than one supplier assigned, returns custom
**               message.
**
****************************************************************************/
FUNCTION get_serv_req_supplier (pt_requisition_line_id in po_requisition_lines.requisition_line_id%type)
RETURN po_vendors.vendor_name%type;


/****************************************************************************
**
**  Function:    get_serv_req_supplier_site
**  Author:      Jon Bartlett (Red Rock) 25th March 2009
**  Purpose:     Returns supplier site name for Service Requisition.
**               If greater than one supplier site assigned, returns custom
**               message.
**
****************************************************************************/
FUNCTION get_serv_req_supplier_site (pt_requisition_line_id in po_requisition_lines.requisition_line_id%type)
RETURN po_vendor_sites.vendor_site_code%type;

/****************************************************************************
**
**  Function:    get_serv_req_contractor
**  Author:      Jon Bartlett (Red Rock) 25th March 2009
**  Purpose:     Returns suggested contractor for a Service Requisition.
**               If greater than one suppler/contactractor assigned, returns custom
**               message.
**
****************************************************************************/
FUNCTION get_serv_req_contractor (pt_requisition_line_id in po_requisition_lines.requisition_line_id%type)
RETURN per_people_f.full_name%type;

/****************************************************************************
**
**  Function:    get_serv_req_start_date
**  Author:      Jon Bartlett (Red Rock) 25th March 2009
**  Purpose:     Returns suggested contractor start date for a Service Requisition.
**
****************************************************************************/
FUNCTION get_serv_req_start_date (pt_requisition_line_id in po_requisition_lines.requisition_line_id%type)
RETURN po_requisition_lines.assignment_start_date%type;

/****************************************************************************
**
**  Function:    get_serv_req_end_date
**  Author:      Jon Bartlett (Red Rock) 25th March 2009
**  Purpose:     Returns suggested contractor end date for a Service Requisition.
**
****************************************************************************/
FUNCTION get_serv_req_end_date (pt_requisition_line_id in po_requisition_lines.requisition_line_id%type)
RETURN po_requisition_lines.assignment_end_date%type;

/****************************************************************************
**
**  Function:    is_po_print_enhanced
**  Author:      Joy Pinto (Red Rock) 15th June 2017
**  Purpose:     Returns Y if the tag of the org in the lookup XXDOI_POC_PO_PRINT_PROGRAMS is NEW and N Otherwise
**
****************************************************************************/
FUNCTION is_po_print_enhanced (p_org_id IN NUMBER
                              )
RETURN VARCHAR2;

/****************************************************************************
**
**  Procedure:    submit_po_appr_notif
**  Author:       Joy Pinto (Red Rock) 15th June 2017
**  Purpose:      Wrapper program to ubmit PO PRint Notification. Can be called from SRS or Workflow
**
****************************************************************************/
PROCEDURE submit_po_appr_notif (ERRBUF         OUT VARCHAR2,
                                RETCODE        OUT VARCHAR2,
                                p_po_header_id IN  VARCHAR2,
                                p_email_address IN VARCHAR2
                           );

END poc_ip5_custom;
/
