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
		endpoint					varchar2(4000)
		, method					varchar2(100)
		, payload_json				json
	);

	type call_response is record (
		response_type				varchar2(200)
		, response_json				json
		, response_json_list		json_list
		, response_raw				clob
	);

	type text_arr is table of varchar2(4000) index by varchar2(250);

	-- Package globals
	session_environment				text_arr;
	rest_request					call_request;
	rest_request_headers			text_arr;
	rest_response					call_response;
	rest_response_status_code		pls_integer;
	rest_response_status_reason		varchar2(256);
	rest_response_headers			text_arr;

	/** Set a session environment variable
	* @author Morten Egan
	* @param variable_name The name of the variable we want to set
	* @param variable_value The value of the parameter
	*/
	procedure setenv (
		variable_name 					in				varchar2
		, variable_value				in				varchar2
	);

	/** Set session environment based on values in a table.
	* Expect the table to have the following columns: session_key, rest_name, setting_name, setting_val
	* @author Morten Egan
	* @param session_key The key that identifies the individual set of evironment settings that we need to set.
	* @param rest_name The name of the rest API that these settings are for.
	* @param table_name The name of the table that holds the settings
	*/
	procedure setenv_from_table (
		session_key						in				varchar2
		, rest_name						in				varchar2
		, table_name					in				varchar2
	);

	/** Set a request header and value
	* @author Morten Egan
	* @param header_name The name of the header
	* @param header_value The value of header to set
	*/
	procedure setheader (
		header_name						in				varchar2
		, header_value					in				varchar2
	);

	/** Set request headers based on values in a table.
	* Expect the table to have the following columns: session_key, rest_name, header_name, header_val
	* @author Morten Egan
	* @param session_key The key that identifies the individual set of request headers that we need to set.
	* @param rest_name The name of the rest API that these settings are for.
	* @param table_name The name of the table that holds the settings
	*/
	procedure setheader_from_table (
		session_key						in				varchar2
		, rest_name						in				varchar2
		, table_name					in				varchar2
	);

	/** We need to initiate the call, to clear and reset parameters
	* @author Morten Egan
	*/
	procedure init_rest;

	/** This is the procedure that does the API call
	* @author Morten Egan
	* @param request_endpoint The method we are calling
	* @param request_method GET, POST, UPDATE or DELETE method. Defaults to GET
	*/
	procedure rest_request (
		request_endpoint				in				varchar2
		, request_method				in				varchar2 default 'GET'
	);

	/*	Here we set the default environment settings
	*	We will try and set as many as possible
	*/
	-- Transport related parameters
	session_environment('transport_protocol') := 'https';
	session_environment('rest_host_port') := '443';
	session_environment('rest_uri_model') := '[transport_protocol]://[rest_host]:[rest_host_port]/[rest_api_name]/[rest_api_version]/[rest_api_method]';
	session_environment('max_redirects') := '1';
	session_environment('throw_exception_on_http_error') := 'no';
	session_environment('use_basic_authentication') := 'no';
	-- Response related parameters
	session_environment('response_autoparse') := 'YES';
	session_environment('response_expect_format') := 'JSON';

	/* Here we set standard headers */
	rest_request_headers('User-Agent') := 'rest-ninja/' || p_version;
	rest_request_headers('Content-Type') := 'application/json';

end ninja_rest;
/