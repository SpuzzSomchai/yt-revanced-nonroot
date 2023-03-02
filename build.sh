#!/bin/bash
# File containing all patches and YouTube version
# source config-rv.txt
# source config-rve.txt
for var in config-rv.txt config-rve.txt
do
source $var
# Download Patches
declare -A artifacts
artifacts["${NAME}-cli.jar"]="${USER}/revanced-cli revanced-cli .jar"
artifacts["${NAME}-integrations.apk"]="${USER}/revanced-integrations revanced-integrations .apk"
artifacts["${NAME}-patches.jar"]="${USER}/revanced-patches revanced-patches .jar"

## Functions

get_artifact_download_url() {

    # Usage: get_download_url <repo_name> <artifact_name> <file_type>

    local api_url result
    api_url="https://api.github.com/repos/$1/releases/latest"

    # shellcheck disable=SC2086

    result=$(curl -s $api_url | jq ".assets[] | select(.name | contains(\"$2\") and contains(\"$3\") and (contains(\".sig\") | not)) | .browser_download_url")
    echo "${result:1:-1}"
}

# Function for populating patches array, using a function here reduces redundancy & satisfies DRY principals
populate_patches() {

    # Note: <<< defines a 'here-string'. Meaning, it allows reading from variables just like from a file

    while read -r patch; do
        patches+=("$1 $patch")
    done <<< "$2"
}

## Main

# cleanup to fetch new revanced on next run
if [[ "$1" == "clean" ]]; then
    rm -f revanced-cli.jar revanced-integrations.apk revanced-patches.jar
    exit
fi

if [[ "$1" == "experimental" ]]; then
    EXPERIMENTAL="--experimental"
fi

# Fetch all the dependencies

for artifact in "${!artifacts[@]}"; do
    if [ ! -f "$artifact" ]; then
        echo "Downloading $artifact"
        # shellcheck disable=SC2086,SC2046
        curl -sLo "$artifact" $(get_artifact_download_url ${artifacts[$artifact]})
    fi
done
# Repair
declare -A apks
apks["youtube.apk"]=dl_yt

## Functions

# Wget user agent
WGET_HEADER="User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:102.0) Gecko/20100101 Firefox/102.0"

# Wget function
req() { wget -nv -O "$2" --header="$WGET_HEADER" "$1"; }

# Wget apk verions
get_apk_vers() { req "$1" - | sed -n 's;.*Version:</span><span class="infoSlide-value">\(.*\) </span>.*;\1;p'; }

# Wget apk verions(largest)
get_largest_ver() {
	local max=0
	while read -r v || [ -n "$v" ]; do
		if [[ ${v//[!0-9]/} -gt ${max//[!0-9]/} ]]; then max=$v; fi
	done
	if [[ $max = 0 ]]; then echo ""; else echo "$max"; fi
}

# Wget download apk
dl_apk() {
	local url=$1 regexp=$2 output=$3
	url="https://www.apkmirror.com$(req "$url" - | tr '\n' ' ' | sed -n "s/href=\"/@/g; s;.*${regexp}.*;\1;p")"
	echo "$url"
	url="https://www.apkmirror.com$(req "$url" - | tr '\n' ' ' | sed -n 's;.*href="\(.*key=[^"]*\)">.*;\1;p')"
	url="https://www.apkmirror.com$(req "$url" - | tr '\n' ' ' | sed -n 's;.*href="\(.*key=[^"]*\)">.*;\1;p')"
	req "$url" "$output"
}


# Downloading youtube
dl_yt() {
	local last_ver
	last_ver="$version"
	last_ver="${last_ver:-$(get_apk_vers "https://www.apkmirror.com/uploads/?appcategory=youtube" | get_largest_ver)}"

	echo "Choosing version '${last_ver}'"
	local base_apk="youtube-v${VERSION}.apk"
	if [ ! -f "$base_apk" ]; then
		declare -r dl_url=$(dl_apk "https://www.apkmirror.com/apk/google-inc/youtube/youtube-${last_ver//./-}-release/" \
			"APK</span>[^@]*@\([^#]*\)" \
			"$base_apk")
		echo "YouTube version: ${last_ver}"
		echo "downloaded from: [APKMirror - YouTube]($dl_url)"
	fi
}

## Main

for apk in "${!apks[@]}"; do
    if [ ! -f $apk ]; then
        echo "Downloading $apk"
        version=${VERSION}
        ${apks[$apk]}
    fi
done

# Patch revanced
echo "Patching ${NAME}..."
java -jar ${NAME}-cli.jar -a youtube-v${VERSION}.apk -b ${NAME}-patches.jar -m ${NAME}-integrations.apk -o ${NAME}.apk ${INCLUDE_PATCHES} ${EXCLUDE_PATCHES} -c 2>&1 | tee -a Patch.log

# Find and select apksigner binary
apksigner="$(find $ANDROID_SDK_ROOT/build-tools -name apksigner | sort -r | head -n 1)"
# Sign apks (https://github.com/tytydraco/public-keystore)
echo  "Signing ${NAME}..."
${apksigner} sign --ks public.jks --ks-key-alias public --ks-pass pass:public --key-pass pass:public --in ./${NAME}.apk --out ./yt-${NAME}-v${VERSION}.apk
done
