#!/bin/bash
# задаем путь, куда складываем бэкапы
backup_dir=/mnt/backup
# выбираем названия разделов ВМ, которые бэкапим
backup_images_names="system\|home\|var"
# получаем текущий timestamp
data=`date +%s`
# получаем список активных ВМ
vm_list=`virsh list | grep running | awk '{print $2}'`
# перебираем активные ВМ
for activevm in $vm_list
    do
        # получем список дисков активной ВМ (vda,vdb,...)
        disk_list=`virsh domblklist $activevm | grep vd | awk '{print $1}'`
        # если нет vd..., ищем hd...
        if [ "$disk_list" = "" ]
            then
                disk_list=`virsh domblklist $activevm | grep hd | awk '{print $1}'`
        fi
        # формируем пути к файлам qcow2 для бэкапа
        disk_path=`virsh domblklist $activevm | grep $backup_images_names | awk '{print $2}'`
        # делаем дамп конфигурации ВМ
        virsh dumpxml $activevm > $backup_dir/$activevm.xml-$data
        if [ $? -eq 0 ]
            then
                # если дамп получился, удаляем старые
                ls -d $backup_dir/* | grep $activevm".xml" | grep -v $activevm".xml-"$data | xargs -d"\n" rm -f
        fi
        # делаем external snapshot
        virsh snapshot-create-as $activevm snap-backup --disk-only --atomic --quiesce --no-metadata
        # если получилось
        if [ $? -eq 0 ]
            then
                for path in $disk_path
                    do
                        filename=`basename $path`
                        # копируем qcow2 файл в бэкап
                        cp -v $path $backup_dir/$filename-$data
                        # если получилось
                        if [ $? -eq 0 ]
                            then
                                # удаляем старые файлы
                                ls -d $backup_dir/* | grep $backup_dir"/"$filename | grep -v $backup_dir"/"$filename"-"$data | xargs -d"\n" rm -f
                        fi
                    done
                for disk in $disk_list
                    do
                        # путь до снэпшотов
                        snap_path=`virsh domblklist $activevm | grep $disk | awk '{print $2}'`
                        # commit снэпшот
                        virsh blockcommit $activevm $disk --active --verbose --pivot
                        # удаляем снэпшот
                        rm -f $snap_path
                    done
        # если снэпшоты не получились
        else
            echo "Backup error!"
        fi
    done
