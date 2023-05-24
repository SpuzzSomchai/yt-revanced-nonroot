#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
spinner=(
  "⠋"
  "⠙"
  "⠹"
  "⠸"
  "⠼"
  "⠴"
  "⠦"
  "⠧"
  "⠇"
  "⠏"
)
i=0
dl_gh() {
    local user=$1
    local repos=$2
    local tag=$3
    if [ -z "$user" ] || [ -z "$repos" ] || [ -z "$tag" ]; then
        echo -e "${RED}Usage: dl_gh user repo tag${NC}"
        return 1
    fi
    for repo in $repos; do
        echo -e "${YELLOW}Getting asset URLs for $repo...${NC}"
        asset_urls=$(wget -qO- "https://api.github.com/repos/$user/$repo/releases/$tag" \
                    | jq -r '.assets[] | "\(.browser_download_url) \(.name)"')        
        if [ -z "$asset_urls" ]; then
            echo -e "${RED}No assets found for $repo${NC}"
            return 1
        fi        
        downloaded_files=()
        while read -r url name; do
            echo -e "${BLUE}-> ${CYAN}\"$name\"${BLUE} | ${CYAN}\"$url\"${NC}"
            while ! wget -q -O "$name" "$url"; do
                printf "${spinner[i++]} "
                ((i == 3)) && i=0
                sleep 0.1
                printf "\b\b\b"
            done
            printf "${GREEN}-> ${CYAN}\"$name\"${NC} [${GREEN}\"$(date +%T)\"${NC}] [${GREEN}DONE${NC}]\n"
            downloaded_files+=("$name")
        done <<< "$asset_urls"
        if [ ${#downloaded_files[@]} -gt 0 ]; then
            echo -e "${GREEN}Finished downloading assets for $repo:${NC}"
            for file in ${downloaded_files[@]}; do
                echo -e " -> ${BLUE}$file${NC}"
            done
        fi
    done
    echo -e "${GREEN}All assets downloaded${NC}"
}
get_patches_key() {
    local folder="$1"
    local exclude_file="patches/${folder}/exclude-patches"
    local include_file="patches/${folder}/include-patches"
    local word
    if [ ! -d "${exclude_file%/*}" ]; then
        printf "${RED}Folder not found: %s\n${NC}" "${exclude_file%/*}"
        return 1
    fi
    if [ ! -f "$exclude_file" ]; then
        printf "${RED}File not found: %s\n${NC}" "$exclude_file"
        return 1
    fi
    if [ ! -f "$include_file" ]; then
        printf "${RED}File not found: %s\n${NC}" "$include_file"
        return 1
    fi
    if [ ! -r "$exclude_file" ]; then
        printf "${RED}Cannot read file: %s\n${NC}" "$exclude_file"
        return 1
    fi
    if [ ! -r "$include_file" ]; then
        printf "${RED}Cannot read file: %s\n${NC}" "$include_file"
        return 1
    fi
    while IFS= read -r word; do
        if [[ -n "$word" ]]; then
            exclude_patches+=("-e" "$word")
        fi
    done < "$exclude_file"
    while IFS= read -r word; do
        if [[ -n "$word" ]]; then
            include_patches+=("-i" "$word")
        fi
    done < "$include_file"
    for word in "${exclude_patches[@]}"; do
      if [[ " ${include_patches[*]} " =~ " $word " ]]; then
        printf "${RED}Patch %s is specified both as exclude and include${NC}\n" "$word"
        return 1
      fi
    done
    return 0
}
_req() {
    if [ "$2" = - ]; then
	wget -nv -O "$2" --header="$3" "$1"
    else
	local dlp
	dlp="$(dirname "$2")/tmp.$(basename "$2")"
	wget -nv -O "$dlp" --header="$3" "$1"
	mv -f "$dlp" "$2"
    fi
}
req() {
    _req \
     "$1" \
      "$2" \
       "User-Agent: Mozilla/5.0 \
     (X11; Linux x86_64; rv:111.0) \
 Gecko/20100101 Firefox/111.0" 
}
get_apkmirror_vers() { 
    req "$1" - \
    | sed -n 's;.*Version:</span><span \
    class="infoSlide-value">\(.*\) </span>.*;\1;p'
}
get_largest_ver() {
  local max=0
  while read -r v || [ -n "$v" ]; do   		
	if [[ ${v//[!0-9]/} -gt ${max//[!0-9]/} ]]; then max=$v; fi
	  done
      	if [[ $max = 0 ]]; then echo ""; else echo "$max"; fi
}
dl_apkmirror() {
  local url=$1 regexp=$2 output=$3
  url="https://www.apkmirror.com$(req "$url" - | tr '\n' ' ' \
  | sed -n "s/href=\"/@/g; s;.*${regexp}.*;\1;p")"
  echo "$url"
  url="https://www.apkmirror.com$(req "$url" - | tr '\n' ' ' \
  | sed -n 's;.*href="\(.*key=[^"]*\)">.*;\1;p')"
  url="https://www.apkmirror.com$(req "$url" - | tr '\n' ' ' \
  | sed -n 's;.*href="\(.*key=[^"]*\)">.*;\1;p')"
  echo -e "${BLUE}Downloading ${CYAN}$output${BLUE} from ${CYAN}$url${NC}"
  while ! req "$url" "$output"; do
    printf "${spinner[i++]} "
    ((i == 3)) && i=0
    sleep 0.1
    printf "\b\b\b"
  done
  printf "${GREEN}$output [DONE]\n${NC}" 
}
get_apkmirror() {
  local app_name=$1 
  local app_category=$2 
  local app_link_tail=$3
  local arch=$4
  local arch_array=( 
  "x86" 
  "x86_64"
  "arm64-v8a" 
  "armeabi-v7a"
  )
  local url_regexp_array=( 
  'x86</div>[^@]*@\([^"]*\)' 
  'x86_64</div>[^@]*@\([^"]*\)'
  'arm64-v8a</div>[^@]*@\([^"]*\)' 
  'armeabi-v7a</div>[^@]*@\([^"]*\)'
  )
  if [[ -z $arch ]]; then
    echo -e "${YELLOW}Downloading $app_name${NC}"
  else
    for i in {0..3}; do
      if [[ $arch == ${arch_array[i]} ]]; then
        echo -e "${YELLOW}Downloading $app_name (${arch_array[i]})${NC}"
        url_regexp=${url_regexp_array[i]}
        break
      fi
    done
    if [[ -z $url_regexp ]]; then
      echo -e "${RED}Architecture not exactly!!! Please check${NC}"
      exit 1
    fi
  fi
  export version=$version
  if [[ -z $version ]]; then
    version=${version:-$(get_apkmirror_vers \
    "https://www.apkmirror.com/uploads/?appcategory=$app_category" \
    | get_largest_ver)}
  fi
  echo -e "${YELLOW}Choosing version '${version}'${NC}"
  local base_apk="$app_name.apk"
  if [[ -z $arch ]]; then
      local dl_url=$(dl_apkmirror \
      "https://www.apkmirror.com/apk/$app_link_tail-${version//./-}-release/" \
      "APK</span>[^@]*@\([^#]*\)" \
      "$base_apk")
      echo -e "${GREEN}$app_name version: ${version}${NC}"
      echo -e "${GREEN}Download link $app_name: $dl_url${NC}"
  else
      local dl_url=$(dl_apkmirror \
      "https://www.apkmirror.com/apk/$app_link_tail-${version//./-}-release/" \
      "$url_regexp" \
      "$base_apk")
      echo -e "${GREEN}$app_name ($arch) version: ${version}${NC}"
      echo -e "${GREEN}Download link $app_name ($arch): $dl_url${NC}"
  fi
}
get_uptodown_resp() {
    req "${1}/versions" -
}
get_uptodown_vers() {
    sed -n 's;.*version">\(.*\)</span>$;\1;p' <<< "$1"
}
dl_uptodown() {
    local uptwod_resp=$1 version=$2 output=$3
    local url
    url=$(grep -F "${version}</span>" -B 2 <<< "$uptwod_resp" \
    | head -1 | sed -n 's;.*data-url="\(.*\)".*;\1;p') || return 1
    url=$(req "$url" - | sed -n 's;.*data-url="\(.*\)".*;\1;p') || return 1
    echo -e "${BLUE}Downloading ${CYAN}$output${BLUE} from ${CYAN}$url${NC}"
  while ! req "$url" "$output"; do
    printf "${spinner[i++]} "
    ((i == 3)) && i=0
    sleep 0.1
    printf "\b\b\b"
  done
  printf "${GREEN}$output [DONE]\n${NC}" 
}
get_uptodown() {
    local apk_name="$1"
    local link_name="$2"
    echo -e "${YELLOW}Downloading $apk_name${NC}"
    export version="$version"
    local out_name=$(echo "$apk_name" \
    | tr '.' '_' | awk '{ print tolower($0) ".apk" }')
    local uptwod_resp
    uptwod_resp=$(get_uptodown_resp \
    "https://${link_name}.en.uptodown.com/android")
    local available_versions=($(get_uptodown_vers "$uptwod_resp"))
    if [[ " ${available_versions[@]} " =~ " ${version} " ]]; then
        echo -e "${YELLOW}Choosing version $version${NC}"
        dl_uptodown "$uptwod_resp" "$version" "$out_name"
    else
        version=${available_versions[0]}
        echo -e "${YELLOW}Choosing version $version${NC}"
        uptwod_resp=$(get_uptodown_resp \
	"https://${link_name}.en.uptodown.com/android")
        dl_uptodown "$uptwod_resp" "$version" "$out_name"
    fi
}
get_ver() {
    export version=$(jq -r --arg patch_name "$1" --arg pkg_name "$2" '
    .[]
    | select(.name == $patch_name)
    | .compatiblePackages[]
    | select(.name == $pkg_name)
    | .versions[-1]
    ' patches.json)
}
patch() {
  local apk_name=$1
  local apk_out=$2
  echo -e "${YELLOW}Starting patch $apk_out...${NC}"
  local base_apk=$(find -name "$apk_name.apk" -print -quit)
  if [[ ! -f "$base_apk" ]]
    then
      echo -e "${RED}Error: APK file not found${NC}"
    exit 1
  fi
  echo -e "${YELLOW}Searching for patch files...${NC}"
  local patches_jar=$(find -name "revanced-patches*.jar" -print -quit)
  local integrations_apk=$(find -name "revanced-integrations*.apk" -print -quit)
  local cli_jar=$(find -name "revanced-cli*.jar" -print -quit)
  if [[ -z "$patches_jar" ]] || [[ -z "$integrations_apk" ]] || [[ -z "$cli_jar" ]]
    then
      echo -e "${RED}Error: patches files not found${NC}"
    exit 1
  fi
  echo -e "${YELLOW}Running patch $apk_out with the following files:${NC}"
  echo -e "${CYAN}$cli_jar${NC}"
  echo -e "${CYAN}$integrations_apk${NC}"
  echo -e "${CYAN}$patches_jar${NC}"
  echo -e "${CYAN}$base_apk${NC}"
  java -jar "$cli_jar" \
    -m "$integrations_apk" \
    -b "$patches_jar" \
    -a "$base_apk" \
    ${exclude_patches[@]} \
    ${include_patches[@]} \
    --keystore=./src/ks.keystore \
    -o "build/$apk_out.apk"
  echo -e "${GREEN}Patch ${RED}$apk_out ${GREEN}is finished!${NC}"
  vars_to_unset=(
    "version"
    "exclude_patches"
    "include_patches"
  )
  for varname in "${vars_to_unset[@]}"; do
    if [[ -v "$varname" ]]; then
      unset "$varname"
    fi
  done
  rm -f ./"$base_apk"
}
