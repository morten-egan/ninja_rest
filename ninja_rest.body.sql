create or replace package body ninja_rest

as

	procedure setenv (
		variable_name						in				varchar2
		, variable_value					in				varchar2
	)
	
	as
	
	begin
	
		dbms_application_info.set_action('setenv');

		session_environment(variable_name) := variable_value;
	
		dbms_application_info.set_action(null);
	
		exception
			when others then
				dbms_application_info.set_action(null);
				raise;
	
	end setenv;

	procedure setheader (
		header_name							in				varchar2
		, header_value						in				varchar2
	)
	
	as
	
	begin
	
		dbms_application_info.set_action('setheader');

		rest_request_headers(header_name) := header_value;
	
		dbms_application_info.set_action(null);
	
		exception
			when others then
				dbms_application_info.set_action(null);
				raise;
	
	end setheader;

	function build_rest_uri (
		request_endpoint					in				varchar2
	)
	return varchar2
	
	as
	
		l_ret_val							varchar2(4000);
		l_session_parm_idx					varchar2(250);
	
	begin
	
		dbms_application_info.set_action('build_rest_uri');

		-- Loop over all session_parameters, and replace values using the rest_uri_model
		-- parameter as the base string for replacement
		l_ret_val := session_environment('rest_uri_model');
		l_session_parm_idx := session_environment.first;
		while l_session_parm_idx is not null loop
			l_ret_val := replace(l_ret_val, '[' || l_session_parm_idx || ']', session_environment(l_session_parm_idx));
			session_environment.next(l_session_parm_idx);
		end loop;
	
		dbms_application_info.set_action(null);
	
		return l_ret_val;
	
		exception
			when others then
				dbms_application_info.set_action(null);
				raise;
	
	end build_rest_uri;

	procedure set_request_headers (
		request						in out				utl_http.req
	)
	
	as

		l_request_headers_idx		varchar2(250);
	
	begin
	
		dbms_application_info.set_action('set_request_headers');

		-- Set the registered headers
		l_request_headers_idx := rest_request_headers.first;
		while l_request_headers_idx is not null loop
			utl_http.set_header(
				r => request
				, name => l_request_headers_idx
				, value => rest_request_headers(l_request_headers_idx)
			);
		end loop;

		-- Final header to set is the content-length
		utl_http.set_header(
			r => request
			, name => 'Content-Length'
			, value => length(rest_request.payload_json.to_char)
		);
	
		dbms_application_info.set_action(null);
	
		exception
			when others then
				dbms_application_info.set_action(null);
				raise;
	
	end set_request_headers;

	procedure init_rest
	
	as
	
	begin
	
		dbms_application_info.set_action('init_rest');

		rest_request.payload_json := json();
	
		dbms_application_info.set_action(null);
	
		exception
			when others then
				dbms_application_info.set_action(null);
				raise;
	
	end init_rest;

	procedure rest_request (
		request_endpoint					in				varchar2
		, request_method					in				varchar2 default 'GET'
	)
	
	as

		l_request							utl_http.req;
		l_response							utl_http.resp;
		l_response_piece					varchar2(32000);

		rest_communication_error			exception;
		pragma								exception_init(rest_communication_error, -20001);
	
	begin
	
		dbms_application_info.set_action('rest_request');

		-- Set detailed error and exception support for http packages
		utl_http.set_response_error_check(
			enable => true
		);
		utl_http.set_detailed_excp_support(
			enable => true
		);

		-- The first thing we do when we get called is reset result variables.
		rest_response.response_type := 'JSON';
		rest_response.response_json := json();
		rest_response.response_json_list := json_list();
		rest_response.response_clob := '';

		-- Check if request protocol is set
		if session_environment('transport_protocol') is not null then
			-- Protocol is set, check if http or https
			-- In case of https, check and set wallet parameters
			if session_environment('transport_protocol') = 'https' then
				utl_http.set_wallet(
					session_environment('wallet_location')
					, session_environment('wallet_password')
				);
			end if;
		else
			-- Protocol not set, raise error
			raise_application_error(-20001, 'NINJA_REST - Transport protocol is not set or invalid.');
		end if;

		-- Set follow redirects
		utl_http.set_follow_redirect (
			max_redirects => session_environment('max_redirects')
		);

		-- Now we start the URI endpoint translation and definition.
		-- First we check if rest_request.endpoint is set manually.
		-- If it is, we expect that this is because the complete endpoint
		-- has been set. No translation will be done.
		if rest_request.endpoint is null then
			-- We need to create the URI
			rest_request.endpoint := build_rest_uri(request_endpoint);
		end if;

		-- We need to set the method if not already done
		if rest_request.method is null then
			rest_request.method := request_method;
		end if;

		-- Now that the URI is built, let us open the request.
		-- Only fully URIs are expected
		l_request := utl_http.begin_request(
			url => rest_request.endpoint
			, method => rest_request.method
		);

		-- Once the request is open, we can set the headers
		set_request_headers (
			request => l_request
		);

		-- After headers, we sent the content of the payload
		utl_http.write_text (
			r => l_request
			, data => rest_request.payload_json.to_char
		);

		-- Now we can get the response
		l_response := utl_http.get_response (
			r => l_request
		);
	
		dbms_application_info.set_action(null);
	
		exception
			when others then
				dbms_application_info.set_action(null);
				raise;
	
	end rest_request;

begin

	dbms_application_info.set_client_info('ninja_rest');
	dbms_session.set_identifier('ninja_rest');

end ninja_rest;
/