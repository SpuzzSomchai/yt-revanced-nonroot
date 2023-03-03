#!/bin/bash
# File containing all patches and YouTube version
# source config-rv.txt
# source config-rve.txt
for var in config-rv.txt config-rve.txt
do
source $var

echo "🔴🟡🟢"

# Begin
echo "⏭️ Starting patch ${NAME}..."
# Get patches 
echo "⏭️ Prepairing ${NAME} patches..."

# Revanced-patches
curl -s https://api.github.com/repos/${USER}/revanced-patches/releases/latest \
| grep "browser_download_url.*jar" \
| cut -d : -f 2,3 \
| tr -d \" \
| wget -qi -
mv revanced-patches*.jar ${NAME}-patches.jar

# Revanced CLI
curl -s https://api.github.com/repos/${USER}/revanced-cli/releases/latest \
| grep "browser_download_url.*jar" \
| cut -d : -f 2,3 \
| tr -d \" \
| wget -qi -
mv revanced-cli*.jar ${NAME}-cli.jar

# ReVanced Integrations
curl -s https://api.github.com/repos/${USER}/revanced-integrations/releases/latest \
| grep "browser_download_url.*apk" \
| cut -d : -f 2,3 \
| tr -d \" \
| wget -qi -
mv revanced-integrations*.apk ${NAME}-integrations.apk
echo
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

	echo "⏭️ Choosing version '${last_ver}'"
	local base_apk="youtube-v${VERSION}.apk"
	if [ ! -f "$base_apk" ]; then
		declare -r dl_url=$(dl_apk "https://www.apkmirror.com/apk/google-inc/youtube/youtube-${last_ver//./-}-release/" \
			"APK</span>[^@]*@\([^#]*\)" \
			"$base_apk")
		echo "⏭️ YouTube version: ${last_ver}"
		echo "⏭️ downloaded from: [APKMirror - YouTube]($dl_url)"
	fi
}

## Main

for apk in "${!apks[@]}"; do
    if [ ! -f $apk ]; then
        echo "⏭️ Downloading $apk"
        version=${VERSION}
        ${apks[$apk]}
    fi
done

# Patch revanced and revanced extended
echo "⏭️ Patching YouTube..."
java -jar ${NAME}-cli.jar -a youtube-v${VERSION}.apk -b ${NAME}-patches.jar -m ${NAME}-integrations.apk -o ${NAME}.apk ${INCLUDE_PATCHES} ${EXCLUDE_PATCHES} -c 2>&1 | tee -a patchlog.txt

# Find and select apksigner binary
apksigner="$(find $ANDROID_SDK_ROOT/build-tools -name apksigner | sort -r | head -n 1)"

# Sign apks (https://github.com/tytydraco/public-keystore)
echo "⏭️ Signing ${NAME}-v${VERSION}..."
${apksigner} sign --ks public.jks --ks-key-alias public --ks-pass pass:public --key-pass pass:public --in ./${NAME}.apk --out ./yt-${NAME}-v${VERSION}.apk

# Refresh patches cache
echo "⏭️ Clean patches cache..."
rm -f *-cli.jar *-integrations.apk *-patches.jar
done
