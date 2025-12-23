elastic_ips=("1.2.3.4" "5.6.7.8") # more Elastic IP addresses here
 
access_token=$hackattic_access_token
presence_token=$(curl -X GET "https://hackattic.com/challenges/a_global_presence/problem?access_token=$access_token" | jq -r '.presence_token' )

for ip in "${elastic_ips[@]}"; do
    echo "Invoking app at $ip"
    curl -X POST "http://$ip:80/?presence_token=$presence_token&access_token=$access_token"
    echo "\n"
done