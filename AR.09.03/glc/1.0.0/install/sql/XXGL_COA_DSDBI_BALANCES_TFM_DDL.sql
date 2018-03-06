-- $Header :$

  CREATE TABLE fmsmgr.xxgl_coa_dsdbi_balances_tfm 
   (	record_id number, 
	actual_flag varchar2(5), 
	period_name varchar2(10), 
	old_code_combination_id number, 
	old_segment1 varchar2(15), 
	old_segment2 varchar2(15), 
	old_segment3 varchar2(15), 
	old_segment4 varchar2(15), 
	old_segment5 varchar2(15), 
	new_code_combination_id number, 
	new_segment1 varchar2(15), 
	new_segment2 varchar2(15), 
	new_segment3 varchar2(15), 
	new_segment4 varchar2(15), 
	new_segment5 varchar2(15), 
	new_segment6 varchar2(15), 
	new_segment7 varchar2(15), 
	reference1 varchar2(150), 
	reference2 varchar2(150), 
	reference4 varchar2(150), 
	reference5 varchar2(150), 
	reference10 varchar2(150), 
	close_balance_dr number, 
	close_balance_cr number, 
	currency_code varchar2(5), 
	group_id number, 
	status varchar2(60), 
	created_by number, 
	creation_date date, 
	last_updated_by number, 
	last_update_date date, 
	run_id number, 
	run_phase_id number
   );
   
CREATE SYNONYM xxgl_coa_dsdbi_balances_tfm FOR fmsmgr.xxgl_coa_dsdbi_balances_tfm;      
   