#!/bin/bash
# Config to patch Revanced and Revanced Extended

# Revanced 
keywordsrv(){
NAME="revanced"
USER="revanced"
PATCH="patches.rv"}
declare -a keywordsrv


# Revanced Extended 
keywordsrve(){
NAME="revanced-extended"
USER="inotia00"
PATCH="patches.rve"}
declare -a keywordsrve

# for var in keywords.rv # Revanced w w
# for var in keywords.rve # Revanced Extended 
for val in keywordsrv keywordsrve # Both
do $val

# Prepair patches keywords
patch_file=$PATCH

# Get line numbers where included & excluded patches start from. 
# We rely on the hardcoded messages to get the line numbers using grep
excluded_start="$(grep -n -m1 'EXCLUDE PATCHES' "$patch_file" | cut -d':' -f1)"
included_start="$(grep -n -m1 'INCLUDE PATCHES' "$patch_file" | cut -d':' -f1)"

# Get everything but hashes from between the EXCLUDE PATCH & INCLUDE PATCH line
# Note: '^[^#[:blank:]]' ignores starting hashes and/or blank characters i.e, whitespace & tab excluding newline
excluded_patches="$(tail -n +$excluded_start $patch_file | head -n "$(( included_start - excluded_start ))" | grep '^[^#[:blank:]]')"

# Get everything but hashes starting from INCLUDE PATCH line until EOF
included_patches="$(tail -n +$included_start $patch_file | grep '^[^#[:blank:]]')"

# Array for storing patches
declare -a patches

# Function for populating patches array, using a function here reduces redundancy & satisfies DRY principals
populate_patches() {
    # Note: <<< defines a 'here-string'. Meaning, it allows reading from variables just like from a file
    while read -r patch; do
        patches+=("$1 $patch")
    done <<< "$2"
}

# If the variables are NOT empty, call populate_patches with proper arguments
[[ ! -z "$excluded_patches" ]] && populate_patches "-e" "$excluded_patches"
[[ ! -z "$included_patches" ]] && populate_patches "-i" "$included_patches"

# Download latest APK supported
WGET_HEADER="User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:102.0) Gecko/20100101 Firefox/102.0"


req() {
    wget -q -O "$2" --header="$WGET_HEADER" "$1"
}

get_latestytversion() {
    url="https://www.apkmirror.com/apk/google-inc/youtube/"
    YTVERSION=$(req "$url" - | grep "All version" -A200 | grep app_release | sed 's:.*/youtube-::g;s:-release/.*::g;s:-:.:g' | sort -r | head -1)
    echo "Latest Youtube Version: $YTVERSION"
}

dl_yt() {
    rm -rf $2
    echo -e "🚘 Downloading YouTube v$1..."
    url="https://www.apkmirror.com/apk/google-inc/youtube/youtube-${1//./-}-release/"
    url="$url$(req "$url" - | grep Variant -A50 | grep ">APK<" -A2 | grep android-apk-download | sed "s#.*-release/##g;s#/\#.*##g")"
    url="https://www.apkmirror.com$(req "$url" - | tr '\n' ' ' | sed -n 's;.*href="\(.*key=[^"]*\)">.*;\1;p')"
    url="https://www.apkmirror.com$(req "$url" - | tr '\n' ' ' | sed -n 's;.*href="\(.*key=[^"]*\)">.*;\1;p')"
    req "$url" "$2"
}
# Fetch latest supported YT versions
curl -s https://api.github.com/repos/$USER/revanced-patches/releases/latest | grep "browser_download_url.*json" | cut -d : -f 2,3 | tr -d \" | wget -qi -
YTVERSION=$(jq -r '.[] | select(.name == "microg-support") | .compatiblePackages[] | select(.name == "com.google.android.youtube") | .versions[-1]' patches.json)

# Download Youtube
dl_yt $YTVERSION youtube-v$YTVERSION.apk

# Get patches 
echo -e "⏭️ Prepairing $NAME patches..."

# Revanced-patches
curl -s https://api.github.com/repos/$USER/revanced-patches/releases/latest | grep "browser_download_url.*jar" | cut -d : -f 2,3 | tr -d \" | wget -qi -

# Revanced CLI
curl -s https://api.github.com/repos/$USER/revanced-cli/releases/latest | grep "browser_download_url.*jar" | cut -d : -f 2,3 | tr -d \" | wget -qi -

# ReVanced Integrations
curl -s https://api.github.com/repos/$USER/revanced-integrations/releases/latest | grep "browser_download_url.*apk" | cut -d : -f 2,3 | tr -d \" | wget -qi -

# Patch APK
echo -e "⏭️ Patching YouTube..."
java -jar revanced-cli*.jar -m revanced-integrations*.apk -b revanced-patches*.jar ${patches[@]} -a youtube-v$YTVERSION.apk -o $NAME.apk

# Find and select apksigner binary
echo -e "⏭️ Signing $NAME-v$YTVERSION..."
apksigner="$(find $ANDROID_SDK_ROOT/build-tools -name apksigner | sort -r | head -n 1)"

# Sign apks (https://github.com/tytydraco/public-keystore)
${apksigner} sign --ks public.jks --ks-key-alias public --ks-pass pass:public --key-pass pass:public --in $NAME.apk --out yt-$NAME-v$YTVERSION.apk


# Refresh patches cache
echo -e "⏭️ Clean patches cache..."
rm -f revanced-cli*.jar revanced-integrations*.apk revanced-patches*.jar patches.json

# Finish
fi
done