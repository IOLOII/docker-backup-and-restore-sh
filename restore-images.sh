#!/bin/bash

# 输入参数为备份目录路径
backup_dir=$1

if [ -z "$backup_dir" ]; then
    echo "Usage: $0 <backup_directory>"
    exit 1
fi

if [ ! -d "$backup_dir" ]; then
    echo "Directory not found!"
    exit 1
fi

image_list_file="$backup_dir/image_list.txt"

if [ ! -f "$image_list_file" ]; then
    echo "Image list file not found in the backup directory."
    exit 1
fi

echo "Starting restore process..."

# 加载镜像并重新标记
while IFS= read -r line; do
    image_name_tag=$(echo $line | awk '{print $1}')
    original_image_name_tag=$(echo $line | awk '{print $1}') # 保存原始的名称和标签用于后续标记
    safe_image_name_tag=$(echo $image_name_tag | sed 's|[:/]|_|g') # 使用处理过的安全名称
    image_file="$backup_dir/$safe_image_name_tag.tar"
    
    if [ ! -f "$image_file" ]; then
        echo "Image file not found: $image_file"
        continue
    fi
    
    # 输出开始处理镜像的日志
    echo "Processing image: $original_image_name_tag from $image_file"
    
    # 加载镜像
    docker load -i "$image_file" > /dev/null
    if [ $? -ne 0 ]; then
        echo "Failed to load image from $image_file"
        continue
    fi
    
    # 查找新加载的未命名镜像ID（悬空镜像）
    loaded_image_id=$(docker images --filter "dangling=true" -q | tail -n 1)
    if [ -z "$loaded_image_id" ]; then
        echo "Could not find newly loaded dangling image for $original_image_name_tag"
        continue
    fi
    
    # 如果已有同名镜像存在，则先删除旧的镜像
    existing_image_id=$(docker images --filter "reference=${original_image_name_tag}" -q)
    if [ -n "$existing_image_id" ]; then
        docker rmi "$original_image_name_tag" > /dev/null
        if [ $? -ne 0 ]; then
            echo "Failed to remove existing image with name $original_image_name_tag"
            continue
        fi
    fi
    
    # 重新标记镜像
    docker tag "$loaded_image_id" "$original_image_name_tag"
    if [ $? -eq 0 ]; then
        echo "Successfully re-tagged image as $original_image_name_tag"
    else
        echo "Failed to re-tag image as $original_image_name_tag"
    fi
done < "$image_list_file"

echo "Restore completed."