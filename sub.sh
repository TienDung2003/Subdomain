#!/bin/bash

# -------------------- Banner -------------------- #
echo -e "\e[36m"
echo "============================================="
echo " 🔎 Subdomain Enumeration Framework "
echo "============================================="
echo -e "\e[0m"

# -------------------- Dependency Check -------------------- #
for cmd in subfinder assetfinder massdns httpx dnsgen dig; do
    command -v $cmd >/dev/null 2>&1 || { echo "[!] Missing: $cmd"; exit 1; }
done

# -------------------- ENUM: Passive -------------------- #
enum_domains_passive() {
    local domain="$1"
    folder=$(date +%y%m%d%H%M)_$domain
    mkdir -p "$folder"

    echo "[*] Running passive subdomain enumeration for $domain..."

    # subfinder
    subfinder -d "$domain" -all -silent -o "$folder/_subfinder.txt"

    # assetfinder
    assetfinder --subs-only "$domain" > "$folder/_assetfinder.txt" 2>/dev/null

    # amass passive
    amass enum -passive -norecursive -noalts -d "$domain" > "$folder/_amass.txt" 2>/dev/null


    # Gộp
    cat "$folder/_subfinder.txt" "$folder/_assetfinder.txt" "$folder/_amass.txt" 2>/dev/null | \
        sed '/^$/d' | sort -u > "$folder/subdomainP.txt"

    rm -f "$folder/_subfinder.txt" "$folder/_assetfinder.txt" "$folder/_amass.txt"

    echo -e "\e[32m[PASSIVE]\e[0m Found \e[33m$(wc -l < "$folder/subdomainP.txt")\e[0m unique subdomains for \e[33m$domain\e[0m"
}

# -------------------- FILTER: DNS Resolve via massdns -------------------- #
filter_domain() {
    local domain="$1"
    local folder="$2"

    for i in {1..3}; do
        massdns -r resolvers.txt -t A -o S -c 100 -w "$folder/results$i.txt" "$folder/subdomainP.txt" > /dev/null 2>&1 &
    done
    wait

    for i in {1..3}; do
        grep " A " "$folder/results$i.txt" | cut -d ' ' -f1 | sed 's/\.$//' | sort -u > "$folder/tmp$i.txt"
    done

    cat "$folder/tmp"*.txt | sort -u > "$folder/subdomainLive.txt"
    rm -f "$folder/results"*.txt "$folder/tmp"*.txt

    echo -e "\e[32m[FILTER]\e[0m Found \e[33m$(wc -l < "$folder/subdomainLive.txt")\e[0m live subdomains"
}
# -------------------- FILTER: Wildcard Detection -------------------- #
filter_wildcard() {
    local domain="$1"
    local folder="$2"
    local input="$folder/subdomainLive.txt"
    local output="$folder/subdomainFiltered.txt"

    local rand=$(head /dev/urandom | tr -dc a-z0-9 | head -c10)
    local fake="${rand}.${domain}"
    local wildcard_ip=$(dig +short "$fake" @1.1.1.1)

    if [[ -z "$wildcard_ip" ]]; then
        echo "[+] No wildcard detected."
        cp "$input" "$output"
        return
    fi

    echo "[!] Wildcard IP: $wildcard_ip. Filtering..."

    while read -r sub; do
        ip=$(dig +short "$sub" @1.1.1.1 | head -n1)
        if [[ "$ip" != "$wildcard_ip" && -n "$ip" ]]; then
            echo "$sub"
        fi
    done < "$input" > "$output"

    echo -e "\e[34m[WILDCARD]\e[0m Removed wildcarded subs. Remaining: \e[33m$(wc -l < "$output")\e[0m"
}

# -------------------- HTTPX Probe -------------------- #
probe_httpx() {
    local folder="$1"
    local input="$folder/subdomainFiltered.txt"
    local output_all="$folder/httpx.txt"
    local output_focus="$folder/httpx_focus.txt"

    echo "[*] Running httpx on common ports ..."

    httpx-toolkit -l "$input" -p 80,443,8080,8443 -silent -probe \
        -status-code -title -ip -cname  -tech-detect \
        -timeout 10 -o "$output_all"

    grep -Ei '\[200\]|Login|Admin|API' "$output_all" > "$output_focus"

    echo -e "\e[36m[HTTPX]\e[0m Found: \e[33m$(wc -l < "$output_all")\e[0m HTTP(S) services"
    echo -e "\e[35m[FOCUS]\e[0m High priority entries: \e[33m$(wc -l < "$output_focus")\e[0m"
}

# -------------------- DNSGEN -------------------- #
dnsgen_enum() {
    local folder="$1"
    local domain="$2"
    local input="$folder/subdomainFiltered.txt"
    local dnsgenout="$folder/dnsgen_output.txt"
    local output="$folder/subdomainHidden.txt"

    dnsgen "$input" -w wordlist.txt > "$dnsgenout"
    massdns -r resolvers.txt -t A -o S -w "$folder/massdns_dnsgen.txt" "$dnsgenout" > /dev/null 2>&1
    grep " A " "$folder/massdns_dnsgen.txt" | cut -d ' ' -f1 | sed 's/\.$//' | sort -u > "$output"


    echo -e "\e[36m[DNSGEN]\e[0m Found: \e[33m$(wc -l < "$output")\e[0m new subdomains"
}

# -------------------- Report Generator -------------------- #
generate_summary() {
    local domain="$1"
    local folder="$2"
    local summary_file="$folder/summary_${domain}.txt"

    {
        echo "============================="
        echo " 📄 Summary Report for $domain"
        echo "============================="
        echo ""
        echo "🔍 Passive subdomain count: $(wc -l < "$folder/subdomainP.txt")"
        echo "🌐 Live subdomain (DNS): $(wc -l < "$folder/subdomainLive.txt")"
        echo "🛡️  Filtered (non-wildcard): $(wc -l < "$folder/subdomainFiltered.txt")"
        echo "🔌 HTTP(S) services: $(wc -l < "$folder/httpx.txt")"
        echo "🎯 Focus entries (Login/Admin/API/200): $(wc -l < "$folder/httpx_focus.txt")"
        echo "🕵️ Hidden subdomains (dnsgen): $(wc -l < "$folder/subdomainHidden.txt")"
        echo ""
        echo "🔗 Live HTTP Results:"
        cat "$folder/httpx.txt" 2>/dev/null || echo "[No HTTP results]"
    } > "$summary_file"

    echo -e "\e[32m[SUMMARY]\e[0m Report saved: \e[36m$summary_file\e[0m"
}

# -------------------- Domain Scanner Wrapper -------------------- #
scan_domain() {
    domain="$1"
    echo -e "\n\e[33m[*] Starting scan for: $domain\e[0m"

    enum_domains_passive "$domain"
    filter_domain "$domain" "$folder"
    filter_wildcard "$domain" "$folder"
    probe_httpx "$folder"
    dnsgen_enum "$folder" "$domain"
    generate_summary "$domain" "$folder"
}

# -------------------- Main Entry -------------------- #
if [ "$#" -eq 1 ]; then
    if [ -f "$1" ]; then
        cat "$1" | xargs -P 5 -n 1 -I {} bash "$0" {}  # multi-thread
    else
        scan_domain "$1"
    fi
else
    echo "Usage: $0 <domain.com> | <domains.txt>"
    exit 1
fi
