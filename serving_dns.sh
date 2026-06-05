elastic_ip="1.2.3.4"
json=$(curl -X GET "https://hackattic.com/challenges/serving_dns/problem?access_token=$hackattic_access_token")
echo "$json"
curl -X POST "$elastic_ip:80" --header 'Content-Type: application/json' --data "$json"
curl -X POST "https://hackattic.com/challenges/serving_dns/solve?access_token=$hackattic_access_token" \
    --data "{\"dns_ip\": \"$elastic_ip\", \"dns_port\": 9002}" 