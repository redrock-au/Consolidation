create or replace PACKAGE BODY POC_POAPPRV_WF AS
/* $Header: svn://d02584/consolrepos/branches/AP.03.01/poc/1.0.0/install/sql/POC_POAPPRV_WF.pkb 1371 2017-07-03 00:08:48Z svnuser $ */

FUNCTION PrintDocument(itemtype varchar2,
		       itemkey  varchar2) return varchar2;

FUNCTION Print_PO(p_doc_id        varchar2,
                  p_doc_num       varchar2,
                  p_email_address varchar2) RETURN number ;

FUNCTION generate_req_out_URL(req_id   IN NUMBER,
			      gwyuid   IN VARCHAR2,
			      two_task IN VARCHAR2,
			      lifetime IN NUMBER DEFAULT 1440) RETURN varchar2
IS
  base	     VARCHAR2(257);
  url	     VARCHAR2(512);
  fname      VARCHAR2(255);
  node       VARCHAR2(50);
  id	     VARCHAR2(32);
  mtype      VARCHAR2(80);
  fs_enabled VARCHAR2(2);
  pos        number;
  svc        varchar2(50);
BEGIN
   fnd_profile.get('APPS_WEB_AGENT', base);

   IF(base IS NULL) THEN
      RETURN NULL;
   END IF;

   SELECT fcr.outfile_name,
	  fcr.outfile_node_name,
	  fmt.mime_type
   INTO   fname,
	  node,
	  mtype
   FROM   fnd_concurrent_requests fcr,
	  fnd_mime_types_vl fmt
   WHERE  fcr.request_id = req_id
   AND    fcr.output_file_type = fmt.file_format_code
   AND    rownum = 1;

   if (fnd_profile.defined('FS_SVC_PREFIX')) then
     fnd_profile.get('FS_SVC_PREFIX', svc);

     if (svc is not null) then
       svc := substr(svc, 1, 9) || node;
     else
       svc := 'FNDFS_' || node;
     end if;
   else
     svc := 'FNDFS_' || node;
   end if;

   id := fnd_webfile.create_id(fname,
			       svc,
			       lifetime,
			       mtype,
			       req_id);

   base := Ltrim(Rtrim(base));

   -- Strip any file path from the base URL by truncating at the
   -- third '/'.
   -- This leaves us with something like 'http://ap363sun:8000'.

   pos := instr(base, '/', 1, 3);
   if (pos > 0) then
     base := substr(base, 1, pos - 1);
   end if;

   url := base || '/OA_CGI/FNDWRR.exe?' || 'temp_id=' || id || '&' ||
          'login=' || gwyuid || '@' || two_task;

   return url;

END generate_req_out_URL;

PROCEDURE Print_Document(itemtype  in varchar2,
                         itemkey   in varchar2,
                         actid     in number,
                         funcmode  in varchar2,
                         resultout out varchar2    ) is
  l_orgid       number;
  l_print_doc   varchar2(2);
  x_progress    varchar2(300);
  l_doc_string varchar2(200);
  l_preparer_user_name varchar2(100);
BEGIN
  x_progress := 'POC_DOC_NOTIFICATION.Print_Document: 01';
  /* DEBUG */  PO_WF_DEBUG_PKG.insert_debug(itemtype,itemkey,x_progress);

  -- Do nothing in cancel or timeout mode
  if (funcmode <> wf_engine.eng_run) then
      resultout := wf_engine.eng_null;
      return;
  end if;

  l_orgid := wf_engine.GetItemAttrNumber (itemtype => itemtype,
                                          itemkey  => itemkey,
                                          aname    => 'ORG_ID');

  IF l_orgid is NOT NULL THEN
    fnd_client_info.set_org_context(to_char(l_orgid));
  END IF;

  x_progress := 'POC_DOC_NOTIFICATION.Print_Document: 02';
  resultout := wf_engine.eng_completed || ':' ||
               PrintDocument(itemtype,itemkey);
  -- resultout := wf_engine.eng_completed || ':' || 'ACTIVITY_PERFORMED' ;
  x_progress := 'POC_DOC_NOTIFICATION.Print_Document: 03';
EXCEPTION
  WHEN OTHERS THEN
    l_doc_string := PO_REQAPPROVAL_INIT1.get_error_doc(itemType, itemkey);
    l_preparer_user_name := PO_REQAPPROVAL_INIT1.get_preparer_user_name(itemType, itemkey);
    wf_core.context('POC_DOC_NOTIFICATION.Print_Document',x_progress);
    PO_REQAPPROVAL_INIT1.send_error_notif(itemType, itemkey, l_preparer_user_name, l_doc_string, sqlerrm, 'POC_DOC_NOTIFICATION.PRINT_DOCUMENT');
    raise;

END Print_Document;

FUNCTION PrintDocument(itemtype varchar2,
		       itemkey varchar2) return varchar2 is

  l_document_type   VARCHAR2(25);
  l_document_num    VARCHAR2(30);
  l_email_address   VARCHAR2(100);
  l_preparer_id     number;
  l_document_id     NUMBER;
  l_release_num     NUMBER;
  l_request_id      NUMBER := 0;
  l_qty_precision   VARCHAR2(30);
  l_user_id         VARCHAR2(30);
  x_progress        varchar2(200);
BEGIN
  x_progress := 'POC_DOC_NOTIFICATION.PrintDocument: 01';
  /* DEBUG */  PO_WF_DEBUG_PKG.insert_debug(itemtype,itemkey,x_progress);

   -- Get the profile option report_quantity_precision
   fnd_profile.get('REPORT_QUANTITY_PRECISION', l_qty_precision);

   -- Get the user id for the current user.  This information
   -- is used when sending concurrent request.
   FND_PROFILE.GET('USER_ID', l_user_id);

   -- Send the concurrent request to print document.
   l_document_type := wf_engine.GetItemAttrText (itemtype => itemtype,
                                         itemkey  => itemkey,
                                         aname    => 'DOCUMENT_TYPE');

   l_document_id := wf_engine.GetItemAttrNumber (itemtype => itemtype,
                                         itemkey  => itemkey,
                                         aname    => 'DOCUMENT_ID');

   l_document_num := wf_engine.GetItemAttrText (itemtype => itemtype,
                                         itemkey  => itemkey,
                                         aname    => 'DOCUMENT_NUMBER');

   l_preparer_id := wf_engine.GetItemAttrText (itemtype => itemtype,
                                         itemkey  => itemkey,
                                         aname    => 'PREPARER_ID');
   BEGIN
      select email_address
      into   l_email_address
      from   per_people_x
      where  person_id = l_preparer_id;
   EXCEPTION
     when NO_DATA_FOUND then
    	  l_email_address := '';
   END;

   if l_email_address is not null then
      l_request_id := Print_PO(l_document_id,
                               l_document_num,
		               l_email_address);

      wf_engine.SetItemAttrNumber (itemtype => itemtype,
                               itemkey  => itemkey,
                               aname    => 'CONCURRENT_REQUEST_ID',
                               avalue   => l_request_id);

      x_progress := 'POC_DOC_NOTIFICATION.PrintDocument: 02. request_id= ' || to_char(l_request_id);
	  return 'Y';
  else
      x_progress := 'POC_DOC_NOTIFICATION.PrintDocument: 02. Request Not Submitted ';
      return 'N';
  end if;
  /* DEBUG */  PO_WF_DEBUG_PKG.insert_debug(itemtype,itemkey,x_progress);
  return 'N';

EXCEPTION

   WHEN OTHERS THEN
        wf_core.context('POC_DOC_NOTIFICATION','PrintDocument',x_progress);
        raise;

END PrintDocument;


FUNCTION Print_PO(p_doc_id varchar2,
                  p_doc_num varchar2,
                  p_email_address varchar2) RETURN number is

   l_request_id number;
   x_progress varchar2(200);
   lv_po_enhanced      varchar2(10) := 'N';  

   CURSOR get_po_enhanced IS
     SELECT NVL(poc_ip5_custom.is_po_print_enhanced(org_id),'N')
     FROM   po_headers_all
     WHERE  po_header_id = p_doc_id;

BEGIN
   -- Added the below code by Joy Pinto on 15-June-2017
   OPEN get_po_enhanced;
   FETCH get_po_enhanced INTO lv_po_enhanced;
   CLOSE get_po_enhanced;
   
    if fnd_request.SET_PRINT_OPTIONS(copies => 0) then
       IF nvl(lv_po_enhanced,'N') = 'N' THEN -- Added by Joy Pinto for DOI PO Print Enhancements
          l_request_id := fnd_request.submit_request('POC',
                                                     'POCNOTIF',
                                                      null,
                                                      null,
                                                      false,
                                                      p_doc_id,
                                                      p_doc_num,
					                                            p_email_address,
                                                      fnd_global.local_chr(0)
                                                    );
       ELSE
          l_request_id := fnd_request.submit_request('POC',
                                                     'POCNOTIFXML', -- New Concurrent Program
                                                      null,
                                                      null,
                                                      false,
                                                      p_doc_id,
					                                            p_email_address,
                                                      fnd_global.local_chr(0)
                                                    );
       END IF; 
    else
       l_request_id := to_number('');
    end if;

    return(l_request_id);
EXCEPTION
   WHEN others THEN
        wf_core.context('POC_DOC_NOTIFICATION','Print_PO',x_progress);
        raise;
END Print_PO;

PROCEDURE set_document_url_attribute(itemtype     in varchar2,
                                     itemkey      in varchar2,
				     p_request_id in number,
				     p_attribute  in varchar2) is

  profbuf  varchar2(255);  /* buffer for profile value */
  outurl   varchar2(255);  /* URL for output */
  logurl   varchar2(255);  /* URL for log */
  twotask  varchar2(255);  /* two task of DB */
  gwyuid   varchar2(255);  /* GWYUID for DB */
  url_ttl  number;         /* Time to live for url - in minutes */
  ename    varchar2(30);   /* Error name returned by wf_core.get_error */
  wf_error exception;
begin
   FND_PROFILE.GET ('CONC_ATTACH_URL', profbuf);

   if profbuf = 'Y' then
     FND_PROFILE.GET ('CONC_URL_LIFETIME', profbuf);
     url_ttl := to_number(profbuf);

     /* Note, we must set a default value for url_ttl.        *
      * Stored procedure defaults only work for missing args, *
      * not for null args.                                    */
     if (url_ttl is null) then
       url_ttl := 10080;
     end if;

     FND_PROFILE.GET ('TWO_TASK', twotask);
     FND_PROFILE.GET ('GWYUID', gwyuid);

     outurl := generate_req_out_URL(p_request_id,gwyuid,twotask,url_ttl);

     wf_engine.SetItemAttrText (itemtype => itemtype,
     		                itemkey	=> itemkey,
    	            	        aname	=> p_attribute,
	    			avalue  => outurl);
   end if;

end;

Procedure IsDocGenerated(itemtype  in varchar2,
                         itemkey   in varchar2,
                         actid     in number,
                         funcmode  in varchar2,
                         resultout out varchar2) is

  x_request_id  number;
  x_request_id2 number;
  x_timeout_cnt number;
  x_phase       varchar2(80);
  x_status      varchar2(80);
  x_dev_phase   varchar2(80);
  x_dev_status  varchar2(80);
  x_message     varchar2(240);
  x_phase2      varchar2(80);
  x_status2     varchar2(80);
  x_dev_phase2  varchar2(80);
  x_dev_status2 varchar2(80);
  x_message2    varchar2(240);
BEGIN

 if funcmode = 'RUN' then

   x_request_id  := wf_engine.GetItemAttrNumber (
					  itemtype => itemtype,
                                          itemkey  => itemkey,
                                          aname    => 'CONCURRENT_REQUEST_ID');
   x_request_id2  := wf_engine.GetItemAttrNumber (
					  itemtype => itemtype,
                                          itemkey  => itemkey,
                                          aname    => 'CONCURRENT_REQUEST_ID2');
   x_timeout_cnt := wf_engine.GetItemAttrNumber (
					  itemtype => itemtype,
                                          itemkey  => itemkey,
                                          aname    => 'TIMEOUT_CNT');

   if FND_CONCURRENT.get_request_status(x_request_id,
		   	                'POC',
			                '',
	    		                x_phase,
			                x_status,
			                x_dev_phase,
			                x_dev_status,
			                x_message)
    and
       FND_CONCURRENT.get_request_status(x_request_id2,
   	                                 'POC',
			                 '',
	    		                 x_phase2,
			                 x_status2,
			                 x_dev_phase2,
			                 x_dev_status2,
			                 x_message2)     then
        if x_phase = 'Completed' and
	   x_phase2 = 'Completed' then
	   if x_status = 'Normal' and
	      x_status2 = 'Normal' then

	      set_document_url_attribute(itemtype,
                                         itemkey,
					 x_request_id,
					 'PO_DOC_URL');

	       set_document_url_attribute(itemtype,
                                          itemkey,
					  x_request_id2,
					  'PO_DOC_URL2');

               resultout := wf_engine.eng_completed || ':' ||  'Y';
	   else
	       resultout := wf_engine.eng_completed || ':' ||  'F';
	   end if;
	else
	   x_timeout_cnt := nvl(x_timeout_cnt, 0)+1;

	   if x_timeout_cnt > 10 then
	      resultout := wf_engine.eng_completed || ':' ||  'T';
           else
	      resultout := wf_engine.eng_completed || ':' ||  'N';

              wf_engine.SetItemAttrNumber(itemtype => itemtype,
                                          itemkey  => itemkey,
                                          aname    => 'TIMEOUT_CNT',
					   avalue   => x_timeout_cnt);
           end if;
        end if;
   else
       x_timeout_cnt := nvl(x_timeout_cnt, 0)+1;

       if x_timeout_cnt > 10 then
	  resultout := wf_engine.eng_completed || ':' ||  'T';
       else
	  resultout := wf_engine.eng_completed || ':' ||  'N';
          wf_engine.SetItemAttrNumber (itemtype => itemtype,
                                       itemkey  => itemkey,
                                       aname    => 'TIMEOUT_CNT',
		                       avalue   => x_timeout_cnt);
       end if;
   end if;
 else
    resultout := wf_engine.eng_completed || ':' ||  'N';
 end if;

END IsDocGenerated;
END  POC_POAPPRV_WF;
/
