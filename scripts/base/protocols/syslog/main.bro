##! Core script support for logging syslog messages.  This script represents 
##! one syslog message as one logged record.

@load ./consts

module Syslog;

export {
	redef enum Log::ID += { LOG };
	
	type Info: record {
		## Timestamp of when the syslog message was seen.
		ts:        time            &log;
		uid:       string          &log;
		id:        conn_id         &log;
		## Protocol over which the message was seen.
		proto:     transport_proto &log;
		## Syslog facility for the message.
		facility:  string          &log;
		## Syslog severity for the message.
		severity:  string          &log;
		## The plain text message.
		message:   string          &log;
	};
}

redef capture_filters += { ["syslog"] = "port 514" };
const ports = { 514/udp } &redef;
redef dpd_config += { [ANALYZER_SYSLOG_BINPAC] = [$ports = ports] };

redef likely_server_ports += { 514/udp };

redef record connection += {
	syslog: Info &optional;
};

event bro_init() &priority=5
	{
	Log::create_stream(Syslog::LOG, [$columns=Info]);
	}

event syslog_message(c: connection, facility: count, severity: count, msg: string) &priority=5
	{
	local info: Info;
	info$ts=network_time();
	info$uid=c$uid;
	info$id=c$id;
	info$proto=get_port_transport_proto(c$id$resp_p);
	info$facility=facility_codes[facility];
	info$severity=severity_codes[severity];
	info$message=msg;
	
	c$syslog = info;
	}

event syslog_message(c: connection, facility: count, severity: count, msg: string) &priority=-5
	{
	Log::write(Syslog::LOG, c$syslog);
	}
