#!/usr/bin/env bash
set -e
source /etc/profile

v_prefix="${1%/}"
v_name=$2

# 判断参数数量
[ ! $# -eq 2 ] && echo "Need 2 parameter:prefix_dir name" && exit -1

# 判断目录是否存在
[ ! -d $v_prefix ] && echo "Prefix directory does not exist" && exit -2

## 设置动态共享库文件动态装载目录/etc/ld.so.conf.d/$v_name.conf
tv_conf_array=("/etc/ld.so.conf" "/etc/ld.so.conf.d/*.conf")
tv_dir="$v_prefix/lib"
tv_file_type=".so" # 指定文件后缀
tv_exclude_array=("/lib" "/usr/lib" "/lib64" "/usr/lib64") # 指定例外路径
tv_lib_dir=$(find $tv_dir -name "*$tv_file_type" |sed 's|/[^/]*'"$tv_file_type"'||' | sort | uniq)

echo "Start setting /etc/ld.so.conf.d/$v_name.conf"
for cur_lib_dir in $tv_lib_dir
do
  if ! echo ${tv_exclude_array[@]} | grep -wq "^$cur_lib_dir"; then # 判断是否不是例外路径
    if ! cat $(echo ${tv_conf_array[@]}) | grep -q "^$cur_lib_dir$"; then # 判断是否没有设置过该路径
      if ls $cur_lib_dir | grep -q "$tv_file_type$"; then # 目录下有指定类型的文件
        echo "add directory $cur_lib_dir to /etc/ld.so.conf.d/$v_name.conf"
        echo "$cur_lib_dir" >> /etc/ld.so.conf.d/$v_name.conf
      fi
    fi
  fi
done
ldconfig -f /etc/ld.so.conf.d/$v_name.conf >/dev/null
echo -ne "\E[34m'$tv_dir' libraries in ldconfig output num: ";
ldconfig -p | grep " $tv_dir"|wc -l;
echo -ne "\E[0m\c";


## 设置环境变量
tv_conf_array=("/etc/profile" "/etc/profile.d/*.sh" "/etc/profile.d/*.csh")

# 设置变量子函数
function set_env_var()
{
if [ -d $tv_dir ] && ls $tv_dir | grep -q "$tv_file_type$"; then # 判断指定目录中指定类型文件存在
  if ! echo ${tv_exclude_array[@]} | grep -wq "^$tv_dir"; then # 判断是否不是例外路径
    if ! echo ${tv_conf_array[@]} | xargs grep -wq "^$tv_var_name" 2>/dev/null; then # 判断是否没有设置过该变量
      cat >> /etc/profile.d/$v_name.sh <<EOF 
# $tv_var_name ( $tv_dir )
${tv_var_name}_BAK=\$$tv_var_name
export $tv_var_name=$tv_dir:\$$tv_var_name
export $tv_var_name=\$(echo -n "\$$tv_var_name"|xargs -d":" -n1|sort|uniq|grep -v "^\$"|xargs|tr " " ":"  || echo -n "\$${tv_var_name}_BAK")

EOF
      source /etc/profile.d/$v_name.sh
    else
      echo -e "\E[33malready set environment variable $tv_var_name\E[0m";
    fi
    echo -e "\E[34madd $tv_dir to $tv_var_name in /etc/profile.d/$v_name.sh\E[0m";
  fi
fi
}

# 初始化程序专用变量文件
[ -e /etc/profile.d/$v_name.sh ] && cp -np /etc/profile.d/$v_name.sh /etc/profile.d/$v_name.sh.bak
cat /dev/null > /etc/profile.d/$v_name.sh

# 设置PKG_CONFIG_PATH变量(编译依赖它的软件时需要)
tv_dir="$v_prefix/lib/pkgconfig";
tv_file_type=".pc" # 指定文件后缀
tv_exclude_array=("/lib/pkgconfig" "/usr/lib/pkgconfig" "/lib64/pkgconfig" "/usr/lib64/pkgconfig") # 指定例外路径
tv_var_name="PKG_CONFIG_PATH"; set_env_var

# 设置编译时的头文件路径变量C_INCLUDE_PATH和CPLUS_INCLUDE_PATH（有些软件不用pkg-config）
tv_dir="$v_prefix/include";
tv_file_type=".h" # 指定文件后缀
tv_exclude_array=("/usr/include" "/usr/local/include") # 指定例外路径
tv_var_name="C_INCLUDE_PATH" ; set_env_var
tv_var_name="CPLUS_INCLUDE_PATH"; set_env_var

# 设置执行路径PATH变量
tv_dir="$v_prefix/bin";
tv_file_type=".*" # 指定文件后缀
tv_exclude_array=("/usr/local/bin" "/usr/bin" "/bin" "/root/bin") # 指定例外路径
tv_var_name="PATH"
set_env_var
tv_dir="$v_prefix/sbin";
tv_exclude_array=("/usr/local/sbin" "/usr/sbin" "/sbin") # 指定例外路径
set_env_var

# 设置man搜索路径MANPATH变量
tv_dir="$v_prefix/man";
tv_file_type=".*" # 指定文件后缀
tv_exclude_array=("/usr/man" "/usr/share/man" "/usr/local/man" "/usr/local/share/man" "/usr/X11R6/man") # 指定例外路径
tv_var_name="MANPATH"; set_env_var

# 没有内容的话删除程序专用变量文件
if [ $(cat /etc/profile.d/$v_name.sh | wc -l) -eq 0 ]; then
  rm -f /etc/profile.d/$v_name.sh
fi
