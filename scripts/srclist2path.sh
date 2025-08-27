#!/bin/bash
#echo $(find ../ -name proj.config)
for path in $(find ../ -name proj.config); do 
    declare "$(sed s/PROJNAME=// $path)"="$(dirname ${path})"
done

srclist2paths () {
    srclist=$1
    #base_path="`dirname ${srclist} | xargs dirname`"
    #eval "echo list ${srclist}"
    #echo "src base $base_path"
    for srcfile in `eval "cat ${srclist}"`; do
        srcfile=`eval "echo ${srcfile}"`
        if [[ "`basename ${srcfile}`" =~ ".srclist" ]] ; then
            srclist2paths "${srcfile}"
        else 
            if [[ ! "${list}" =~ "${srcfile}" ]] ; then
                #echo "Skeeping ${base_path}/${srcfile} already included in file list!"
            #else
                list="${list} ${srcfile}"
            fi
        fi    
    done
    #echo "final list ${list}"
    #retval=${list}
}



list=""
srclist2paths $@
echo "${list}"