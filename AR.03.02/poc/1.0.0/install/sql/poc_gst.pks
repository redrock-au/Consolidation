create or replace package poc_gst is
/* $Header: svn://d02584/consolrepos/branches/AR.03.02/poc/1.0.0/install/sql/poc_gst.pks 1382 2017-07-03 00:49:40Z svnuser $ */
   /*
   ** NOTE: The PB_INCLUSIVE parameter works as follows:
   **       PB_INCLUSIVE = TRUE then return the total cost of
   **                           of goods
   **       PB_INCLUSIVE = FALSE then return the GST component
   **                         of the goods
   **       Eg: If Goods cost 100, and the tax rate is 10%
   **             if PB_INCLUSIVE is TRUE then
   **               110 is returned
   **             if PB_INCLUSIVE is FALSE then
   **                10 is returned
   **  Modifications
   **    13-MAY-02   Andrew McLeod   Modified c_get_tax_rate cursor to join
   **				po_line_locations_all to ap_tax_codes by
   **				tax_code_id, not tax_name
   */

   -- Performs the GST calculation
   -- NOTE: Pass the tax rate as the percentage
   --       ie: For 10% pass the value 10 (not 0.1)
   function gst(pn_amount     in number,
                pn_tax_rate   in number,
                pb_inclusive  in boolean)
   return number;
   --Allow function to be used in SELECT
   PRAGMA restrict_references(gst, wnds, wnps);



   -- Returns the amount of GST on a PO Line
   function gst_po(pn_po_header_id  in number,
                   pn_po_line_id    in number,
                   pb_inclusive     in boolean)
   return number;
   --Allow function to be used in SELECT
   PRAGMA restrict_references(gst_po, wnds, wnps);

   function gst_po_db(pn_po_header_id  in number,
                      pn_po_line_id    in number,
                      pv_inclusive     in varchar2)
   return number;
   --Allow function to be used in SELECT
   PRAGMA restrict_references(gst_po_db, wnds, wnps);

   -- Returns the GST on an amount for a PO line
   function gst_amount(pn_po_header_id  in number,
                       pn_po_line_id    in number,
                       pn_amount        in number,
                       pb_inclusive     in boolean := true)
   return number;
   --Allow function to be used in SELECT
   PRAGMA restrict_references(gst_amount, wnds, wnps);

   -- Returns the GST on an amount for a PO line
   function gst_amount_db(pn_po_header_id  in number,
                          pn_po_line_id    in number,
                          pn_amount        in number,
                          pv_inclusive     in varchar2)
   return number;
   --Allow function to be used in SELECT
   PRAGMA restrict_references(gst_amount_db, wnds, wnps);

end poc_gst;
/
