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

	procedure setenv_from_table (
		session_key						in				varchar2
		, rest_name						in				varchar2
		, table_name					in				varchar2
	)
	
	as

		l_stmt							varchar2(4000);
		type l_env_rec					is record (
											setting_name	varchar2(250)
											, setting_val	varchar2(4000)
										);
		type l_env_list					is table of l_env_rec;
		l_env_set						l_env_list;
	
	begin
	
		dbms_application_info.set_action('setenv_from_table');

		l_stmt := 'select setting_name, setting_val from ' || table_name || ' where session_key = :b1 and rest_name = :b2';

		execute immediate l_stmt
		bulk collect into l_env_set
		using session_key, rest_name;

		for i in 1..l_env_set.count loop
			setenv(l_env_set(i).setting_name, l_env_set(i).setting_val);
		end loop;
	
		dbms_application_info.set_action(null);
	
		exception
			when others then
				dbms_application_info.set_action(null);
				raise;
	
	end setenv_from_table;

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

	procedure setheader_from_table (
		session_key						in				varchar2
		, rest_name						in				varchar2
		, table_name					in				varchar2
	)
	
	as

		l_stmt							varchar2(4000);
		type l_env_rec					is record (
											header_name		varchar2(250)
											, header_val	varchar2(4000)
										);
		type l_env_list					is table of l_env_rec;
		l_env_set						l_env_list;
	
	begin
	
		dbms_application_info.set_action('setheader_from_table');

		l_stmt := 'select header_name, header_val from ' || table_name || ' where session_key = :b1 and rest_name = :b2';

		execute immediate l_stmt
		bulk collect into l_env_set
		using session_key, rest_name;

		for i in 1..l_env_set.count loop
			setenv(l_env_set(i).header_name, l_env_set(i).header_val);
		end loop;
	
		dbms_application_info.set_action(null);
	
		exception
			when others then
				dbms_application_info.set_action(null);
				raise;
	
	end setheader_from_table;

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

	procedure parse_response
	
	as
	
	begin
	
		dbms_application_info.set_action('parse_response');

		if upper(session_environment('response_expect_format')) = 'JSON' then
			if substr(rest_response.response_raw, 1 , 1) = '[' then
				rest_response.response_type := 'JSON_LIST';
				rest_response.response_json_list := json_list(rest_response.response_raw);
			else
				rest_response.response_type := 'JSON';
				rest_response.response_json := json(rest_response.response_raw);
			end if;
		end if;
	
		dbms_application_info.set_action(null);
	
		exception
			when others then
				dbms_application_info.set_action(null);
				raise;
	
	end parse_response;

	procedure rest_request (
		request_endpoint					in				varchar2
		, request_method					in				varchar2 default 'GET'
	)
	
	as

		l_request							utl_http.req;
		l_response							utl_http.resp;
		l_response_header_name				varchar2(4000);
		l_response_header_value				varchar2(4000);
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

		-- Check if the basic authentication setting is true
		-- and if it is, let us call the authentication procedure.
		-- Expect username and password to be available in basic_auth_username
		-- and basic_auth_password environment parameters.
		if upper(session_environment('use_basic_authentication')) = 'YES' then
			utl_http.set_authentication(
				r => l_request
				, username => session_environment('basic_auth_username')
				, password => session_environment('basic_auth_password')
				, scheme => 'Basic'
				, for_proxy => false
			);
		end if;

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

		-- Get the response codes from the response
		rest_response_status_code := l_response.status_code;
		rest_response_status_reason := l_response.reason_phrase;

		-- Collect all response headers, in case this is needed
		for i in 1..utl_http.get_header_count(r => l_response) loop
			utl_http.get_header(
				r => l_response
				, n => i
				, name => l_response_header_name
				, value => l_response_header_value
			);
			rest_response_headers(l_response_header_name) := l_response_header_value;
		end loop;

		-- Now we can collect the actual response.
		begin
			loop
				utl_http.read_text (
					r => l_response
					, data => l_response_piece
				);
				rest_response.response_raw := rest_response.response_raw || l_response_piece;
			end loop;

			exception
				when utl_http.end_of_body then
					null;
				when others then
					raise;
		end;

		-- So we are done with the communication. Let us make sure that we
		-- close the connection before we continue.
		utl_http.end_response(
			r => l_response
		);

		-- If the environment setting for fail on http error is set, we will throw exception.
		-- Otherwise, we will continue, and expect the return document to be the error message
		-- from the endpoint API
		if rest_response_status_code >= 400 then
			if upper(session_environment('throw_exception_on_http_error')) = 'YES' then
				raise_application_error(-20001, 'NINJA_REST - HTTP error encountered.');
			end if;
		end if;

		-- Next we check if autoparse is set. If it is, we parse the
		-- response based on the value of response_expect_format in the session environment.
		if upper(session_environment('response_autoparse')) = 'YES' then
			parse_response;
		end if;
	
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