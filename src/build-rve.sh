#!/bin/bash
# Revanced Extended build
source ./src/tools.sh

release=$(curl -sL "https://api.github.com/repos/inotia00/revanced-patches/releases/latest")
asset=$(echo "$release" | jq -r '.assets[] | select(.name | test("revanced-patches.*\\.jar$")) | .browser_download_url')
curl -sLO "$asset"

ls revanced-patches*.jar >> new.txt
rm -f revanced-patches*.jar

release=$(curl -sL "https://api.github.com/repos/$GITHUB_REPOSITORY/releases/latest")
asset=$(echo "$release" | jq -r '.assets[] | select(.name == "revanced-extended-version.txt") | .browser_download_url')
curl -sLO "$asset"

if diff -q revanced-extended-version.txt new.txt >/dev/null ; then
rm -f ./*.txt
echo "Old patch!!! Not build"
exit 0
else
rm -f ./*.txt

#Download Revanced Extended patches 
dl_gh "inotia00" "revanced-patches revanced-cli revanced-integrations" "latest"

# Patch YouTube Extended
get_patches_key "youtube-revanced-extended"
get_ver "hide-general-ads" "com.google.android.youtube"
get_apkmirror "youtube" "youtube" "google-inc/youtube/youtube"
#get_uptodown "youtube" "youtube"
patch "youtube" "youtube-revanced-extended"

# Patch YouTube Music Extended 
get_patches_key "youtube-music-revanced-extended"
get_apkmirror "youtube-music" "youtube-music" "google-inc/youtube-music/youtube-music" "arm64-v8a"
#get_uptodown "youtube-music" "youtube-music" 
patch "youtube-music" "YT-RVE-$version-arm64-v8a"

# Patch microG
get_patches_key "mMicroG"
dl_gh "inotia00" "mMicroG" "latest"
patch "microg" "mMicroG"

ls revanced-patches*.jar >> revanced-extended-version.txt
fi
