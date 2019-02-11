#!/bin/bash
# $1 - адрес клиента для backup
# $2 - путь на клиенте для backup
# $3 - срок хранения файлов в днях (+1)
# $4 - название backup (не обязательно)

source=$1:$2

if [ -z $4 ]
    then
        dstDir=/mnt/backup/$1
    else
        dstDir=/mnt/backup/$1/$4
fi


# если нет каталога - создадим его
if [ ! -d $dstDir ]
    then
        mkdir $dstDir
fi

date=`date +%F-%H-%M-%S`

latest=`ls $dstDir -Arc | tail -n 1`

rsync \
--rsync-path="sudo /usr/bin/rsync" \
--rsh="ssh -T -x -c chacha20-poly1305@openssh.com,aes128-ctr -o 'Compression no'" \
--verbose \
--progress \
--archive \
--delete \
--whole-file \
--link-dest=$dstDir/$latest \
$source \
$dstDir/$date/

/usr/bin/find $dstDir -mindepth 1 -maxdepth 1 -ctime +$3 -exec rm -rf {} \;
