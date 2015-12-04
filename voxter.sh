#!/usr/bin/env bash

#1 fetch/download podcast from ivoox.
#2 rename podcast filename to this pattern: name-yymmdd-title.mp3
#3 set mp3 ID tags    
#The file name will use pattern name-yymmdd-title.extension
#Will remove all non 128 ASCII code and underscoring blank space separ
#ed words

function help(){

    if [ -z "$1" ];then
	my_prg_name="ivooxer"
    else
	my_prg_name=$1       
    fi
    
    echo "$my_prg_name Download podcasts from ivoox site."
    echo ""
    echo "Use: $my_prg_name [options] url"
    echo ""
    echo "If there are not options to specify somo podcast attributes \
$my_prg_name try to get the info from ivoox.com."
    echo ""
    echo "Options"
    echo "-p STRING: program name."
    echo "-d DATE  : podcast record date. Use YY/MM/DD or \"today\" to \
sysdate."
    echo "-t STRING: podcast title."
    echo "-n       : to avoid updating mp3 id tags."
    echo ""
    echo "-h       : to show this help."
    echo ""
}

normalize_string(){
    #write your own rules to normalize strings

    #erase spanish chars, substitute white spaces and erase non ascii127
    eval ${1}=$(echo "${!1}" | \
		    tr 'á' 'a' | tr 'Á' 'A' | \
		    tr 'é' 'e' | tr 'É' 'E' | \
		    tr 'í' 'i' | tr 'Í' 'I' | \
		    tr 'ó' 'o' | tr 'Ó' 'O' | \
		    tr 'ú' 'u' | tr 'Ú' 'U' | \
		    tr 'ñ' 'n' | tr 'Ñ' 'N' | \
		    tr '[:upper:]' '[:lower:]' | \
		    tr -cd '[[:alnum:]]\ ' | sed -r s/' '+/' '/g | tr ' ' '_')

		    #tr -d '_' | tr ' ' '_' | tr '-' '_' | tr -d '\200-\377)
}

id3=1
pc_genre="Sound\ Clip"
exit_code=0

if [ $# -lt 1 ]
then
    show_help=1
    exit_code=-1
else    
    while getopts  p:d:t:g:nh name
    do
	case $name in
	    p) pc_program="$OPTARG";;
	    d) pc_date="$OPTARG";;
	    t) pc_title="$OPTARG";;
	    g) pc_genre="$OPTARG";;
	    n) id3=0;;
	    h) show_help=1;;
	    ?)
	    show_help=1
	    exit_code=-1;;     
	esac
    done
fi

#bad constructed arguments
if [ $OPTIND -ne $# ]
then
    exit_code=-1
    show_help=1
fi

if [ ! -z "$show_help" ]
then
    help $0
    exit $exit_code
fi

#get the podcast site html code. better get once work many
shift $((OPTIND - 1))
url=$1 #last argument (url)
tmp_file="/tmp/$(basename $url)"

wget -qO- --output-document=$tmp_file $url

#get data from url source code if not gived by user
if [ -z "$pc_date" ]
then
    icon_date=$(grep -i "\"icon-date\"" -F $tmp_file | \
    grep -Eo '\b[[:digit:]]{2}/[[:digit:]]{2}/[[:digit:]]{4}')
    
    pc_date=${icon_date:8:2}${icon_date:3:2}${icon_date:0:2}
    unset icon_date
fi

if [ -z "$pc_program" ]
then
    pc_program=$(grep "meta name=\"description\"" $tmp_file |
			sed s/".*Programa: "//g | cut -f1 -d'.')
fi
normalize_string 'pc_program'

if [ -z "$pc_title" ]
then
    pc_title=$(grep "meta property=\"og:title\"" $tmp_file |
			sed s/".*content=\""//g | cut -f1 -d'"')
fi
normalize_string 'pc_title'

#get url podcast file
dlpattern="downloadlink').load"
dlsuffix=$(grep $dlpattern $tmp_file | cut -f4 -d\' | sed s/downloadlink_//g)
dlurl=$(echo $url | sed s/"mp3_rf_.*"//g)
dlurl=$dlurl"mp3_"$dlsuffix
dlsource=$(curl -L --silent $dlurl)
fileurl=$(echo $dlsource | sed s/".*href.*href=\""//g | sed s/"\".*"//g)

rm $tmp_file

if [ -z "$pc_date" ]
then
    echo -n "Error: Imposible to extract a valid program date from the \
 given url. "
    echo "Check if url is correct or set date using -d parameter."
    exit -1
fi

if [ -z "$pc_program" ]
then
    echo -n "Error: Imposible to extract a valid program name from the \
 given url. "
    echo "Check if url is correct or set program name using -p \
parameter."
    exit -1
fi

if [ -z "$pc_title" ]
then
    echo -n "Error: Imposible to extract a valid program title from the\
 given url. "
    echo "Check if url is correct or set program title using -t\
 parameter."
    exit -1
fi

#get file
podcast="$pc_date"-"$pc_program"-"$pc_title.mp3"
wget -qO- $fileurl --output-document $podcast

if [ $? -ne 0 ]
then
    echo "Error downloading podcast"
    exit -1
fi

#set mp3 tags
if [ $id3 ]
then
    pc_program=$(echo $pc_program | tr '_' ' ')
    pc_title=$(echo $pc_title | tr '_' ' ')
    year=$(echo 20${pc_date:0:2})
    id3 -d $podcast
    id3 -A "$pc_program" -t "$pc_title" -y $year -g 'Sound Clip' $podcast > /dev/null
fi

echo "Succesfully downloaded $podcast"
exit $exit_code
