#!/usr/bin/env bash

# Author: tyasky

configfile="$(cd $(dirname $0);pwd)/config.ini"

# 第二个参数指定额外不编码的字符
# 笔记：[-_.~a-zA-Z0-9$2] 中的-字符用于表示区间，放到中间会出意外结果
urlencode() {
    local string="${1}"
    local strlen=${#string}
    local encoded=""
    local pos c o
    for pos in $(awk "BEGIN { for ( i=0; i<$strlen; i++ ) { print i; } }")
    do
        c=${string:$pos:1}
        case $c in
            [-_.~a-zA-Z0-9$2] ) o="${c}" ;;
            * ) o=`printf '%%%02X' "'$c"`
        esac
        encoded="$encoded$o"
    done
    echo "${encoded}"
}

send_request() {
    timestamp=`date -u +"%Y-%m-%dT%H:%M:%SZ"`
    # 服务器拒绝重放攻击（本次与前一次请求数据相同返回错误)，SignatureNonce 需赋值随机数而不能是时间戳(可能同一秒两次请求)
    nonce=`openssl rand -base64 8 | md5sum | cut -c1-8`
    args="AccessKeyId=$ak&Format=json&SignatureMethod=HMAC-SHA1&SignatureNonce=$nonce&SignatureVersion=1.0&Timestamp=$timestamp&Version=2015-01-09&$1"
    # 签名要求参数按大小写敏感排序(sort 在本地语言环境可能会忽略大小写排序)：LC_ALL=c sort
    args=`echo "$args" | sed 's/\&/\n/g' | LC_ALL=c sort | xargs | sed 's/ /\&/g'`
    CanonicalizedQueryString=$(urlencode "$args" "=&")
    StringToSign="GET&%2F&$(urlencode $CanonicalizedQueryString)"
    Signature=$(urlencode $(echo -n "$StringToSign" | openssl dgst -sha1 -hmac "$sk&" -binary | openssl base64))
    echo $(curl -k -s "https://alidns.aliyuncs.com/?$args&Signature=$Signature")
}

getValueFromJson() {
    local json="$1"
    local key="^$2："
    echo $json | sed 's/":/：/g;s/"//g;s/,/\n/g' | grep -E $key | awk -F： '{ print $2 }'
}

DescribeSubDomainRecords() {
    local host="$1"
    local type="$2"
    send_request "Action=DescribeSubDomainRecords&SubDomain=$host.$domain&Type=$type"
}

UpdateDomainRecord() {
    local host="$1"
    local type="$2"
    local value="$3"
    local recordid=$(getValueFromJson `DescribeSubDomainRecords "$host" "$type"` "RecordId")
    send_request "Action=UpdateDomainRecord&RR=$host&RecordId=$recordid&Type=$type&Value=$value"
}

AddDomainRecord() {
    local host="$1"
    local type="$2"
    local value="$3"
    send_request "Action=AddDomainRecord&DomainName=$domain&RR=$host&Type=$type&Value=$value"
}

DeleteSubDomainRecords() {
    local host="$1"
    send_request "Action=DeleteSubDomainRecords&DomainName=$domain&RR=$host"
}

isCmdExist() {
    local ret=1
    if type $1 >/dev/null 2>&1;then
        ret=0
    fi
    return $ret
}

parse_ini() {
  cat "$1" |sed 's/\r/\n/g'| gawk -v section="$2" -v key="$3" '
    BEGIN {
      if (length(key) > 0) { params=3 }
      else if (length(section) > 0) { params=2 }
      else { params=1 }
    }
    match($0,/#/) { next }
    match($0,/^\[(.+)\]$/){
      current=substr($0, RSTART+1, RLENGTH-2)
      found=current==section
      if (params==1) { print current }
    }
    match($0,/(.+)=(.+)/,a) {
       if (found) {
         if (params==3 && key==a[1]) { print a[2] }
         if (params==2) { printf "%s=%s\n",a[1],a[2] }
       }
    }'
}

init() {
    ak=`parse_ini "$configfile" common AccessKeyID`
    sk=`parse_ini "$configfile" common AccessKeySecret`
    domain=`parse_ini "$configfile" common DomainName`
}

resolveDomain() {
    local host="$1"
    local type="$2"
    local downvalue="$3"
    rslt=`DescribeSubDomainRecords "$host" "$type"| grep TotalCount`
    if [ -z "$rslt" ];then
        echo "未获取到阿里云查询结果"
        return 1
    fi
    upvalue=$(getValueFromJson "$rslt" "Value")
    echo "域名指向：$upvalue"

    if [ -z "$downvalue" ]; then
        echo "待解析值为空"
        return 1
    fi
    echo "待解析值：$downvalue"

    if [ "$upvalue" = "$downvalue" ]; then
        echo "已正确解析，无需更新。"
    elif [ -n "$upvalue" ]; then
        echo "更新解析记录..."
        UpdateDomainRecord "$host" "$type" "$downvalue"
    else
        echo "添加解析记录..."
        AddDomainRecord "$host" "$type" "$downvalue"
    fi
}

usage() {
    echo "Usage:"
    echo "-f file1  Read config from file1" 
    echo "-d test   DeleteSubDomainRecords of test.xx.com"
    echo "-h        Show usage"
    exit
}

set -- $(getopt -q hd:f: "$@")
while [ -n "$1" ]
do
    case "$1" in
        -h) usage;;
        -d) init;host=${2:1:!2-1};DeleteSubDomainRecords "$host";exit;;
        -f) configfile=${2:1:!2-1};shift;;
        *);;
    esac
    shift
done

init

value=`parse_ini "$configfile" IPv4`
value=${value//\\/\\\\}
echo "$value" | while read i && [ -n "$i" ]
do
    kk=${i%=*}
    vv=${i#*=}
    if isCmdExist $vv;then
        vv=$(eval $vv)
    fi
    echo "$kk.$domain"
    resolveDomain "$kk" "A" "$vv"
    echo
done

value=`parse_ini $configfile IPv6`
value=${value//\\/\\\\}
echo "$value" | while read i && [ -n "$i" ]
do
    kk=${i%=*}
    vv=${i#*=}
    if isCmdExist $vv;then
        vv=$(eval $vv)
    fi
    echo "$kk.$domain"
    resolveDomain "$kk" "AAAA" "$vv"
    echo
done
