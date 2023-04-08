#!/bin/bash
# Config to patch Revanced and Revanced Extended
# Input YTVERSION number/blank to select specific/auto select YouTube version supported 

# Revanced 
keywords_rv() {
NAME="revanced"
USER="revanced"
PATCH="patches.rv"
#YTVERSION="18.03.36"
}

# Revanced Extended 
keywords_rve() {
NAME="revanced-extended"
USER="inotia00"
PATCH="patches.rve"
#YTVERSION="18.07.35"
}

#for keyword in keywords_rv # Revanced
#for keyword in keywords_rve # Revanced Extended 
for keyword in keywords_rv keywords_rve # Both
do $keyword

# Prepair patches keywords
    patch_file=$PATCH
    excluded_start=$(grep -n -m1 'EXCLUDE PATCHES' "$patch_file" | cut -d':' -f1)
    included_start=$(grep -n -m1 'INCLUDE PATCHES' "$patch_file" | cut -d':' -f1)
    excluded_patches=$(tail -n +$excluded_start $patch_file | head -n "$(( included_start - excluded_start ))" | grep '^[^#[:blank:]]')
    included_patches=$(tail -n +$included_start $patch_file | grep '^[^#[:blank:]]')
    patches=()
    if [ -n "$excluded_patches" ]; then
        while read -r patch; do
            patches+=("-e $patch")
        done <<< "$excluded_patches"
    fi
    if [ -n "$included_patches" ]; then
        while read -r patch; do
            patches+=("-i $patch")
        done <<< "$included_patches"
    fi
declare -a patches 

# If the variables are NOT empty, call populate_patches with proper arguments
[[ ! -z "$excluded_patches" ]] && populate_patches "-e" "$excluded_patches"
[[ ! -z "$included_patches" ]] && populate_patches "-i" "$included_patches"

# Download resources 
echo "⏬ Downloading $NAME resources..."
urls_res() {
wget -q -O - "https://api.github.com/repos/$USER/revanced-patches/releases/latest" \
| jq -r '.assets[].browser_download_url'  
wget -q -O - "https://api.github.com/repos/$USER/revanced-cli/releases/latest" \
| jq -r '.assets[].browser_download_url'  
wget -q -O - "https://api.github.com/repos/$USER/revanced-integrations/releases/latest" \
| jq -r '.assets[].browser_download_url'  
}
urls_res | xargs wget -q -i

# Download YouTube APK supported
WGET_HEADER="User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:111.0) Gecko/20100101 Firefox/111.0"

req() {
    wget -q -O "$2" --header="$WGET_HEADER" "$1"
}

dl_yt() {
    rm -rf $2
    echo "⏬ Downloading YouTube v$1..."
    url="https://www.apkmirror.com/apk/google-inc/youtube/youtube-${1//./-}-release/"
    url="$url$(req "$url" - \
    | grep Variant -A50 \
    | grep ">APK<" -A2 \
    | grep android-apk-download \
    | sed "s#.*-release/##g;s#/\#.*##g")"
    url="https://www.apkmirror.com$(req "$url" - \
    | tr '\n' ' ' \
    | sed -n 's;.*href="\(.*key=[^"]*\)">.*;\1;p')"
    url="https://www.apkmirror.com$(req "$url" - \
    | tr '\n' ' ' \
    | sed -n 's;.*href="\(.*key=[^"]*\)">.*;\1;p')"
    req "$url" "$2"
}

# Download specific or auto choose Youtube version
if [ $YTVERSION ] ;
  then dl_yt $YTVERSION youtube-v$YTVERSION.apk 
else YTVERSION=$(jq -r '.[] | select(.name == "microg-support") | .compatiblePackages[] | select(.name == "com.google.android.youtube") | .versions[-1]' patches.json) 
  dl_yt $YTVERSION youtube-v$YTVERSION.apk
fi

# Patch APK
echo "⚙️ Patching YouTube..."
java -jar revanced-cli*.jar \
     -m revanced-integrations*.apk \
     -b revanced-patches*.jar \
     -a youtube-v$YTVERSION.apk \
     ${patches[@]} \
     --keystore=ks.keystore \
     -o yt-$NAME-v$YTVERSION.apk

# Refresh caches
echo "🧹 Clean caches..."
rm -f revanced-cli*.jar \
      revanced-integrations*.apk \
      revanced-patches*.jar \
      patches.json \
      options.toml \
      youtube*.apk \ 
      
unset patches 
unset YTVERSION

# Finish
done
