#!/bin/bash
set -e

TTL=600
RRTYPE=""
STATUS=""
RNAME=""
ERRFILE=$(mktemp)
DATFILE=$(mktemp)

clean_up () {
    ARG=$?
	if [ $ARG -ne 0 ]; then
		echo
		echo "$0 failed with status $ARG"
		echo "$0 Cleaning up and exiting..."
		rm -f $ERRFILE $DATFILE
	fi	
    exit $ARG
}

usage() {                                 # Function: Print a help message.
  echo
  echo "Utility to update PowerDNS A or AAAA record for a subdomain."
  echo
  echo "Usage: $0 -s <subdomain> -d <domain> -a <apikey> -u <base_url> -i <IP> [-6]" 
  echo "  -u base_url: PowerDNS base URL like 'https://pdns.example.com:8081'." 
  echo "  -a apikey: PowerDNS API key. This should be given as environment variable 'apikey'!"
  
  echo "  -s subdomain: Subdomain to update. Use @ to configure the domain itself." 
  echo "  -d domain: Domain to update." 
  echo "  -i IP: IP address to set. If not given, the IP address will be autodetected using https://api64.ipify.org" 
  echo "  -c: use current IP address from ipify.org" 
  echo "  -6: Assign AAAA-record for IPv6 instead of IPv4 A-record." 
  echo "  -t TTL: TTL for the record. Default is 600." 
  echo "  -v verbose: check after update"
}

exit_abnormal() {
  echo "For help use -h" 1>&2
  exit 1
}

validate_ipv4() {
	if [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	echo "IP is valid"
	else
	echo "IP is invalid: $1"
	exit 1
	fi
}

validate_ipv6() {
	# regex='^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$'
	regex='^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$'
  if [[ $1 =~ regex ]]; then
	echo "IPv6 is valid"
  else
	echo "IPv6 is invalid: $1"
	exit 1
  fi
}

trap clean_up EXIT

# If -h flag is passed, show usage and exit
if [ "$1" == "-h" ]; then
	usage
	exit 0
fi

[ -z "${apikey}" ] && echo && echo "API key should be passed as an environment variable 'apikey' for security reasons!" && echo
[ -z $(which jq) ] && usage && echo -e "\n\n'jq' command line tool is missing! Please install it first.\n" && exit 1

: ${verbose:=0}

while getopts "?:h:s:d:a:u:i:6:t:v" flag
do
	case "${flag}" in
		s) subdomain=${OPTARG} ;;
		d) domain=${OPTARG} ;;
		a) apikey=${OPTARG} ;;
		u) base_url=${OPTARG} ;;
		i) IP=${OPTARG} ;;
		6) use_ipv6=1 ;;
		t) TTL=${OPTARG} ;;
		v) verbose=${OPTARG} ;;
	esac
done

[ -z "$domain" ] && >&2 echo "Missing '-d domain' flag." && exit_abnormal
[ -z "$subdomain" ] && >&2 echo "Missing '-s subdomain' flag. Use @ to configure the domain itself." && exit_abnormal
[ -z "$IP" ] && echo "Missing '-i IP' flag. Autodeting IP address..."

[ -z "$base_url" ] && >&2 echo "Missing '-u base_Url' flag. This is PowerDNS base URL like 'https://pdns.example.com:8081'." && exit_abnormal
[ -z "$apikey" ] && >&2 echo "Missing '-a apikey' flag." && exit_abnormal

if [[ -z "$IP" && $use_ipv6 -eq 0 ]]; then
	IP=$(curl -s  https://api.ipify.org)
	echo "Using autodetected IP address: $IP"
fi

if [ -z "$IP" ] && [[ $use_ipv6 -ne 0 ]]; then
	IP=$(curl -s  https://api6.ipify.org)
	if [ -z "$IP" ]; then
		echo "Failed to autodetect IPv6 address. Exiting."
		exit 1
	fi
	echo "Using autodetected IPv6 address: $IP"
fi

[[ $use_ipv6 -ne 0 ]] && RRTYPE="AAAA" || RRTYPE="A"

if [[ $RRTYPE == "A" ]] ; then
  validate_ipv4 $IP
fi

if [[ $RRTYPE == "AAAA" ]] ; then
  validate_ipv6 $IP
fi

# Make sure domain is period terminated
if [[ ${domain: -1} != '.' ]]; then
	domain="${domain}."
fi

# Make sure base_url is not terminated with a slash. If it is, remove it.
if [[ ${base_url: -1} == '/' ]]; then
	base_url="${base_url::-1}"
fi
# Create endpoint from $base_url
# e.g. base_url=http://127.0.0.1:8081
ENDPOINT="$base_url/api/v1/servers/localhost/zones"

if [[ $subdomain == '@' ]]; then
	RNAME="$domain"
else
	RNAME="$subdomain.$domain"
fi

json_message=$(jq -n \
	--arg RNAME "$RNAME" \
	--arg RRTYPE "$RRTYPE" \
	--arg IP "$IP" \
	--arg TTL "$TTL" \
	'{
		"rrsets": [
			{
				"name": $RNAME,
				"type": $RRTYPE,
				"ttl": $TTL,
				"changetype": "REPLACE",
				"records": [
					{
						"content": $IP,
						"disabled": false
					}
				]
			}
		]
	}'
)

echo -e "Sending request to $ENDPOINT/$domain"
echo -e "Payload: $json_message"

set +e 

## UPDATE
STATUS=$(curl -Ss \
-X PATCH "$ENDPOINT/$domain" \
-H "X-Api-Key: $apikey" \
-H "Content-Type: application/json" \
-d "$json_message" \
-w "%{http_code}\n" \
-o $DATFILE 2>$ERRFILE)

if [[ $? -ne 0 ]]; then
	>&2 echo "Curl failed: $(cat $ERRFILE | jq)"
	exit 1
elif [ -z $STATUS ] || [[ $STATUS -ne 204 ]]; then
	>&2 echo "PowerDNS request failed: $STATUS \n$(cat $DATFILE)"
	exit 1
fi

echo "HTTP response code: $STATUS"

if [ -z $verbose ]; then
echo -e "Checking status... \n"

## GET status 
# https://dnssecaccess.euronic.fi/api/v1/servers/localhost/zones/karttahimmeli.fi \
STATUS=$(curl -L \
"$ENDPOINT/$domain" \
-H 'Content-Type: application/json' \
-H "X-API-KEY: $apikey" \
-w "%{http_code}\n" \
-o $DATFILE 2>$ERRFILE)


if [[ $? -ne 0 ]]; then
	>&2 echo -e "Curl failed: $(cat $ERRFILE | jq)"
	exit 1
elif [ -z $STATUS ] || [[ $STATUS -ne 200 ]]; then
	>&2 echo -e "PowerDNS request failed: $STATUS \n$(cat $DATFILE | jq)"
	exit 1
fi

echo -e "Current status:\n$(cat $DATFILE | jq)"

exit 0
fi