Utility to update PowerDNS A or AAAA record for a subdomain.

Usage: ./update_pdns.sh -s <PDNS_SUBDOMAIN> -d <PDNS_DOMAIN> -a <PDNS_APIKEY> -u <PDNS_BASE_URL> -i <PDNS_HOST_IP> [-6]
  -u PDNS_BASE_URL: PowerDNS base URL like 'https://pdns.example.com:8081'.
  -a PDNS_APIKEY: PowerDNS API key. This should be given as environment variable 'PDNS_APIKEY'!
  -s PDNS_SUBDOMAIN: PDNS_SUBDOMAIN to update. Use @ to configure the domain itself.
  -d PDNS_DOMAIN: Domain to update.
  -i PDNS_HOST_IP: IP address to set. If not given, the IP address will be autodetected using https://api64.ipify.org
  -c: use current IP address from ipify.org
  -6: Assign AAAA-record for IPv6 instead of IPv4 A-record.
  -t TTL: TTL for the record. Default is 600.
  -v verbose: check after update

All parameters can also be set as environment variables.