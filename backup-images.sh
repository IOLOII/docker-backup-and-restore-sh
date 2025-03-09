#!/bin/bash

# 创建一个以当前日期时间命名的备份目录
backup_dir="docker_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$backup_dir"

# 创建一个文件用于存储镜像名和tag
image_list_file="$backup_dir/image_list.txt"
> "$image_list_file" # 清空文件内容（如果存在）

echo "Starting backup process..."

# 获取所有非 '<none>:<none>' 的镜像ID、名称和标签，并保存到指定文件中
docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep -v '<none>:<none>' | while read -r image; do
    image_name_tag=$(echo $image | awk '{print $1}')
    image_id=$(echo $image | awk '{print $2}')
    
    # 替换镜像名中的斜杠等特殊字符，以防止创建非法目录
    safe_image_name_tag=$(echo $image_name_tag | sed 's|[:/]|_|g')
    
    echo "$image_name_tag $image_id" >> "$image_list_file"
    
    # 输出开始处理镜像的日志
    echo "Processing image: $image_name_tag (ID: $image_id)"
    
    # 使用 docker save 命令导出镜像
    docker save -o "$backup_dir/$safe_image_name_tag.tar" $image_id
    
    if [ $? -eq 0 ]; then
        echo "Successfully exported image $image_name_tag to $backup_dir/$safe_image_name_tag.tar"
    else
        echo "Failed to export image $image_name_tag"
    fi
done

# 检查是否有足够的磁盘空间
free_space=$(df --output=avail "$backup_dir" | tail -n 1)
if [ "$free_space" -lt 1048576 ]; then # 小于1GB的空间
    echo "Warning: Insufficient disk space left for further backups."
else
    echo "Disk space is sufficient for further operations."
fi

echo "Backup completed successfully. Images are saved in '$backup_dir' and their names and tags are listed in '$image_list_file'."