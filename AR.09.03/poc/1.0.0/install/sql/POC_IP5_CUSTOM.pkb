create or replace PACKAGE BODY        "POC_IP5_CUSTOM"
AS
/* $Header: svn://d02584/consolrepos/branches/AR.09.03/poc/1.0.0/install/sql/POC_IP5_CUSTOM.pkb 2689 2017-10-05 04:37:59Z svnuser $ */

/****************************************************************************
**
**  Filename: POC_IP5_CUSTOM.pkb
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




/****************************************************************************
**
**  Procedure:    get_supplier_details
**  Author:       Jon Bartlett (Red Rock) 12th May 2009
**  Purpose:      Fetches supplier information for inclusion on Notification
**                 header.
**
****************************************************************************/
function get_supplier_details (pt_req_header_id in po_requisition_headers.requisition_header_id%type)
return   varchar2
is
     --
     vv_supp_details  varchar2(250);
     --
begin
     --
     begin
          --
          select distinct pv.vendor_name
          ||     decode(pvs.address_line1, null, null, ', '||pvs.address_line1)
          ||     decode(pvs.address_line2, null, null, ', '||pvs.address_line2)
          ||     decode(pvs.address_line3, null, null, ', '||pvs.address_line3)
          ||     decode(pvs.address_line4, null, null, ', '||pvs.address_line4)
          ||     decode(pvs.city, null, null, ', '||pvs.city)
          ||     decode(pvs.state, null, null, ', '||pvs.state)
          ||     decode(pvs.zip, null, null, ', '||pvs.zip)
          ||     '.'     supplier_details
          into   vv_supp_details
          from   po_requisition_headers ph
          ,      po_requisition_lines   pl
          ,      po_vendors             pv
          ,      po_vendor_sites        pvs
          where  ph.requisition_header_id = pl.requisition_header_id
            and  pl.vendor_id             = pv.vendor_id
            and  pl.vendor_site_id        = pvs.vendor_site_id
            and  ph.requisition_header_id = pt_req_header_id;
     --
     exception
     when too_many_rows then
          --
          vv_supp_details := 'Multiple';
          --
     when no_data_found then
          -- probably a service req.
          begin
               --
               select distinct pv.vendor_name
                    ||     decode(pvs.address_line1, null, null, ', '||pvs.address_line1)
                    ||     decode(pvs.address_line2, null, null, ', '||pvs.address_line2)
                    ||     decode(pvs.address_line3, null, null, ', '||pvs.address_line3)
                    ||     decode(pvs.address_line4, null, null, ', '||pvs.address_line4)
                    ||     decode(pvs.city, null, null, ', '||pvs.city)
                    ||     decode(pvs.state, null, null, ', '||pvs.state)
                    ||     decode(pvs.zip, null, null, ', '||pvs.zip)
                    ||     '.'     supplier_details
               into   vv_supp_details
               from   po_requisition_suppliers  prs
               ,      po_requisition_lines_all  prl
               ,      po_vendors                pv
               ,      po_vendor_sites_all       pvs
               where  1=1
                 and  prs.requisition_line_id   = prl.requisition_line_id
                 and  prs.vendor_id             = pv.vendor_id
                 and  prs.vendor_site_id        = pvs.vendor_site_id
                 and  prl.requisition_header_id = pt_req_header_id;
               --
          exception
          when too_many_rows then
               --
               vv_supp_details := 'Multiple';
               --
          when others then
               --
               vv_supp_details := null;
               --
          end;
          --
     end;
     --
     return (vv_supp_details);
     --
exception
when others then
     --
     return (null);
     --
end get_supplier_details;


/****************************************************************************
**
**  Procedure:    get_req
**  Author:       Jon Bartlett (Red Rock) 12th May 2009
**  Purpose:      Fetches Req Header DFFs to add to Notification
**
****************************************************************************/
function  get_req  (pt_req_header_id in po_requisition_headers.requisition_header_id%type)
return   po_requisition_headers%rowtype
is
     --
     vt_req_header_rec  po_requisition_headers%rowtype;
     --
begin
     --
     select rh.attribute3  xx_dot_cms_number
     ,      decode(rh.attribute8,'Y','Yes','N','No',null)  xxdot_contract_variation
     ,      rh.attribute4  xxdot_selection_method
     ,      decode(rh.attribute9,'Y','Yes','N','No',null)  xxdot_comply_it_policy
     ,      rh.attribute5  xxdot_approve_fin_del
     ,      rh.attribute6  xxdot_approval_date
     into   vt_req_header_rec.attribute3
     ,      vt_req_header_rec.attribute8
     ,      vt_req_header_rec.attribute4
     ,      vt_req_header_rec.attribute9
     ,      vt_req_header_rec.attribute5
     ,      vt_req_header_rec.attribute6
     from   po_requisition_headers rh
     where  rh.requisition_header_id = pt_req_header_id;
     --
     return (vt_req_header_rec);
     --
end get_req;

PROCEDURE set_item_tk(itemtype  in varchar2,
		      itemkey   in varchar2,
		      actid     in number,
		      funcmode  in varchar2,
		      resultout out varchar2) IS
BEGIN
  wf_engine.SetItemAttrText(itemtype => itemtype,
                            itemkey  => itemkey,
                            aname    => 'POC_ITEM_TK',
                            avalue   => itemtype || ':' || itemkey);
END set_item_tk;

-- GKR19JUN01 Function added to calculate the GST inclusive amount for
-- the entire requisition
FUNCTION calculate_gst_incl_amount(p_document_id number) return number is
    v_dummy number := -99;
BEGIN
  -- SR280307 SQL was not taking into account cancelled lines.
  -- Added the substraction of l.quantity_cancelled
  --
  -- BHF 04-FEB-2009
  -- Catered for NULL values for Unit Price and/or Quantity, as will be
  -- the case for certain Service Requisition lines
  --
  SELECT SUM
         (
           NVL( (prl.quantity - NVL( prl.quantity_cancelled
                                   , 0)) * prl.unit_price
              , prl.amount
              ) * (1 + (NVL(atc.tax_rate, 0)/100))
         )
  INTO   v_dummy
  FROM   ap_tax_codes_all             atc
  ,      po_requisition_lines         prl
  WHERE  prl.requisition_header_id  = p_document_id
  AND    prl.tax_code_id            = atc.tax_id(+)
  AND    NVL(prl.cancel_flag, 'N') != 'Y';

  return v_dummy;
EXCEPTION
  when others then
    return -99;
END calculate_gst_incl_amount;

-- Procedure takes PO_REQUISITION_LINES.ATTRIBUTE11 and 12 where the
-- requisition line = 1 and populates PO_REQUISITION_HEADERS.ATTRIBUTE1 and 2
-- with the details.  It sets PO_REQUISITION_LINES.ATTRIBUTE11 and 12 to null.
-- This is bringing the transmission method and details across from the line
-- to the header level.
PROCEDURE adjust_attributes(itemtype  in varchar2,
			    itemkey   in varchar2,
			    actid     in number,
			    funcmode  in varchar2,
			    resultout out varchar2) IS

  -- Cursor to get details of line 1 of the requisition
  cursor req_line_details(p_req_id po_requisition_headers_all.requisition_header_id%TYPE)is
    select l.attribute11,
	   l.attribute12,
  	   l.requisition_line_id,
	   l.vendor_site_id
    from po_requisition_lines_all l
    where l.requisition_header_id = p_req_id
    and   l.line_num = 1;

  lv_rec_line req_line_details%ROWTYPE;

  lv_req_id po_requisition_headers_all.requisition_header_id%TYPE;
  lv_method po_requisition_headers_all.attribute1%TYPE;
  lv_detail po_requisition_headers_all.attribute2%TYPE;

  lv_totamt_gstincl       number;
  lv_totamt_dsp_gstincl   varchar2(30);
  lv_cc                   varchar2(30);
BEGIN
  -- Getting requisition ID from the workflow
  lv_req_id := wf_engine.GetItemAttrNumber (itemtype => itemtype,
                                            itemkey  => itemkey,
                                            aname    => 'DOCUMENT_ID');

  -- Getting requisition line details
  open req_line_details(lv_req_id);
  fetch req_line_details into lv_rec_line;
  close req_line_details;

  lv_method := lv_rec_line.attribute11;
  lv_detail := lv_rec_line.attribute12;

  -- Getting default transmission method and details if needed
  if(lv_method is null and lv_rec_line.vendor_site_id is not null)then
    begin
      select s.attribute5,
             decode(upper(s.attribute5), 'FAX',       s.attribute7,
                                         'EMAIL',     s.attribute6,
                                         'EMAIL-PDF', s.attribute6,
                                         null)
      into lv_method,
           lv_detail
      from po_vendor_sites_all s
      where s.vendor_site_id = lv_rec_line.vendor_site_id;
    exception
      when others then
        lv_method := null;
        lv_detail := null;
    end;
  end if;

  -- Updating headers with transmission details
  update po_requisition_headers_all h
  set h.attribute1 = lv_method,
      h.attribute2 = lv_detail
  where h.requisition_header_id = lv_req_id;

  -- Clearing transmission details from the line
  update po_requisition_lines_all l
  set l.attribute11 = null,
      l.attribute12 = null
  where l.requisition_line_id = lv_rec_line.requisition_line_id;

  lv_cc := PO_CORE_S2.get_base_currency;

  lv_totamt_gstincl := calculate_gst_incl_amount(lv_req_id);

  lv_totamt_dsp_gstincl := to_char(lv_totamt_gstincl,
                             FND_CURRENCY.GET_FORMAT_MASK(lv_cc,30));

  wf_engine.SetItemAttrText (itemtype => itemtype,
                             itemkey  => itemkey,
                             aname    => 'POC_TOTAMT_GSTINCL',
                             avalue   => lv_totamt_dsp_gstincl);

END adjust_attributes;

-- Checks all distributes on a requisition and checks of the second segment
-- = 00000  If so it reports back on all distribution lines that have that
-- second segment = 00000
PROCEDURE check_for_invalid_acct(itemtype        in varchar2,
			itemkey         in varchar2,
			actid           in number,
			funcmode        in varchar2,
			resultout       out varchar2)IS

  -- Cursor to get all the code combinations for a requisition
  CURSOR cur_dist_accts(p_req_id po_requisition_headers_all.requisition_header_id%TYPE)IS
    select g.segment1,
           g.segment2,
           g.segment3,
           g.segment4,
           g.segment5,
           g.segment6,
           g.segment7,
	   h.segment1 req_num,
	   l.line_num,
	   d.distribution_num,
	   l.requisition_line_id,
	   d.distribution_id
    from gl_code_combinations       g,
	 po_req_distributions_all   d,
	 po_requisition_headers_all h,
	 po_requisition_lines_all   l
    where g.code_combination_id   = d.code_combination_id
    and   h.requisition_header_id = l.requisition_header_id
    and   l.requisition_line_id   = d.requisition_line_id
    and   h.requisition_header_id = p_req_id
    order by l.line_num, d.distribution_num;

  lv_rec_accts cur_dist_accts%ROWTYPE;
  lv_req_id    po_requisition_headers_all.requisition_header_id%TYPE;
  lv_note_text varchar2(1000) := null;
  lv_bad_acct  boolean        := FALSE;

  lc_bad_seg2  constant gl_code_combinations.segment2%TYPE := '00000';
  lc_NL        constant varchar2(1) := fnd_global.newline;
BEGIN
  -- Getting requisition_header_id from workflow
  lv_req_id := wf_engine.GetItemAttrNumber(itemtype => itemtype,
                                           itemkey  => itemkey,
                                           aname    => 'DOCUMENT_ID');
  resultout := 'N';

  -- Looping until all GL codes combinations have been analyzed
  for lv_req_accts in cur_dist_accts(lv_req_id) loop

    -- if an invalid segment has been found record the information
    -- to report back to the workflow
    if(lv_req_accts.segment2 = lc_bad_seg2)then
      if(resultout = 'N')then
        resultout := 'Y';
        lv_bad_acct := TRUE;
	lv_note_text := 'Line#  Dist#  Account Code' || lc_NL;
	lv_note_text := '-----  -----  -----------------------------------'||lc_NL;
      end if;
      lv_note_text := lv_note_text || to_char(lv_req_accts.line_num, '99990')
		      || '  ' || to_char(lv_req_accts.distribution_num, '99990')
		      || '  ' || lv_req_accts.segment1
		      || '.'  || lv_req_accts.segment2
		      || '.'  || lv_req_accts.segment3
		      || '.'  || lv_req_accts.segment4
		      || '.'  || lv_req_accts.segment5
		      || '.'  || lv_req_accts.segment6
		      || '.'  || lv_req_accts.segment7 || lc_NL;
    end if;
  end loop;

  -- Update custom attribute in workflow with the invalid account details to
  -- be sent to the user
  wf_engine.SetItemAttrText(itemtype => itemtype,
                            itemkey  => itemkey,
                            aname    => 'POC_INVALID_ACCOUNT_TEXT',
                            avalue   => lv_note_text);
END check_for_invalid_acct;


-- GKR01AUG01 Procedure sets the user name to "firstname surname"
-- calculates the GST inclusive amount, gets the vendors name and
-- requisition number for the Approved PO
PROCEDURE set_po_approved_atts(itemtype  in  varchar2,
                               itemkey   in  varchar2,
                               actid     in  number,
                               funcmode  in  varchar2,
                               resultout out varchar2) IS
  lv_po_id         po_headers_all.po_header_id%TYPE;
  lv_preparer_id   hr_employees_current_v.employee_id%TYPE;
  lv_preparer_name varchar2(80);
  lv_vendor_name   po_vendors.vendor_name%TYPE;
  lv_req_num       po_requisition_headers_all.segment1%TYPE;
  lv_gst_incl_amt  number := 0;
begin
  -- Getting the po_header_id from workflow
  lv_po_id := wf_engine.GetItemAttrNumber(itemtype => itemtype,
                                           itemkey  => itemkey,
                                           aname    => 'DOCUMENT_ID');

  -- Changing the Preparer name to "Firstname Surname"
  lv_preparer_id := wf_engine.GetItemAttrText (itemtype => itemtype,
                                               itemkey  => itemkey,
                                               aname    => 'PREPARER_ID');
  begin
    select substr(h.first_name||' '||h.last_name,1,80)
    into   lv_preparer_name
    from   hr_employees_current_v h
    where  h.employee_id = lv_preparer_id;
  exception when others then
    lv_preparer_name := null;
  end;
  if(lv_preparer_name is not null)then
    wf_engine.SetItemAttrText(itemtype => itemtype,
                              itemkey  => itemkey,
                              aname    => 'PREPARER_DISPLAY_NAME',
                              avalue   => lv_preparer_name);
  end if;

  -- Getting the Vendor name to Display
  begin
    select v.vendor_name
    into   lv_vendor_name
    from   po_vendors v
    where  v.vendor_id = (select vendor_id
			  from   po_headers_all
			  where  po_header_id = lv_po_id);
  exception when others then
    lv_vendor_name := null;
  end;
  wf_engine.SetItemAttrText(itemtype => itemtype,
                            itemkey  => itemkey,
                            aname    => 'POC_VENDOR_NAME_DISP',
                            avalue   => lv_vendor_name);

  -- Getting the requisition details to display
  begin
   select h.segment1
   into lv_req_num
    from po_requisition_headers h,
         po_requisition_lines   l,
         po_req_distributions   d,
         po_distributions_all   pd
    where l.requisition_header_id = h.requisition_header_id
    and   d.requisition_line_id = l.requisition_line_id
    and   d.distribution_id = pd.req_distribution_id
    and   pd.po_header_id = lv_po_id
    and   rownum = 1;
  exception when others then
    lv_req_num := null;
  end;
  wf_engine.SetItemAttrText(itemtype => itemtype,
                            itemkey  => itemkey,
                            aname    => 'POC_REQ_NUMBER',
                            avalue   => lv_req_num);

  -- Calculating GST Inclusive price for the PO
  --
  -- Bruce Freshwater 04-FEB-2009
  -- Catered for PO Line Locations that may have NULL values for
  -- Quantity (such as certain Service Requisitions)
  --
  BEGIN

    SELECT SUM( ROUND(  NVL(  NVL( pll.price_override
                                 , 1
                                 )
                            * pll.quantity
                           , pll.amount
                           )
                      * DECODE( pll.taxable_flag
                              , 'Y', 1 + (atc.tax_rate/100)
                              ,      1
                              )
                      , 2)
              )
    INTO  lv_gst_incl_amt
    FROM  ap_tax_codes_all    atc
    ,     po_line_locations   pll
    WHERE pll.po_header_id  = lv_po_id
    AND   atc.tax_id        = pll.tax_code_id;

  EXCEPTION
  WHEN OTHERS
  THEN
    lv_gst_incl_amt := 0;
  END;

  if(lv_gst_incl_amt != 0)then
    wf_engine.SetItemAttrText(itemtype => itemtype,
                              itemkey  => itemkey,
                              aname    => 'PO_AMOUNT_DSP',
                              avalue   => replace(to_char(lv_gst_incl_amt,
                                          '$999,999,999,999,990.00'), ' '));
  end if;
end set_po_approved_atts;


-- GKR01AUG01 Gets the user name in the format of "firstname surname"
-- will return null if it cannot be retrieved
FUNCTION get_full_name(p_employee_id number)return varchar2 is
  lv_full_name varchar2(100) := null;
begin
  select full_name /* Code defunct 11.5.8 -> h.first_name||' '||h.last_name */
  into   lv_full_name
  from   hr_employees_current_v h
  where  h.employee_id = p_employee_id;
  return lv_full_name;
exception when others then
  return null;
end get_full_name;


-- GKR01AUG01 Sets user display name to "firstname surname"
PROCEDURE set_req_notif_atts(itemtype  in  varchar2,
                             itemkey   in  varchar2,
                             actid     in  number,
                             funcmode  in  varchar2,
                             resultout out varchar2) IS
  lv_id        number;
  lv_disp_name varchar2(100);
begin

  lv_id := wf_engine.GetItemAttrNumber(itemtype => itemtype,
                                       itemkey  => itemkey,
                                       aname    => 'FORWARD_FROM_ID');
  lv_disp_name := get_full_name(lv_id);

  if(lv_disp_name is not null)then
    wf_engine.SetItemAttrText(itemtype => itemtype,
                              itemkey  => itemkey,
                              aname    => 'FORWARD_FROM_DISP_NAME',
                              avalue   => lv_disp_name);
  end if;
  lv_disp_name := null;

  lv_id := wf_engine.GetItemAttrNumber(itemtype => itemtype,
                                       itemkey  => itemkey,
                                       aname    => 'FORWARD_TO_ID');
  lv_disp_name := get_full_name(lv_id);

  if(lv_disp_name is not null)then
    wf_engine.SetItemAttrText(itemtype => itemtype,
                              itemkey  => itemkey,
                              aname    => 'FORWARD_TO_DISPLAY_NAME',
                              avalue   => lv_disp_name);
  end if;
  lv_disp_name := null;

  lv_id := wf_engine.GetItemAttrNumber(itemtype => itemtype,
                                       itemkey  => itemkey,
                                       aname    => 'PREPARER_ID');
  lv_disp_name := get_full_name(lv_id);

  if(lv_disp_name is not null)then
    wf_engine.SetItemAttrText(itemtype => itemtype,
                              itemkey  => itemkey,
                              aname    => 'PREPARER_DISPLAY_NAME',
                              avalue   => lv_disp_name);
  end if;
  lv_disp_name := null;

  lv_id := wf_engine.GetItemAttrNumber(itemtype => itemtype,
                                       itemkey  => itemkey,
                                       aname    => 'APPROVER_EMPID');
  lv_disp_name := get_full_name(lv_id);

  if(lv_disp_name is not null)then
    wf_engine.SetItemAttrText(itemtype => itemtype,
                              itemkey  => itemkey,
                              aname    => 'APPROVER_DISPLAY_NAME',
                              avalue   => lv_disp_name);
  end if;
  lv_disp_name := null;

  lv_id := wf_engine.GetItemAttrNumber(itemtype => itemtype,
                                       itemkey  => itemkey,
                                       aname    => 'RESPONDER_ID');
  lv_disp_name := get_full_name(lv_id);

  if(lv_disp_name is not null)then
    wf_engine.SetItemAttrText(itemtype => itemtype,
                              itemkey  => itemkey,
                              aname    => 'RESPONDER_DISPLAY_NAME',
                              avalue   => lv_disp_name);
  end if;

  -- Fetch CMS Number from Requisition Header DFF (Attribute 3)
  -- Jon Bartlett Red Rock 12th September 2008
  declare
       --
       vt_req_header_id  po_requisition_headers.requisition_header_id%type;
       vt_req_rec        po_requisition_headers%rowtype;
       --
  begin
       --
       vt_req_header_id := wf_engine.GetItemAttrNumber(itemtype => itemtype,
                                                       itemkey  => itemkey,
                                                       aname    => 'DOCUMENT_ID');
       --
       vt_req_rec := get_req (vt_req_header_id);
       --
       wf_engine.SetItemAttrText(itemtype => itemtype,
                                 itemkey  => itemkey,
                                 aname    => 'XXDOT_CMS_NUMBER',
                                 avalue   => vt_req_rec.attribute3);
       --
       wf_engine.SetItemAttrText(itemtype => itemtype,
                                 itemkey  => itemkey,
                                 aname    => 'XXDOT_CONTRACT_VARIATION',
                                 avalue   => vt_req_rec.attribute8);
       --
       wf_engine.SetItemAttrText(itemtype => itemtype,
                                 itemkey  => itemkey,
                                 aname    => 'XXDOT_SELECT_METHOD',
                                 avalue   => vt_req_rec.attribute4);
       --
       wf_engine.SetItemAttrText(itemtype => itemtype,
                                 itemkey  => itemkey,
                                 aname    => 'XXDOT_COMPLY_IT_POLICY',
                                 avalue   => vt_req_rec.attribute9);
       --
       wf_engine.SetItemAttrText(itemtype => itemtype,
                                 itemkey  => itemkey,
                                 aname    => 'XXDOT_APPROVED_FIN_DEL',
                                 avalue   => vt_req_rec.attribute5);
       --
       wf_engine.SetItemAttrText(itemtype => itemtype,
                                 itemkey  => itemkey,
                                 aname    => 'XXDOT_APPROVAL_DATE',
                                 avalue   => to_char(to_date(vt_req_rec.attribute6,'YYYY/MM/DD HH24:MI:SS'),'DD-MON-YYYY'));
       --
       wf_engine.SetItemAttrText(itemtype => itemtype,
                                 itemkey  => itemkey,
                                 aname    => 'XXDOT_SUPPLIER_DETAILS',
                                 avalue   => get_supplier_details(vt_req_header_id));
       --

  end;
  -- end changes JB 12th September 2008
  --
end set_req_notif_atts;

-- GKR240501 Procedure added to validate transmission methods and
-- transmission details
-- EM120303 Transferred this method from POR_CUSTOM_PKG
PROCEDURE VALIDATE_TRANS_METHOD(x_trans_method in     varchar2,
                                x_trans_detail in     varchar2,
                                x_return_code  in out number,
                                x_error_msg    in out varchar2)IS

  FUNCTION valid_fax_number(p_fax_number varchar2) return boolean is
    v_dummy number        := -1;
    v_str   varchar2(100) := null;
  BEGIN
    v_str := replace(p_fax_number, ' ', null);

    -- v_dummy will be set to 0 if fax number is all ','
    v_dummy := nvl(length(
                   replace(translate(v_str, ',', ' '), ' ', null)
                         ),0);

    -- if fax number is not all ','
    if (v_dummy != 0) then

      -- v_dummy will be set to 0 is only contains characters [0123456789,]
      v_dummy := nvl(length(
                     replace(translate(v_str, '0123456789,', ' '), ' ', null)
                           ),0);

      -- if fax number only contains valid characters
      if(v_dummy = 0)then
        return TRUE;
      end if;
    end if;

    return FALSE;

  END valid_fax_number;

BEGIN
   if(x_trans_method is null)then
      x_return_code := x_return_code + 1;
      x_error_msg := 'Transmission Method was not supplied.';
   elsif (x_trans_method in ('PRINT', 'NONE')) then

      if(x_trans_detail is not null)then
        x_return_code := x_return_code + 1;
        x_error_msg   := 'No fax number or Email address should be specified'||
                       ' for a transmission method of '||x_trans_method||'.';
      end if;

   elsif (x_trans_method in ('EMAIL', 'EMAIL-PDF')) then
      if(x_trans_detail is null)then
        x_return_code := x_return_code + 1;
        x_error_msg   := 'An Email addess needs to be provided for an '||
                          x_trans_method||' transmission method';
      elsif(instr(x_trans_detail, ' ', 1) != 0)then
        x_return_code := x_return_code + 1;
        x_error_msg   := 'An Email can not contain spaces.';
      end if;
   elsif(x_trans_method = 'FAX')then
      -- check if nothing was supplied for a fax number
      if(x_trans_detail is null)then
         x_return_code := x_return_code + 1;
         x_error_msg   := 'A valid fax number needs to be provided for a '||
                           x_trans_method||' transmission method';
      -- check if fax number is not valid
      elsif(not valid_fax_number(x_trans_detail))then
         x_return_code := x_return_code + 1;
         x_error_msg   := 'An invalid fax number was entered.  A fax number can only contain characters [0-9 ,]';
      end if;
   else
     x_error_msg := 'Invalid Transmission Method entered.';
     x_return_code := x_return_code + 1;
   end if;

   if(x_return_code > 0)then
     x_error_msg := 'Error on line 1: '||x_error_msg;
   end if;

END VALIDATE_TRANS_METHOD;
-- GKR240501 End Modification


-- GKR190601 Procedure added to get default Transmission Method and Details
-- from PO_VENDOR_SITES
-- EM120303 Transferred this method from POR_CUSTOM_PKG
PROCEDURE GET_DEFAULT_TRANS_METHOD(x_site_id      in     number,
                                   x_trans_method out    varchar2,
                                   x_trans_detail out    varchar2,
                                   x_return_code  in out number,
                                   x_error_msg    in out varchar2)IS

  -- Note changing the following 2 variables will default transmission details
  -- if they are not found.  This may have serious implications if you change
  -- them.
  lc_default_trans_method constant po_vendor_sites.attribute5%TYPE := null;
  lc_default_trans_detail constant po_vendor_sites.attribute5%TYPE := null;
BEGIN
  select attribute5,
         decode(upper(attribute5), 'FAX',       attribute7,
                                   'EMAIL',     attribute6,
                                   'EMAIL-PDF', attribute6,
                                   null)
  into x_trans_method,
       x_trans_detail
  from po_vendor_sites
  where vendor_site_id = x_site_id;
EXCEPTION
  when others then
   x_trans_method := lc_default_trans_method;
    x_trans_detail := lc_default_trans_detail;
END GET_DEFAULT_TRANS_METHOD;
-- GKR190601 End Modification

/****************************************************************************
**
**  Procedure:    get_old_req_inc_amount
**  Author:       Jon Bartlett (Red Rock) 19th September 2008
**  Purpose:      Fetches old Req GST inclusive total amount
**
****************************************************************************/
FUNCTION get_old_req_inc_amount (pt_req_header_id in po_requisition_headers.requisition_header_id%type)
return number
is
     --
     ln_old_req_total_tax number;
     ln_old_req_total     number;
     --
begin
     --
     select sum(por_view_reqs_pkg.get_line_rec_tax_total(prl.requisition_line_id))
     into   ln_old_req_total_tax
     from   po_requisition_lines prl
     where  prl.requisition_header_id = pt_req_header_id;
     --
     ln_old_req_total := por_view_reqs_pkg.get_req_total(pt_req_header_id);
     --
     return(ln_old_req_total + ln_old_req_total_tax);
end;



/****************************************************************************
**
**  Procedure:    get_new_req_inc_amount
**  Author:       Jon Bartlett (Red Rock) 19th September 2008
**  Purpose:      Fetches Req Change GST inclusive total amount for changed req
**
****************************************************************************/
FUNCTION get_new_req_inc_amount (pt_req_header_id in po_requisition_headers.requisition_header_id%type
                                     ,pt_change_request_group_id in po_change_requests.change_request_group_id%type)
return   number
is
     --
     ln_new_req_excl_total number;
     ln_new_req_tax_total  number;
     --
begin
     --
     select  nvl(sum(decode(pcr4.action_type, 'CANCELLATION', 0, decode(prl.matching_basis, 'AMOUNT', nvl(pcr3.new_amount, prl.amount),
             nvl(pcr1.new_price, prl.unit_price)*
             nvl(pcr2.new_quantity, prl.quantity)))), 0) new_req_amount
     ,       nvl(sum(nvl(decode(pcr4.action_type,
                               'CANCELLATION', 0,
                               decode(prl.unit_price
                                      ,0, 0,
                                      decode(prl.matching_basis,
                                             'AMOUNT',nvl(pcr3.new_amount, prl.amount)
                                                        * por_view_reqs_pkg.get_line_rec_tax_total(prl.requisition_line_id)/prl.amount ,
                                                          nvl(pcr1.new_price, prl.unit_price)* nvl(pcr2.new_quantity, prl.quantity)*  por_view_reqs_pkg.get_line_rec_tax_total(prl.requisition_line_id)/(prl.unit_price*prl.quantity)))),0)),0) dot_new_tax_amount
     into  ln_new_req_excl_total
     ,     ln_new_req_tax_total
     from  po_requisition_lines_all prl
     ,     po_change_requests       pcr1
     ,     po_change_requests       pcr2
     ,     po_change_requests       pcr3
     ,     po_change_requests       pcr4
     where prl.requisition_line_id=pcr1.document_line_id(+)
        and pcr1.change_request_group_id(+)=pt_change_request_group_id--l_change_request_group_id
        and pcr1.request_level(+)='LINE'
        and pcr1.change_active_flag(+)='Y'
        and pcr1.new_price(+) is not null
        and pcr1.request_status(+) <> 'REJECTED'
        and prl.requisition_line_id=pcr2.document_line_id(+)
        and pcr2.change_request_group_id(+)=pt_change_request_group_id--l_change_request_group_id
        and pcr2.request_level(+)='LINE'
        and pcr2.action_type(+)='DERIVED'
        and pcr2.new_quantity(+) is not null
        and pcr2.request_status(+) <> 'REJECTED'
        and prl.requisition_line_id=pcr3.document_line_id(+)
        and pcr3.change_request_group_id(+)=pt_change_request_group_id--l_change_request_group_id
        and pcr3.request_level(+)='LINE'
        and pcr3.action_type(+)='DERIVED'
        and pcr3.new_amount(+) is not null
        and pcr3.request_status(+) <> 'REJECTED'
        and prl.requisition_line_id=pcr4.document_line_id(+)
        and pcr4.change_request_group_id(+)=pt_change_request_group_id--l_change_request_group_id
        and pcr4.request_level(+)='LINE'
        and pcr4.action_type(+)='CANCELLATION'
        and prl.requisition_header_id=pt_req_header_id--l_document_id
        AND NVL(prl.modified_by_agent_flag, 'N') = 'N'
        and NVL(prl.cancel_flag, 'N')='N';
     --
     return (ln_new_req_excl_total+ln_new_req_tax_total);
     --
end;

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
                                       resultout out varchar2)
is
     --
     ln_req_header_id             po_requisition_headers.requisition_header_id%type;
     lt_change_request_group_id   po_change_requests.change_request_group_id%type;
     lv_cms_number                po_requisition_headers.attribute3%type;
     lv_new_total_inc_amount_dsp  varchar2(100);
     lv_old_total_inc_amount_dsp  varchar2(100);
     --
     vt_req_rec                   po_requisition_headers%rowtype;
     --
     --
begin
     --
     ln_req_header_id := wf_engine.GetItemAttrNumber(itemtype => itemtype,
                                                     itemkey  => itemkey,
                                                     aname    => 'DOCUMENT_ID');
     --
     lt_change_request_group_id := wf_engine.GetItemAttrNumber
                                            (itemtype   => itemtype
                                            ,itemkey    => itemkey
                                            ,aname      => 'CHANGE_REQUEST_GROUP_ID');
     --
     lv_new_total_inc_amount_dsp := rtrim(ltrim(to_char(get_new_req_inc_amount (ln_req_header_id, lt_change_request_group_id),'999,999,999,999.99')));
     lv_old_total_inc_amount_dsp := rtrim(ltrim(to_char(get_old_req_inc_amount (ln_req_header_id),'999,999,999,999.99')));
     --
     wf_engine.SetItemAttrText(itemtype => itemtype,
                               itemkey  => itemkey,
                               aname    => 'XXDOT_NEW_TOTAL_INCL_TAX_DSP',
                               avalue   => lv_new_total_inc_amount_dsp);
     --
     wf_engine.SetItemAttrText(itemtype => itemtype,
                               itemkey  => itemkey,
                               aname    => 'XXDOT_OLD_TOTAL_INCL_TAX_DSP',
                               avalue   => lv_old_total_inc_amount_dsp);
     --
     vt_req_rec := get_req (ln_req_header_id);
     --
     wf_engine.SetItemAttrText(itemtype => itemtype,
                               itemkey  => itemkey,
                               aname    => 'XXDOT_CONTRACT_VARIATION',
                               avalue   => vt_req_rec.attribute8);
     --
     wf_engine.SetItemAttrText(itemtype => itemtype,
                               itemkey  => itemkey,
                               aname    => 'XXDOT_CMS_NUMBER',
                               avalue   => vt_req_rec.attribute3);
     --
     wf_engine.SetItemAttrText(itemtype => itemtype,
                               itemkey  => itemkey,
                               aname    => 'XXDOT_SELECT_METHOD',
                               avalue   => vt_req_rec.attribute4);
     --
     wf_engine.SetItemAttrText(itemtype => itemtype,
                               itemkey  => itemkey,
                               aname    => 'XXDOT_COMPLY_IT_POLICY',
                               avalue   => vt_req_rec.attribute9);
     --
     wf_engine.SetItemAttrText(itemtype => itemtype,
                               itemkey  => itemkey,
                               aname    => 'XXDOT_APPROVED_FIN_DEL',
                               avalue   => vt_req_rec.attribute5);
     --
     wf_engine.SetItemAttrText(itemtype => itemtype,
                               itemkey  => itemkey,
                               aname    => 'XXDOT_APPROVAL_DATE',
                               avalue   => to_char(to_date(vt_req_rec.attribute6,'YYYY/MM/DD HH24:MI:SS'),'DD-MON-YYYY'));
     --
     wf_engine.SetItemAttrText(itemtype => itemtype,
                               itemkey  => itemkey,
                               aname    => 'XXDOT_SUPPLIER_DETAILS',
                               avalue   => get_supplier_details(ln_req_header_id));
     --
     --
end;

/****************************************************************************
**
**  Procedure:    submit_po_print
**  Author:       Jon Bartlett (Red Rock) 18th November 2008
**  Purpose:      Used to submit custom PO Print from iProc.  Called via Conc
**                 request to submit 2 copies of PO print.
**
****************************************************************************/
PROCEDURE submit_po_print (ERRBUF         OUT VARCHAR2,
                           RETCODE        OUT VARCHAR2,
                           p_po_header_id IN  VARCHAR2                           
                           )
IS
     --
     vt_req_id1       fnd_concurrent_requests.request_id%type;
     vt_req_id2       fnd_concurrent_requests.request_id%type;
     vv_conc_error       varchar2(1) := '2';
     vv_conc_success     varchar2(1) := '0';
     lv_po_enhanced      varchar2(10) := 'N';
     lv_app_short_name   varchar2(10) := 'POC';
     lv_templ_code       varchar2(10) := 'POCEPOXML';
     lv_option_return    boolean;
     --
     CURSOR get_po_enhanced IS
        SELECT NVL(poc_ip5_custom.is_po_print_enhanced(org_id),'N')
        FROM   po_headers_all
        WHERE  po_header_id = p_po_header_id;
BEGIN
     -- Added the below code by Joy Pinto on 15-June-2017
     OPEN get_po_enhanced;
     FETCH get_po_enhanced INTO lv_po_enhanced;
     CLOSE get_po_enhanced;
     
     IF nvl(lv_po_enhanced,'N') = 'N' THEN -- Existing program where 2 programs are fired for existing PTV/TSC
     
        fnd_file.put_line(fnd_file.log,'About to submit conc program1 POCEPOPSIPROC - Supplier Copy ');
        
        vt_req_id1 := FND_REQUEST.SUBMIT_REQUEST (APPLICATION => 'POC'
                                                 ,PROGRAM     => 'POCEPOPSIPROC'
                                                 ,DESCRIPTION => 'DOT Custom PO - Supplier Copy'
                                                 ,ARGUMENT1   => p_po_header_id
                                                 ,ARGUMENT2   => null);
        --
        commit;
        --
        fnd_file.put_line(fnd_file.log,'Back from submitting conc prog.  Status: '||vt_req_id1);
        --
        fnd_file.put_line(fnd_file.log,'About to submit conc program1 POCEPOPSIPROC - Supplier Copy ');
        --
        vt_req_id2 := FND_REQUEST.SUBMIT_REQUEST (APPLICATION => 'POC'
                                                 ,PROGRAM     => 'POCEPOPSIPROC'
                                                 ,DESCRIPTION => 'DOT Custom PO - File Copy'
                                                 ,ARGUMENT1   => p_po_header_id
                                                 ,ARGUMENT2   => '1');
        --
        commit;
        --
        fnd_file.put_line(fnd_file.log,'Back from submitting conc prog.  Status: '||vt_req_id2);
        --
     ELSE -- This is for the new PO enhancement for DOI orgs where only 1 program is fired
       fnd_file.put_line(fnd_file.log,'About to submit conc program POCEPOXML ');
       
       lv_option_return := fnd_request.add_layout(template_appl_name      => lv_app_short_name,
                                                  template_code           => lv_templ_code,
                                                  template_language       => 'En',
                                                  template_territory      => 'US',
                                                  output_format           => 'PDF'
                                                  );
       
       
        vt_req_id1 := FND_REQUEST.SUBMIT_REQUEST (APPLICATION => 'POC'
                                                 ,PROGRAM     => 'POCEPOXML'
                                                 ,DESCRIPTION => ''
                                                 ,ARGUMENT1   => p_po_header_id
                                                 ,ARGUMENT2   => null);
        --
        commit;    
        fnd_file.put_line(fnd_file.log,'Back from submitting conc prog.  Status: '||vt_req_id1);
        
        vt_req_id2 := -99; -- Setting this value to avoid error as for 
        
     END IF;
     if ((vt_req_id1 != 0) or (vt_req_id2 != 0)) then
          --
          retcode := vv_conc_success;
          --
     else
          --
          retcode := vv_conc_error;
     end if;
     --
     fnd_file.put_line(fnd_file.log,'Returning status: '||retcode);
     --
EXCEPTION
     WHEN OTHERS THEN
          --
          fnd_file.put_line(fnd_file.log,'Unexpected exception: '||sqlerrm);
          raise;
          --
END submit_po_print;

/****************************************************************************
**
**  Procedure:    update_action_history
**  Author:       Jon Bartlett (Red Rock) 19th November 2008
**  Purpose:      Used to implement functionality to prevent approver from
**                 rejecting notification without entering a reason.
**                 Based upon standard code:
**                   PO_WF_REQ_NOTIFICATION.UPDATE_ACTION_HISTORY
**
****************************************************************************/
PROCEDURE update_action_history (p_action_code         IN VARCHAR2,
                              p_recipient_id           IN NUMBER,
                              p_note                   IN VARCHAR2,
                              p_req_header_id          IN NUMBER)
IS
     --
     pragma AUTONOMOUS_TRANSACTION;
     --
     l_progress               VARCHAR2(100) := '000';
     --
     l_employee_id            PO_ACTION_HISTORY.EMPLOYEE_ID%TYPE;
     l_object_sub_type_code   PO_ACTION_HISTORY.OBJECT_SUB_TYPE_CODE%TYPE;
     l_sequence_num           PO_ACTION_HISTORY.SEQUENCE_NUM%TYPE;
     l_object_revision_num    PO_ACTION_HISTORY.OBJECT_REVISION_NUM%TYPE;
     l_approval_path_id       PO_ACTION_HISTORY.APPROVAL_PATH_ID%TYPE;
     l_request_id             PO_ACTION_HISTORY.REQUEST_ID%TYPE;
     l_program_application_id PO_ACTION_HISTORY.PROGRAM_APPLICATION_ID%TYPE;
     l_program_date           PO_ACTION_HISTORY.PROGRAM_DATE%TYPE;
     l_program_id             PO_ACTION_HISTORY.PROGRAM_ID%TYPE;
     --
begin
     --
     SELECT max(sequence_num)
     INTO   l_sequence_num
     FROM   PO_ACTION_HISTORY
     WHERE  object_type_code = 'REQUISITION'
       AND  object_id = p_req_header_id;
     --
     SELECT employee_id
     ,      object_sub_type_code
     ,      object_revision_num
     ,      approval_path_id
     ,      request_id
     ,      program_application_id
     ,      program_date
     ,      program_id
     INTO   l_employee_id
     ,      l_object_sub_type_code
     ,      l_object_revision_num
     ,      l_approval_path_id
     ,      l_request_id
     ,      l_program_application_id
     ,      l_program_date
     ,      l_program_id
     FROM   PO_ACTION_HISTORY
     WHERE  object_type_code = 'REQUISITION'
       AND  object_id        = p_req_header_id
       AND  sequence_num     = l_sequence_num;
     --
     l_progress := '010';
     --
     po_forward_sv1.update_action_history (p_req_header_id
                                          ,'REQUISITION'
                                          ,l_employee_id
                                          ,p_action_code
                                          ,p_note
                                          ,fnd_global.user_id
                                          ,fnd_global.login_id);
     --
     l_progress := '020';
     --
     po_forward_sv1.insert_action_history (p_req_header_id
                                          ,'REQUISITION'
                                          ,l_object_sub_type_code
                                          ,l_sequence_num + 1
                                          ,NULL
                                          ,NULL
                                          ,p_recipient_id
                                          ,l_approval_path_id
                                          ,NULL
                                          ,l_object_revision_num
                                          ,NULL                  /* offline_code */
		                                      ,l_request_id
                                          ,l_program_application_id
		                                      ,l_program_id
		                                      ,l_program_date
		                                      ,fnd_global.user_id
                                          ,fnd_global.login_id);
     --
     l_progress := '030';
     --
     commit;
     --
EXCEPTION
     --
     WHEN OTHERS THEN
          --
          wf_core.context('POC_IP5_CUSTOM','update_action_history',l_progress,sqlerrm);
          RAISE;
end update_action_history;

/****************************************************************************
**
**  Procedure:    post_approval_notif
**  Author:       Jon Bartlett (Red Rock) 19th November 2008
**  Purpose:      Used to implement functionality to prevent approver from
**                 rejecting notification without entering a reason.
**                 Based upon standard code:
**                   PO_WF_REQ_NOTIFICATION.POST_APPROVAL_NOTIF
**
****************************************************************************/
PROCEDURE post_approval_notif(itemtype   in varchar2,
                              itemkey    in varchar2,
                              actid      in number,
                              funcmode   in varchar2,
                              resultout  out NOCOPY varchar2) is
     --
     l_nid number;
     l_forwardTo varchar2(240);
     l_result varchar2(100);
     l_forward_to_username_response varchar2(240) :='';
     l_req_header_id      po_requisition_headers.requisition_header_id%TYPE;
     l_action             po_action_history.action_code%TYPE;
     l_new_recipient_id   wf_roles.orig_system_id%TYPE;
     l_origsys            wf_roles.orig_system%TYPE;
     --
     vv_reason_text       varchar2(4000);
     --
begin
     --
     if (funcmode IN  ('FORWARD', 'QUESTION', 'ANSWER')) then
          --
          if (funcmode = 'FORWARD') then
               --
               l_action := 'DELEGATE';
               --
          elsif (funcmode = 'QUESTION') then
               --
               l_action := 'QUESTION';
               --
          elsif (funcmode = 'ANSWER') then
               --
               l_action := 'ANSWER';
               --
          end if;
          --
          l_req_header_id := wf_engine.GetItemAttrNumber
                                      (itemtype   => itemtype
                                      ,itemkey    => itemkey
                                      ,aname      => 'DOCUMENT_ID');
          --
          Wf_Directory.GetRoleOrigSysInfo(WF_ENGINE.CONTEXT_NEW_ROLE
                                         ,l_origsys
                                         ,l_new_recipient_id);
          --
          update_action_history (p_action_code   => l_action
                                ,p_recipient_id  => l_new_recipient_id
                                ,p_note          => WF_ENGINE.CONTEXT_USER_COMMENT
                                ,p_req_header_id => l_req_header_id);
          --
          resultout := wf_engine.eng_completed || ':' || wf_engine.eng_null;
          --
          return;
          --
     end if;
     --
     if (funcmode = 'RESPOND') then
          --
          l_nid := WF_ENGINE.context_nid;
          --
          l_result := wf_notification.GetAttrText(l_nid, 'RESULT');
          --
          if((l_result = 'FORWARD') or (l_result = 'APPROVE_AND_FORWARD')) then
               --
               l_forwardTo := wf_notification.GetAttrText(l_nid, 'FORWARD_TO_USERNAME_RESPONSE');
               --
               l_forward_to_username_response := wf_engine.GetItemAttrText (itemtype => itemtype
                                                                           ,itemkey  => itemkey
                                                                           ,aname    => 'FORWARD_TO_USERNAME_RESPONSE');
               --
               if(l_forwardTo is null) then
                    --
                    fnd_message.set_name('ICX', 'ICX_POR_WF_NOTIF_NO_USER');
                    app_exception.raise_exception;
                    --
               end if;
               --
          end if;
          --
          -- custom DOT code to prevent REJECT response without entering a reason.
          if (l_result = 'REJECT') then
               --
               vv_reason_text := wf_notification.GetAttrText(wf_engine.context_nid,'NOTE');
               --
               if ((length(vv_reason_text) < 1)
                or (vv_reason_text is null))
               then
                    --
                    fnd_message.set_name('ICXC', 'POC_POREQCHA_REJECT_NO_NOTE');
                    app_exception.raise_exception;
                    --
               end if;
               --
          end if;
          --
          resultout := wf_engine.eng_completed || ':' || wf_engine.eng_null;
          return;
          --
     end if;
     --
     -- Don't allow transfer
     if (funcmode = 'TRANSFER') then
          --
          fnd_message.set_name('PO', 'PO_WF_NOTIF_NO_TRANSFER');
          app_exception.raise_exception;
          resultout := wf_engine.eng_completed;
          --
          return;
          --
     end if; -- end if for funcmode = 'TRANSFER'
     --
end post_approval_notif;
--
/****************************************************************************
**
**  Function:    get_serv_req_sup_count
**  Author:      Jon Bartlett (Red Rock) 25th March 2009
**  Purpose:     Returns count of suggested suppliers/contactors for a
**                 service requisition line.
**
****************************************************************************/
FUNCTION get_serv_req_sup_count (pt_requisition_line_id in po_requisition_lines.requisition_line_id%type)
RETURN number
IS
     --
     vn_sup_count  number;
     --
BEGIN
     --
     select count(*)
     into   vn_sup_count
     from   po_requisition_suppliers prs
     where  prs.requisition_line_id = pt_requisition_line_id;
     --
     return (vn_sup_count);
     --
END get_serv_req_sup_count;
--
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
RETURN po_vendors.vendor_name%type
IS
     --
     vt_vendor_name    po_vendors.vendor_name%type;
     vn_sug_sup_count  number;
     --
BEGIN
     --
     vn_sug_sup_count := get_serv_req_sup_count(pt_requisition_line_id);
     --
     if (vn_sug_sup_count = 1) then
          --
          SELECT pv.vendor_name
          INTO   vt_vendor_name
          FROM   po_requisition_suppliers   prs
          ,      po_vendors                 pv
          WHERE  prs.vendor_id            = pv.vendor_id
            AND  prs.requisition_line_id  = pt_requisition_line_id;
          --
     elsif (vn_sug_sup_count > 1) then
          --
          vt_vendor_name := fnd_message.get_string('ICXC','POC_REQAPPRV_MULTIPLE_SUP_TEXT');
          --
     else
          -- no suggested supplier found, attempt to fetch from other Req Line.
          --   Expense Service Req lines have no suggested Vendor + Contractor info
          --    but DOT require this to be displayed on the line.
          SELECT pv.vendor_name
          INTO   vt_vendor_name
          FROM   po_requisition_lines_all    prl1
          ,      po_requisition_headers_all  prh
          ,      po_requisition_lines_all    prl2
          ,      po_requisition_suppliers    prs
          ,      po_vendors                  pv
          WHERE  prl1.requisition_line_id         = pt_requisition_line_id
            AND  prl1.requisition_header_id       = prh.requisition_header_id
            AND  prh.requisition_header_id        = prl2.requisition_header_id
            AND  prl2.requisition_line_id         = prs.requisition_line_id
            AND  prs.vendor_id                    = pv.vendor_id
            AND  prl2.contractor_requisition_flag = 'Y'
            AND    ROWNUM                         < 2;
          --
     end if;
     --
     return (vt_vendor_name);
     --
EXCEPTION
WHEN OTHERS THEN
     --
     return (null);
     --
END get_serv_req_supplier;


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
RETURN po_vendor_sites.vendor_site_code%type
IS
     --
     vt_vendor_site_name  varchar2(50);
     vn_sug_sup_count     number;
     --
BEGIN
     --
     vn_sug_sup_count := get_serv_req_sup_count(pt_requisition_line_id);
     --
     if (vn_sug_sup_count = 1) then
          --
          SELECT pvs.vendor_site_code
          INTO   vt_vendor_site_name
          FROM   po_requisition_suppliers   prs
          ,      po_vendor_sites_all        pvs
          WHERE  prs.vendor_site_id       = pvs.vendor_site_id
            AND  prs.requisition_line_id  = pt_requisition_line_id
            AND  ROWNUM                   < 2;
          --
     elsif (vn_sug_sup_count > 1) then
          --
          vt_vendor_site_name := fnd_message.get_string('ICXC','POC_REQAPPRV_MULTIPLE_SUP_TEXT');
          --
     else
          -- no suggested supplier found, attempt to fetch from other Req Line.
          --   Expense Service Req lines have no suggested Vendor + Contractor info
          --    but DOT require this to be displayed on the line.
          SELECT pvs.vendor_site_code
          INTO   vt_vendor_site_name
          FROM   po_requisition_lines_all    prl1
          ,      po_requisition_headers_all  prh
          ,      po_requisition_lines_all    prl2
          ,      po_requisition_suppliers    prs
          ,      po_vendor_sites_all         pvs
          WHERE  prl1.requisition_line_id         = pt_requisition_line_id
            AND  prl1.requisition_header_id       = prh.requisition_header_id
            AND  prh.requisition_header_id        = prl2.requisition_header_id
            AND  prl2.requisition_line_id         = prs.requisition_line_id
            AND  prs.vendor_site_id               = pvs.vendor_site_id
            AND  prl2.contractor_requisition_flag = 'Y'
            AND  ROWNUM                           < 2;
          --
     end if;
     --
     return (vt_vendor_site_name);
     --
EXCEPTION
WHEN OTHERS THEN
     --
     return (null);
     --
END get_serv_req_supplier_site;

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
RETURN per_people_f.full_name%type
IS
     --
     vt_contractor_name  per_people_f.full_name%type;
     vn_sug_sup_count    number;
     --
BEGIN
     --
     vn_sug_sup_count := get_serv_req_sup_count(pt_requisition_line_id);
     --
     if (vn_sug_sup_count = 1) then
          --
          SELECT PO_POAPPROVAL_INIT1.Get_Formatted_Full_Name(prs.candidate_first_name, prs.candidate_last_name)
          INTO   vt_contractor_name
          FROM   po_requisition_suppliers   prs
          WHERE  prs.requisition_line_id  = pt_requisition_line_id
            AND  ROWNUM                   < 2;
          --
     elsif (vn_sug_sup_count > 1) then
          --
          vt_contractor_name := fnd_message.get_string('ICXC','POC_REQAPPRV_MULTIPLE_SUP_TEXT');
          --
     else
          -- no suggested contractor found, attempt to fetch from other Req Line.
          --   Expense Service Req lines have no suggested Vendor + Contractor info
          --    but DOT require this to be displayed on the line.
          SELECT PO_POAPPROVAL_INIT1.Get_Formatted_Full_Name(prs.candidate_first_name, prs.candidate_last_name)
          INTO   vt_contractor_name
          FROM   po_requisition_lines_all    prl1
          ,      po_requisition_headers_all  prh
          ,      po_requisition_lines_all    prl2
          ,      po_requisition_suppliers    prs
          WHERE  prl1.requisition_line_id         = pt_requisition_line_id
            AND  prl1.requisition_header_id       = prh.requisition_header_id
            AND  prh.requisition_header_id        = prl2.requisition_header_id
            AND  prl2.requisition_line_id         = prs.requisition_line_id
            AND  prl2.contractor_requisition_flag = 'Y'
            AND  ROWNUM                           < 2;
          --
     end if;
     --
     return (vt_contractor_name);
     --
EXCEPTION
WHEN OTHERS THEN
     --
     return (null);
     --
END get_serv_req_contractor;

/****************************************************************************
**
**  Function:    get_serv_req_start_date
**  Author:      Jon Bartlett (Red Rock) 25th March 2009
**  Purpose:     Returns suggested contractor start date for a Service Requisition.
**
****************************************************************************/
FUNCTION get_serv_req_start_date (pt_requisition_line_id in po_requisition_lines.requisition_line_id%type)
RETURN po_requisition_lines.assignment_start_date%type
IS
     --
     vt_start_date  po_requisition_lines.assignment_start_date%type;
     --
BEGIN
     --
     -- no start date on current req line, attempt to fetch from other Req Line.
     --   Expense Service Req lines have no suggested Vendor + Contractor info
     --   but DOT require this to be displayed on the line.
     SELECT prl2.assignment_start_date
     INTO   vt_start_date
     FROM   po_requisition_lines_all    prl1
     ,      po_requisition_headers_all  prh
     ,      po_requisition_lines_all    prl2
     WHERE  prl1.requisition_line_id         = pt_requisition_line_id
       AND  prl1.requisition_header_id       = prh.requisition_header_id
       AND  prh.requisition_header_id        = prl2.requisition_header_id
       AND  prl2.contractor_requisition_flag = 'Y'
       AND  ROWNUM                           < 2;
     --
     return (vt_start_date);
     --
EXCEPTION
WHEN OTHERS THEN
     --
     return (null);
     --
END get_serv_req_start_date;


/****************************************************************************
**
**  Function:    get_serv_req_end_date
**  Author:      Jon Bartlett (Red Rock) 25th March 2009
**  Purpose:     Returns suggested contractor start date for a Service Requisition.
**
****************************************************************************/
FUNCTION get_serv_req_end_date (pt_requisition_line_id in po_requisition_lines.requisition_line_id%type)
RETURN po_requisition_lines.assignment_end_date%type
IS
     --
     vt_end_date  po_requisition_lines.assignment_end_date%type;
     --
BEGIN
     --
     -- no end date on current req line, attempt to fetch from other Req Line.
     --   Expense Service Req lines have no suggested Vendor + Contractor info
     --   but DOT require this to be displayed on the line.
     SELECT prl2.assignment_end_date
     INTO   vt_end_date
     FROM   po_requisition_lines_all    prl1
     ,      po_requisition_headers_all  prh
     ,      po_requisition_lines_all    prl2
     WHERE  prl1.requisition_line_id         = pt_requisition_line_id
       AND  prl1.requisition_header_id       = prh.requisition_header_id
       AND  prh.requisition_header_id        = prl2.requisition_header_id
       AND  prl2.contractor_requisition_flag = 'Y'
       AND  ROWNUM                           < 2;
     --
     return (vt_end_date);
     --
EXCEPTION
WHEN OTHERS THEN
     --
     return (null);
     --
END get_serv_req_end_date;

-------------------------------------------------------
-- FUNCTION
--     IS_PO_PRINT_ENHANCED
-- Purpose
--     Returns Y if the tag of the org in the lookup XXDOI_POC_PO_PRINT_PROGRAMS is NEW and N Otherwise
-------------------------------------------------------
FUNCTION is_po_print_enhanced
(
   p_org_id      IN NUMBER
)         
RETURN VARCHAR2
IS
   CURSOR get_po_enhanced IS
      SELECT CASE WHEN UPPER(flv.tag) = 'NEW' THEN 'Y' ELSE 'N' END po_enhanced
      FROM 
             hr_operating_units hou,
             fnd_lookup_values flv
      WHERE
             flv.lookup_code = hou.name
      AND    flv.lookup_type = 'XXDOI_POC_PO_PRINT_PROGRAMS'
      AND    organization_id = p_org_id;  
      
   lv_po_enhanced              VARCHAR2(2000) ;  
   
BEGIN
   OPEN  get_po_enhanced;
   FETCH get_po_enhanced into lv_po_enhanced;
   CLOSE get_po_enhanced;
   
   RETURN nvl(lv_po_enhanced,'N');
   
EXCEPTION 
   WHEN OTHERS THEN
      RETURN 'N';   
END is_po_print_enhanced; 

PROCEDURE submit_po_appr_notif (ERRBUF         OUT VARCHAR2,
                                RETCODE        OUT VARCHAR2,
                                p_po_header_id IN  VARCHAR2,
                                p_email_address IN VARCHAR2
                           )
IS
   vv_conc_error              varchar2(1) := '2';
   vv_conc_success            varchar2(1) := '0';
   lv_po_enhanced             varchar2(10) := 'N';
   lv_app_short_name          varchar2(10) := 'POC';
   lv_templ_code              varchar2(10) := 'POCEPOXML';
   lv_email_templ_code        varchar2(100) := 'POCNOTIF_EMAIL';
   lv_option_return           boolean;
   srs_wait                   BOOLEAN;
   srs_phase                  VARCHAR2(30);
   srs_status                 VARCHAR2(30);
   srs_dev_phase              VARCHAR2(30);
   srs_dev_status             VARCHAR2(30);
   srs_message                VARCHAR2(240);
   ln_request_id              NUMBER;
   lv_completion_text         fnd_concurrent_requests.completion_text%TYPE;  
   lv_po_number               po_headers_all.segment1%TYPE;
   lv_file_name               VARCHAR2(240);
   lv_user_name               VARCHAR2(240);
   
   CURSOR get_po_number IS
      SELECT segment1,fu.user_name
      FROM   po_headers_all pha,
             fnd_user fu
      WHERE  pha.po_header_id = p_po_header_id
      AND    pha.created_by = fu.user_id;
   
BEGIN
  OPEN  get_po_number;
  FETCH get_po_number INTO lv_po_number,lv_user_name;
  CLOSE get_po_number;
  
   IF nvl(lv_user_name ,'X') <> 'CONVERSION' THEN -- Fix Added by Joy Pinto on 21-Aug-2017 to ensure that Emails and PO Docs are not fired during Migration
   
      fnd_file.put_line(fnd_file.log,'About to submit conc program POCEPOXML ');
       
      lv_option_return := fnd_request.add_layout(template_appl_name      => lv_app_short_name,
                                              template_code           => lv_templ_code,
                                              template_language       => 'En',
                                              template_territory      => 'US',
                                              output_format           => 'PDF'
                                              );
       
       
      ln_request_id := FND_REQUEST.SUBMIT_REQUEST (APPLICATION => lv_app_short_name
                                                ,PROGRAM     => lv_templ_code
                                                ,DESCRIPTION => ''
                                                ,ARGUMENT1   => p_po_header_id
                                                ,ARGUMENT2   => null);
       --
      commit;   
      lv_file_name := lv_templ_code||'_'||ln_request_id||'_1.PDF'; -- This is the name of the PDF file generated on the server
    
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
                                              
      IF NOT (srs_dev_phase = 'COMPLETE' AND
                   (srs_dev_status = 'NORMAL' OR srs_dev_status = 'WARNING')) THEN
            SELECT completion_text
            INTO   lv_completion_text
            FROM   fnd_concurrent_requests
            WHERE  request_id = ln_request_id;
         
            fnd_file.put_line(fnd_file.log, lv_completion_text);
            fnd_file.put_line(fnd_file.log,'DEJTR Purchase Order Approval Notification program failed, Please refer to the log file of request ID '||ln_request_id);
            retcode := vv_conc_error;
      ELSE
            -- Success Send the email
            fnd_file.put_line(fnd_file.log, lv_completion_text);
            fnd_file.put_line(fnd_file.log,'DEJTR Purchase Order Approval Notification program completed successfully - request ID '||ln_request_id);

            ln_request_id := fnd_request.submit_request(lv_app_short_name,
                    				  lv_email_templ_code,
                    				  null,
                    				  null,
                    				  false,
                    				  lv_po_number,
                              p_email_address,
                              lv_file_name,
                    				  fnd_global.local_chr(0));
                              
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
                  fnd_file.put_line(fnd_file.log,'DEDJTR Purchase Order Approval Send Email program failed, Please refer to the log file of request ID '||ln_request_id);
                  retcode := vv_conc_error;      
               ELSE
                  fnd_file.put_line(fnd_file.log, lv_completion_text);
                  fnd_file.put_line(fnd_file.log,'DEDJTR Purchase Order Approval Send Email completed successfully - request ID '||ln_request_id);               
               END IF;
      END IF;  
   ELSE
      fnd_file.put_line(fnd_file.log, 'Not running the PDF Doc generation and not sending Email as the Created user is CONVERSION');
   END IF;   -- End of Conversion
   
END submit_po_appr_notif;

END poc_ip5_custom;
/
