Utility to update PowerDNS A or AAAA record for a subdomain.

Usage: ./update_pdns.sh -s <subdomain> -d <domain> -a <apikey> -u <base_url> -i <IP> [-6]
  -u base_url: PowerDNS base URL like 'https://pdns.example.com:8081'.
  -a apikey: PowerDNS API key. This should be given as environment variable 'apikey'!
  -s subdomain: Subdomain to update. Use @ to configure the domain itself.
  -d domain: Domain to update.
  -i IP: IP address to set. If not given, the IP address will be autodetected using https://api64.ipify.org
  -c: use current IP address from ipify.org
  -6: Assign AAAA-record for IPv6 instead of IPv4 A-record.
  -t TTL: TTL for the record. Default is 600.
  -v verbose: check after update
