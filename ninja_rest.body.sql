create or replace package body ninja_rest

as


begin

	dbms_application_info.set_client_info('ninja_rest');
	dbms_session.set_identifier('ninja_rest');

end ninja_rest;
/