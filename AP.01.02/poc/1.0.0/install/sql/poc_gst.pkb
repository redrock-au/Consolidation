create or replace package body poc_gst is
/* $Header: svn://d02584/consolrepos/branches/AP.01.02/poc/1.0.0/install/sql/poc_gst.pkb 1368 2017-07-02 23:54:39Z svnuser $ */

   -- Get tax rate for a PO line
   cursor c_get_tax_rate(pn_po_header_id   number,
                         pn_po_line_id     number) is (
      select
         t.tax_rate
      from
         po_line_locations_all l,
         ap_tax_codes t
      where l.taxable_flag = 'Y'
      and l.po_header_id = pn_po_header_id
      and l.po_line_id = pn_po_line_id
      and t.tax_id = l.tax_code_id);

   function to_boolean(pv_bool_text in varchar2) return boolean is
   begin
      if pv_bool_text = 'INC' or
         pv_bool_text = 'TRUE' then
         return true;
      elsif pv_bool_text = 'EXC' or
            pv_bool_text = 'FALSE' then
         return false;
      else
         raise program_error;
      end if;
   end to_boolean;

------------------------------------------------------------------------------
   -- Performs the GST calculation
   function gst(pn_amount     in number,
                pn_tax_rate   in number,
                pb_inclusive  in boolean)
   return number is
      vn_include_amount  number := 0;
      vn_return_amount   number := 0;
   begin
      if pb_inclusive then
         vn_include_amount := pn_amount;
      end if;

      if pn_tax_rate != 0 then
         vn_return_amount := (pn_amount * pn_tax_rate / 100) + vn_include_amount;
      else
         vn_return_amount := vn_include_amount;
      end if;

      return vn_return_amount;
   end gst;

------------------------------------------------------------------------------
   -- Returns the GST on an amount for a PO line
   function gst_amount(pn_po_header_id  in number,
                       pn_po_line_id    in number,
                       pn_amount        in number,
                       pb_inclusive     in boolean)
   return number is
      v_tax_rate        ap_tax_codes.tax_rate%type;
      vn_return_amount  number := 0;
   begin
      -- Get the GST rate for the line
      open c_get_tax_rate(pn_po_header_id, pn_po_line_id);
      fetch c_get_tax_rate into v_tax_rate;

      if c_get_tax_rate%found then
         -- Calculate the amount of GST
         vn_return_amount := gst(pn_amount, v_tax_rate, pb_inclusive);
      else
         vn_return_amount := gst(pn_amount, 0, pb_inclusive);
      end if;

      close c_get_tax_rate;

      return vn_return_amount;
   end gst_amount;

------------------------------------------------------------------------------
   function gst_amount_db(pn_po_header_id  in number,
                          pn_po_line_id    in number,
                          pn_amount        in number,
                          pv_inclusive     in varchar2)
   return number is
   begin
      return gst_amount(pn_po_header_id, pn_po_line_id, pn_amount, to_boolean(pv_inclusive));
   end gst_amount_db;

------------------------------------------------------------------------------
   -- Returns the amount of GST on a PO Line
   function gst_po(pn_po_header_id  in number,
                   pn_po_line_id    in number,
                   pb_inclusive     in boolean)
   return number is
      vn_line_amount     number := 0;
      vn_return_amount   number := 0;
   begin
      select nvl(unit_price,0) * nvl(quantity,0)
      into vn_line_amount
      from po_lines
      where po_line_id = pn_po_line_id;

      vn_return_amount := gst_amount(pn_po_header_id,
                                     pn_po_line_id,
                                     vn_line_amount,
                                     pb_inclusive);

      return vn_return_amount;

   end gst_po;

------------------------------------------------------------------------------
   function gst_po_db(pn_po_header_id  in number,
                      pn_po_line_id    in number,
                      pv_inclusive     in varchar2)
   return number is
   begin
      return gst_po(pn_po_header_id, pn_po_line_id, to_boolean(pv_inclusive));
   end gst_po_db;


end poc_gst;
/
