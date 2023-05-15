#!/bin/bash
dl_gh() {
    local user=$1
    local repos=$2
    local tag=$3
    for repo in $repos ; do
    asset_urls=$(wget -qO- "https://api.github.com/repos/$user/$repo/releases/$tag" \
                 | jq -r '.assets[] | "\(.browser_download_url) \(.name)"')
        while read -r url names
        do
            echo "Downloading $names from $url"
            wget -q -O "$names" $url
        done <<< "$asset_urls"
    done
echo "All assets downloaded"
}
get_patches_key() {
    local folder=$1
    EXCLUDE_PATCHES=()
        for word in $(cat patches/$folder/exclude-patches) ; do
            EXCLUDE_PATCHES+=("-e $word")
        done
    INCLUDE_PATCHES=()
        for word in $(cat patches/$folder/include-patches) ; do
            INCLUDE_PATCHES+=("-i $word")
        done
}
req() { 
    wget -nv -O "$2" -U "Mozilla/5.0 (X11; Linux x86_64; rv:111.0) Gecko/20100101 Firefox/111.0" "$1"
}

get_apkmirror_vers() { 
    req "$1" - | sed -n 's;.*Version:</span><span class="infoSlide-value">\(.*\) </span>.*;\1;p'
}

dl_apkmirror() {
  local url=$1 regexp=$2 output=$3
  url="https://www.apkmirror.com$(req "$url" - | tr '\n' ' ' | sed -n "s/href=\"/@/g; s;.*${regexp}.*;\1;p")"
  echo "$url"
  url="https://www.apkmirror.com$(req "$url" - | tr '\n' ' ' | sed -n 's;.*href="\(.*key=[^"]*\)">.*;\1;p')"
  url="https://www.apkmirror.com$(req "$url" - | tr '\n' ' ' | sed -n 's;.*href="\(.*key=[^"]*\)">.*;\1;p')"
  req "$url" "$output"
}

get_apkmirror() {
  local app_name=$1 
  local app_category=$2 
  local app_link_tail=$3
  echo "Downloading $app_name"
  local last_ver=$version
  if [[ -z $last_ver ]]; then
    last_ver=$(get_apkmirror_vers "https://www.apkmirror.com/uploads/?appcategory=$app_category" | sort -rV | head -n 1)
  fi
  echo "Choosing version '${last_ver}'"
  local base_apk="$app_name.apk"
  local dl_url=$(dl_apkmirror "https://www.apkmirror.com/apk/$app_link_tail-${last_ver//./-}-release/" \
			"APK</span>[^@]*@\([^#]*\)" \
			"$base_apk")
  echo "$app_name version: ${last_ver}"
  echo "downloaded from: [APKMirror - $app_name]($dl_url)"
}

get_apkmirror_arch() {
  local app_name=$1 
  local app_category=$2 
  local app_link_tail=$3 
  echo "Downloading $app_name (arm64-v8a)"
  local last_ver=$version
  if [[ -z $last_ver ]]; then
    last_ver=$(get_apkmirror_vers "https://www.apkmirror.com/uploads/?appcategory=$app_category" | sort -rV | head -n 1)
  fi
  echo "Choosing version '${last_ver}'"
  local base_apk="$app_name.apk"
  local url_regexp='arm64-v8a</div>[^@]*@\([^"]*\)'
  local dl_url=$(dl_apkmirror "https://www.apkmirror.com/apk/$app_link_tail-${last_ver//./-}-release/" \
			"$url_regexp" \
			"$base_apk")
  echo "$app_name (arm64-v8a) version: ${last_ver}"
  echo "downloaded from: [APKMirror - $app_name (arm64-v8a)]($dl_url)"
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
    url=$(grep -F "${version}</span>" -B 2 <<< "$uptwod_resp" | head -1 | sed -n 's;.*data-url="\(.*\)".*;\1;p') || return 1
    url=$(req "$url" - | sed -n 's;.*data-url="\(.*\)".*;\1;p') || return 1
    req "$url" "$output"
}
get_uptodown() {
    local apk_name="$1"
    local link_name="$2"
    echo "Downloading $apk_name"
    local version="$version"
    local out_name=$(echo "$apk_name" | tr '.' '_' | awk '{ print tolower($0) ".apk" }')
    local uptwod_resp
    uptwod_resp=$(get_uptodown_resp "https://${link_name}.en.uptodown.com/android")
    local available_versions=($(get_uptodown_vers "$uptwod_resp"))
    echo "Available versions: ${available_versions[*]}"
    if [[ " ${available_versions[@]} " =~ " ${version} " ]]; then
        echo "Downloading version $version"
        dl_uptodown "$uptwod_resp" "$version" "$out_name"
    else
        echo "Couldn't find specified version $version, downloading latest version"
        version=${available_versions[0]}
        echo "Downloading version $version"
        uptwod_resp=$(get_uptodown_resp "https://${link_name}.en.uptodown.com/android")
        dl_uptodown "$uptwod_resp" "$version" "$out_name"
    fi
}
#version="2023.16.0"
#get_uptodown "reddit" "reddit-official-app" (can't download twitter)
get_ver() {
    version=$(jq -r --arg patch_name "$1" --arg pkg_name "$2" '
    .[]
    | select(.name == $patch_name)
    | .compatiblePackages[]
    | select(.name == $pkg_name)
    | .versions[-1]
    ' patches.json)
}
patch() {
    local apk_in=$1
    local apk_out=$2
    if [ -f "$apk_in.apk" ]; then
    java -jar revanced-cli*.jar \
    -m revanced-integrations*.apk \
    -b revanced-patches*.jar \
    -a $apk_in.apk \
    ${EXCLUDE_PATCHES[@]} \
    ${INCLUDE_PATCHES[@]} \
    --keystore=ks.keystore \
    -o ./build/$apk_out.apk
    unset version
    unset EXCLUDE_PATCHES
    unset INCLUDE_PATCHES
    else 
        exit 1
    fi
}
