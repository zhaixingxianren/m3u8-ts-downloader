##################################################################################
#  you can redistribute it and/or modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; 
#
#  author: lijinbo3000@163.com
#  date:   2017
#################################################################################

###usage:
if [ $# -eq 0 ]; then
	echo "usage: m3u8_downloader.sh [path] [download number]"
	echo '   ex. m3u8_downloader.sh /mnt/usb/sda1/'
	exit 1
fi

ret=0
#set download number
download_num=$2
downloaded_num=0


echo "## goto $1, will download $2 number"
if [ ! -d "$1" ]; then
    mkdir "$1"
fi
cd $1

### parse platform
busybox uname -a > platform.info
grep "arm" platform.info
if [ $? -eq 0 ];then
    echo 'arm platform'
    DOWNLOAD_TOOL="busybox wget"
else
    DOWNLOAD_TOOL=wget
fi


#set download-url
#URL="https://d29r7idq0wxsiz.cloudfront.net/DigitalMusicDeliveryService/HPS.m3u8?m=b&dmid=227176503&c=cf&f=ts&t=10&b=256k&s=true&e2=1506076200000&v=V2&h=91fbb03d9ba568252f64ca3ec546e424746a2d64817825585888bdcf62d9c9c0"
#URL="http://live.hkstv.hk.lxdns.com/live/hks/playlist.m3u8?wsSession=59283c4360e2eb717fc24660-150553275635213&wsIPSercert=d36ab94d82b4efba23f9b3f153525683&wsMonitor=-1"
#URL="http://live.italkdd.com:80/cds171/hls/TV013/media.m3u8"
#URL="http://s11.tvprogram.cz/test/hd.m3u8"
URL="https://s-remotesirona.svc.litv.tv/hi/vod/F4XR3jrl1HQ/litv-ftv11-video=1936000-audio_AACL_und_66800_545=66800.m3u8"
URL="https://s-remotesirona.svc.litv.tv/hi/vod/buleR1g8MLg/litv-ftv11-video=1936000-audio_AACL_und_66800_545=66800.m3u8"
URLRelotive=0

URL_ROOT=${URL%/*}
echo "root url is $URL_ROOT"

#EXT-X-MEDIA-SEQUENCE
MEDIASEQ=0
TARGET_DURATION=0
PreMEDIASEQ=-1
STATIC_HLS=0

#only print once
function get_m3u8_info()
{
    if [ $TARGET_DURATION -eq 0 ];then
        local TMP2=`grep "EXT-X-VERSION" $1`
        echo "### m3u8 version is: ${TMP2#*:}"

        local TMP3=`grep "EXT-X-TARGETDURATION" $1`
        TARGET_DURATION=${TMP2#*:}
        echo "### target duration is: $TARGET_DURATION"
    fi

}
function get_media_seq()
{
    local TMP=`grep "EXT-X-MEDIA-SEQUENCE" $1`
    MEDIASEQ=${TMP#*:}
    echo "### mediasequence: $MEDIASEQ"
}

#newest downloaded url,like an anctor
SEG_URL=""
SEG_URLS_File=downloadlist.info
PLAYLIST_FILE=all_list.info

#function: get segment url to download
#input: playlist url
#output: need download urls
function get_segment_url()
{
    :>${SEG_URLS_File}
    while read line
    do
        local url_tmp=""
        if [ $URLRelotive -eq 1 ];then url_tmp="${URL_ROOT}/${line}"
        else
            url_tmp="${line}"
        fi

        if [ "$url_tmp" \>  "$SEG_URL" ];then
            SEG_URL=$url_tmp
            echo $SEG_URL >> $SEG_URLS_File
        fi
    done < $PLAYLIST_FILE
}

#define download ts function
function download_ts()
{
    grep "\.ts" $1 > $PLAYLIST_FILE
    grep "^http.*\.ts" $1  >/dev/null 2>&1
    ret=$?
    if [ $ret -ne 0 ];then
        URLRelotive=1
    else
        URLRelotive=0
    fi

    if [ $2 == "SAME" ];then
        echo "same playlist ,wait seconds..."
        sleep $[${TARGET_DURATION}/3]
    else
        get_segment_url $PLAYLIST_FILE
        while read line
        do
	    local saved_name=${line##*/}
	    saved_name=${saved_name%%\.ts*}
	    echo "### downloading segment name:${saved_name}"
	    $DOWNLOAD_TOOL $line -O ${saved_name}.ts > /dev/null 2>&1
	    if [ $? -ne 0 ];then
	        echo downloading failed,retry again
	        $DOWNLOAD_TOOL $line -O ${saved_name}.ts
	        let downloaded_num=downloaded_num+1
	    else
	        let downloaded_num=downloaded_num+1
	    fi

	    if [ $downloaded_num -eq $download_num ];then
	        echo "download enough,exit now.."
                exit
	    fi

        done < $SEG_URLS_File
    fi
}

i=0
while [ $downloaded_num -lt $download_num ]
do
    saved_file="index_3096_av-p___${i}.m3u8"
    $DOWNLOAD_TOOL $URL -O $saved_file >/dev/null 2>&1
    #if not sucessfull,will retry.
    if [ $? -ne 0 ];then
        echo download m3u8 failed,retry again...
        $DOWNLOAD_TOOL $URL -O $saved_file
        if [ $? -ne 0 ];then
            echo download m3u8 failed,exit...
            exit 1
        fi
    fi

    grep "EXT-X-ENDLIST" $saved_file >/dev/null 2>&1
    STATIC_HLS=$?
    echo "hls is static $STATIC_HLS"

    get_m3u8_info ${saved_file}

    #get media sequence
    get_media_seq ${saved_file}

    #downloading ts segment.
    if [ $PreMEDIASEQ == $MEDIASEQ ];then
        echo "m3u8 downloaded is same sequence"
        download_ts ${saved_file} "SAME"
    else
        download_ts ${saved_file} "NOT"
    fi

    PreMEDIASEQ=$MEDIASEQ
done
