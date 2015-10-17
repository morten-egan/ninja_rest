create or replace package ninja_rest

as

	/** NINJA REST - This is a package to handle most of the internals, when communicating with REST services
	* from the PL/SQL.
	* @author Morten Egan
	* @version 0.0.1
	* @project NINJA_REST
	*/
	p_version		varchar2(50) := '0.0.1';

	-- Type definitions
	type call_request is record (
		call_endpoint				varchar2(4000)
		, call_method				varchar2(100)
		, call_json					json
	);

	type call_response is record (
		result_type					varchar2(200)
		, result 					json
		, result_list				json_list
	);

	type text_arr is table of varchar2(4000) index by varchar2(250);

	-- Package globals
	session_environment				text_arr;
	rest_request					call_request;
	rest_response					call_response;
	rest_response_status_code		pls_integer;
	rest_response_status_reason		varchar2(256);
	rest_response_headers			text_arr;
	rest_raw_response				clob;

	-- Default environment settings
	session_environment('transport_protocol') := 'https';
	session_environment('rest_host_port') := '443';

end ninja_rest;
/