#!/bin/bash
dl_gh() {
    local user=$1
    local repos=$2
    local tag=$3
    if [ -z "$user" ] || [ -z "$repos" ] || [ -z "$tag" ]; then
        echo -e "\033[0;31mUsage: dl_gh user repo tag\033[0m"
        return 1
    fi
    for repo in $repos; do
        echo -e "\033[1;33mGetting asset URLs for $repo...\033[0m"
        asset_urls=$(wget -qO- "https://api.github.com/repos/$user/$repo/releases/$tag" \
                    | jq -r '.assets[] | "\(.browser_download_url) \(.name)"')        
        if [ -z "$asset_urls" ]; then
            echo -e "\033[0;31mNo assets found for $repo\033[0m"
            return 1
        fi     
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
        downloaded_files=()
        while read -r url name; do
            echo -e "\033[0;34m-> \033[0;36m\"$name\"\033[0;34m | \033[0;36m\"$url\"\033[0m"
            while ! wget -q -O "$name" "$url"; do
                printf "${spinner[i++]} "
                ((i == 3)) && i=0
                sleep 0.1
                printf "\b\b\b"
            done
            printf "\033[0;32m-> \033[0;36m\"$name\"\033[0m [\033[0;32m\"$(date +%T)\"\033[0m] [\033[0;32mDONE\033[0m]\n"
            downloaded_files+=("$name")
        done <<< "$asset_urls"
        if [ ${#downloaded_files[@]} -gt 0 ]; then
            echo -e "\033[0;32mFinished \033[1;33mDownloading assets for $repo:\033[0m"
            for file in ${downloaded_files[@]}; do
                echo -e " -> \033[0;34m$file\033[0m"
            done
        fi
    done
}
get_patches_key() {
    local folder="$1"
    local exclude_file="patches/${folder}/exclude-patches"
    local include_file="patches/${folder}/include-patches"
    local word
    if [ ! -d "${exclude_file%/*}" ]; then
        printf "\033[0;31mFolder not found: %s\n\033[0m" "${exclude_file%/*}"
        return 1
    fi
    if [ ! -f "$exclude_file" ]; then
        printf "\033[0;31mFile not found: %s\n\033[0m" "$exclude_file"
        return 1
    fi
    if [ ! -f "$include_file" ]; then
        printf "\033[0;31mFile not found: %s\n\033[0m" "$include_file"
        return 1
    fi
    if [ ! -r "$exclude_file" ]; then
        printf "\033[0;31mCannot read file: %s\n\033[0m" "$exclude_file"
        return 1
    fi
    if [ ! -r "$include_file" ]; then
        printf "\033[0;31mCannot read file: %s\n\033[0m" "$include_file"
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
        printf "\033[0;31mPatch %s is specified both as exclude and include\033[0m\n" "$word"
        return 1
      fi
    done
    return 0
}
req() {  
     wget -nv -O "$2" -U "Mozilla/5.0 (X11; Linux x86_64; rv:111.0) Gecko/20100101 Firefox/111.0" "$1" 
 } 
  
 get_apkmirror_vers() {  
     req "$1" - | sed -n 's;.*Version:</span><span class="infoSlide-value">\(.*\) </span>.*;\1;p' 
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
  local arch=$4
  if [[ -z $arch ]]; then
    echo -e "\033[1;33mDownloading \033[0;31m$app_name\033[0m"
  elif [[ $arch == "arm64-v8a" ]]; then
    echo -e "\033[1;33mDownloading \033[0;31m$app_name (arm64-v8a)\033[0m"
    url_regexp='arm64-v8a</div>[^@]*@\([^"]*\)'
  elif [[ $arch == "armeabi-v7a" ]]; then
    echo -e "\033[1;33mDownloading \033[0;31m$app_name (armeabi-v7a)\033[0m"
    url_regexp='armeabi-v7a</div>[^@]*@\([^"]*\)'
  elif [[ $arch == "x86" ]]; then
    echo -e "\033[1;33mDownloading \033[0;31m$app_name (x86)\033[0m"
    url_regexp='x86</div>[^@]*@\([^"]*\)'
  elif [[ $arch == "x86_64" ]]; then
    echo -e "\033[1;33mDownloading \033[0;31m$app_name (x86_64)\033[0m"
    url_regexp='x86_64</div>[^@]*@\([^"]*\)'
  else
    echo -e "\033[0;31mArchitecture not exactly!!! Please check\033[0m"
    exit 1
  fi 
  export version="$version"
  if [[ -z $version ]]; then
    version=${version:-$(get_apkmirror_vers "https://www.apkmirror.com/uploads/?appcategory=$app_category" | get_largest_ver)}
  fi
  echo -e "\033[1;33mChoosing version \033[0;36m'${version}'\033[0m"
  local base_apk="$app_name.apk"
  if [[ -z $arch ]]; then
      local dl_url=$(dl_apkmirror "https://www.apkmirror.com/apk/$app_link_tail-${version//./-}-release/" \
			"APK</span>[^@]*@\([^#]*\)" \
			"$base_apk")
  elif [[ $arch == "arm64-v8a" ]]; then
      local dl_url=$(dl_apkmirror "https://www.apkmirror.com/apk/$app_link_tail-${version//./-}-release/" \
			"$url_regexp" \
			"$base_apk")
  elif [[ $arch == "armeabi-v7a" ]]; then
      local dl_url=$(dl_apkmirror "https://www.apkmirror.com/apk/$app_link_tail-${version//./-}-release/" \
			"$url_regexp" \
			"$base_apk")
  elif [[ $arch == "x86" ]]; then
       dl_url=$(dl_apkmirror "https://www.apkmirror.com/apk/$app_link_tail-${version//./-}-release/" \
			"$url_regexp" \
			"$base_apk")
  elif [[ $arch == "x86_64" ]]; then
      local dl_url=$(dl_apkmirror "https://www.apkmirror.com/apk/$app_link_tail-${version//./-}-release/" \
			"$url_regexp" \
			"$base_apk")
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
    url=$(grep -F "${version}</span>" -B 2 <<< "$uptwod_resp" | head -1 | sed -n 's;.*data-url="\(.*\)".*;\1;p') || return 1
    url=$(req "$url" - | sed -n 's;.*data-url="\(.*\)".*;\1;p') || return 1
    req "$url" "$output"
}
get_uptodown() {
    local apk_name="$1"
    local link_name="$2"
    echo -e "\033[1;33m\033[1;33mDownloading \033[0;31m$apk_name\033[0m"
    export version="$version"
    local out_name=$(echo "$apk_name" \
    | tr '.' '_' | awk '{ print tolower($0) ".apk" }')
    local uptwod_resp
    uptwod_resp=$(get_uptodown_resp \
    "https://${link_name}.en.uptodown.com/android")
    local available_versions=($(get_uptodown_vers "$uptwod_resp"))
    if [[ " ${available_versions[@]} " =~ " ${version} " ]]; then
        echo -e "\033[1;33mChoosing version \033[0;36m'$version'\033[0m"
        dl_uptodown "$uptwod_resp" "$version" "$out_name"
    else
        version=${available_versions[0]}
        echo -e "\033[1;33mChoosing version \033[0;36m'$version'\033[0m"
        uptwod_resp=$(get_uptodown_resp \
	"https://${link_name}.en.uptodown.com/android")
        dl_uptodown "$uptwod_resp" "$version" "$out_name"
    fi
}
get_ver() {
    if [[ ! -f patches.json ]]; then
       echo -e "\033[0;31mError: patches.json file not found.\033[0m"
       return 1
     else
       export version=$(jq -r --arg patch_name "$1" --arg pkg_name "$2" '
       .[]
       | select(.name == $patch_name)
       | .compatiblePackages[]
       | select(.name == $pkg_name)
       | .versions[-1]
       ' patches.json)
      if [[ -z $version ]]; then
         echo -e "\033[0;31mError: Unable to find a compatible version.\033[0m"
         return 1
      fi
    fi
}
patch() {
  local apk_name=$1
  local apk_out=$2
  echo -e "\033[1;33mStarting patch \033[0;31m$apk_out\033[1;33m...\033[0m"
  local base_apk=$(find -name "$apk_name.apk" -print -quit)
  if [[ ! -f "$base_apk" ]]
    then
      echo -e "\033[0;31mError: APK file not found\033[0m"
    exit 1
  fi
  echo -e "\033[1;33mSearching for patch files...\033[0m"
  local patches_jar=$(find -name "revanced-patches*.jar" -print -quit)
  local integrations_apk=$(find -name "revanced-integrations*.apk" -print -quit)
  local cli_jar=$(find -name "revanced-cli*.jar" -print -quit)
  if [[ -z "$patches_jar" ]] || [[ -z "$integrations_apk" ]] || [[ -z "$cli_jar" ]]
    then
      echo -e "\033[0;31mError: patches files not found\033[0m"
    exit 1
  else
    echo -e "\033[1;33mRunning patch \033[0;31m$apk_out \033[1;33mwith the following files:\033[0m"
    echo -e "\033[0;36m$cli_jar\033[0m"
    echo -e "\033[0;36m$integrations_apk\033[0m"
    echo -e "\033[0;36m$patches_jar\033[0m"
    echo -e "\033[0;36m$base_apk\033[0m"
    java -jar "$cli_jar" \
      -m "$integrations_apk" \
      -b "$patches_jar" \
      -a "$base_apk" \
      ${exclude_patches[@]} \
      ${include_patches[@]} \
      --keystore=./src/ks.keystore \
      -o "build/$apk_out.apk"
    echo -e "\033[0;32mPatch \033[0;31m$apk_out \033[0;32mis finished!\033[0m"
  fi
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