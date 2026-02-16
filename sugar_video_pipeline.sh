#!/bin/bash

# SuGaR: Surface-Aligned Gaussian Splatting 视频到模型完整流程
# 用法: ./sugar_video_pipeline.sh <视频路径> <场景名称> [正则化方法] [迭代次数]

set -e  # 任何命令失败立即退出

# ================= 配置 =================
VIDEO_PATH=$1           # 视频文件路径
SCENE_NAME=$2           # 场景名称
REGULARIZATION=${3:-"dn_consistency"}  # 正则化方法: dn_consistency, density, sdf (默认: dn_consistency)
REFINEMENT_TIME=${4:-"short"}          # 精炼时间: short, medium, long (默认: short)
HIGH_POLY=${5:-"true"}                 # 是否高精度网格: true/false (默认: true)

if [ -z "$VIDEO_PATH" ] || [ -z "$SCENE_NAME" ]; then
    echo "用法: ./sugar_video_pipeline.sh <视频路径> <场景名称> [正则化方法] [精炼时间] [高精度]"
    echo ""
    echo "参数说明:"
    echo "  <视频路径>           输入视频文件路径"
    echo "  <场景名称>           输出场景名称"
    echo "  [正则化方法]        dn_consistency (推荐), density, sdf"
    echo "  [精炼时间]          short (2k迭代), medium (7k), long (15k)"
    echo "  [高精度]            true (1M顶点), false (200k顶点)"
    echo ""
    echo "示例:"
    echo "  ./sugar_video_pipeline.sh ~/video.mp4 my_scene"
    echo "  ./sugar_video_pipeline.sh ~/video.mp4 my_scene density medium true"
    echo "  ./sugar_video_pipeline.sh ~/video.mp4 my_scene dn_consistency short false"
    exit 1
fi

# ================= 路径配置 =================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data/$SCENE_NAME"
OUTPUT_DIR="$SCRIPT_DIR/output/$SCENE_NAME"

# ================= 激活 Conda 环境 =================
CONDA_ENV="gs_linux_backup"
CONDA_BASE="/home/ltx/miniforge3"
source "$CONDA_BASE/etc/profile.d/conda.sh"
conda activate $CONDA_ENV

# ================= 环境变量 =================
export QT_QPA_PLATFORM=offscreen
export CUDA_VISIBLE_DEVICES=0
export DISTUTILS_USE_SDK=1

# WSL CUDA 路径修复
if [ -d "/usr/lib/wsl/lib" ]; then
    export LD_LIBRARY_PATH="/usr/lib/wsl/lib:$LD_LIBRARY_PATH"
fi

# ================= COLMAP 配置 =================
COLMAP_EXE="/usr/local/bin/colmap"
if [ ! -f "$COLMAP_EXE" ]; then
    COLMAP_EXE="colmap"
fi

# 检查是否支持 global_mapper
if ! $COLMAP_EXE help | grep -q "global_mapper"; then
    echo "⚠️ 警告: $COLMAP_EXE 不支持 glomap，使用标准增量式重建"
    USE_INCREMENTAL=true
else
    USE_INCREMENTAL=false
fi

echo "==================== SuGaR 视频到模型 Pipeline ===================="
echo "视频: $VIDEO_PATH"
echo "场景名称: $SCENE_NAME"
echo "正则化方法: $REGULARIZATION"
echo "精炼时间: $REFINEMENT_TIME"
echo "高精度网格: $HIGH_POLY"
echo "输出目录: $OUTPUT_DIR"
echo ""

# ================= 步骤 1: 视频抽帧 =================
echo "==== [1/5] 视频抽帧 ===="
rm -rf "$DATA_DIR"
mkdir -p "$DATA_DIR/input"

# 抽帧参数:
# - fps=1: 每秒1帧 (适合大多数场景)
# - 横屏缩放到 720x1280, 竖屏缩放到 1280x720
ffmpeg -i "$VIDEO_PATH" \
    -vf "fps=2,scale='if(gt(iw,ih),720,1280)':'if(gt(iw,ih),1280,720)':force_original_aspect_ratio=decrease" \
    "$DATA_DIR/input/%04d.jpg" \
    -y -loglevel error

FRAME_COUNT=$(ls -1 "$DATA_DIR/input"/*.jpg | wc -l)
echo "✅ 抽帧完成: $FRAME_COUNT 帧"

if [ $FRAME_COUNT -lt 30 ]; then
    echo "⚠️ 警告: 帧数较少 ($FRAME_COUNT < 30)，建议使用更长的视频或降低抽帧率"
fi

# ================= 步骤 2: COLMAP 位姿估计 (SfM) =================
echo "==== [2/5] COLMAP 位姿估计 ===="
mkdir -p "$DATA_DIR/distorted/sparse"

# 2.1 特征提取
echo "  2.1 特征提取..."
$COLMAP_EXE feature_extractor \
    --database_path "$DATA_DIR/distorted/database.db" \
    --image_path "$DATA_DIR/input" \
    --ImageReader.single_camera 1 \
    --ImageReader.camera_model OPENCV \
    --FeatureExtraction.use_gpu 1

# 2.2 特征匹配
echo "  2.2 特征匹配..."
$COLMAP_EXE exhaustive_matcher \
    --database_path "$DATA_DIR/distorted/database.db" \
    --FeatureMatching.use_gpu 1

# 2.3 稀疏重建
echo "  2.3 稀疏重建..."
if [ "$USE_INCREMENTAL" = true ]; then
    echo "    使用增量式重建 (mapper)..."
    $COLMAP_EXE mapper \
        --database_path "$DATA_DIR/distorted/database.db" \
        --image_path "$DATA_DIR/input" \
        --output_path "$DATA_DIR/distorted/sparse" \
        --Mapper.ba_global_function_tolerance=0.000001
else
    echo "    使用全局重建 (global_mapper/gloMAP)..."
    $COLMAP_EXE global_mapper \
        --database_path "$DATA_DIR/distorted/database.db" \
        --image_path "$DATA_DIR/input" \
        --output_path "$DATA_DIR/distorted/sparse"
fi

# 2.4 图像去畸变
echo "  2.4 图像去畸变..."
mkdir -p "$DATA_DIR/sparse"
$COLMAP_EXE image_undistorter \
    --image_path "$DATA_DIR/input" \
    --input_path "$DATA_DIR/distorted/sparse/0" \
    --output_path "$DATA_DIR" \
    --output_type COLMAP

# 2.5 整理文件结构
mkdir -p "$DATA_DIR/sparse/0"
mv "$DATA_DIR/sparse"/*.bin "$DATA_DIR/sparse/0/" 2>/dev/null || true

# ================= 步骤 3: 检查 COLMAP 结果 =================
echo "==== [3/5] 验证 COLMAP 重建质量 ===="
SPARSE_DIR="$DATA_DIR/sparse/0"

# 检查关键文件
if [ ! -f "$SPARSE_DIR/cameras.bin" ] || [ ! -f "$SPARSE_DIR/images.bin" ] || [ ! -f "$SPARSE_DIR/points3D.bin" ]; then
    echo "❌ 错误: COLMAP 未能生成完整的位姿文件"
    ls -la "$SPARSE_DIR"
    exit 1
fi

# 检查点云大小
POINTS_SIZE=$(stat -c%s "$SPARSE_DIR/points3D.bin" 2>/dev/null || echo "0")
POINTS_SIZE_KB=$((POINTS_SIZE / 1024))

if [ "$POINTS_SIZE_KB" -lt 10 ]; then
    echo "❌ 错误: COLMAP 生成的点云太稀疏 ($POINTS_SIZE_KB KB)"
    echo "提示: 请尝试:"
    echo "  1. 使用更长的视频"
    echo "  2. 降低抽帧率 (fps 参数)"
    echo "  3. 确保视频中场景有多角度拍摄"
    exit 1
fi

# 统计注册的图片数量
IMAGE_COUNT=$(python3 -c "
import struct
with open('$SPARSE_DIR/images.bin', 'rb') as f:
    f.read(8)  # header
    num_images = struct.unpack('Q', f.read(8))[0]
    print(num_images)
" 2>/dev/null || echo "0")

echo "✅ COLMAP 重建成功!"
echo "  - 点云大小: $POINTS_SIZE_KB KB"
echo "  - 注册图片: $IMAGE_COUNT"

if [ $IMAGE_COUNT -lt 30 ]; then
    echo "⚠️ 警告: 注册图片较少 ($IMAGE_COUNT < 30)，重建质量可能不佳"
fi

# ================= 步骤 4: SuGaR 训练 =================
echo "==== [4/5] SuGaR 训练 ===="

# 清理可能占用的端口
PORT_PID=$(netstat -nlp 2>/dev/null | grep :6009 | awk '{print $7}' | cut -d'/' -f1)
if [ ! -z "$PORT_PID" ]; then
    echo "  清理端口 6009..."
    kill -9 $PORT_PID 2>/dev/null || true
    sleep 1
fi

# 构建训练命令
TRAIN_CMD="python train_full_pipeline.py -s \"$DATA_DIR\" -r $REGULARIZATION"

if [ "$HIGH_POLY" = "true" ]; then
    TRAIN_CMD="$TRAIN_CMD --high_poly True"
else
    TRAIN_CMD="$TRAIN_CMD --low_poly True"
fi

TRAIN_CMD="$TRAIN_CMD --refinement_time $REFINEMENT_TIME"

echo "  训练命令: $TRAIN_CMD"
echo ""
echo "  开始训练..."

python train_full_pipeline.py -s "$DATA_DIR" -r $REGULARIZATION \
    ${HIGH_POLY:+--high_poly $HIGH_POLY} \
    ${LOW_POLY:+--low_poly $LOW_POLY} \
    --refinement_time $REFINEMENT_TIME

# ================= 步骤 5: 结果验证 =================
echo "==== [5/5] 验证输出 ===="

# SuGaR 会将结果分散保存在多个子目录中
REFINED_PLY_DIR="$SCRIPT_DIR/output/refined_ply/$SCENE_NAME"
REFINED_MESH_DIR="$SCRIPT_DIR/output/refined_mesh/$SCENE_NAME"

# 检查输出文件是否存在
if [ ! -d "$REFINED_PLY_DIR" ] && [ ! -d "$REFINED_MESH_DIR" ]; then
    echo "❌ 错误: 训练未能生成输出文件夹"
    echo "请检查 output/refined_ply/$SCENE_NAME 或 output/refined_mesh/$SCENE_NAME"
    exit 1
fi

echo "✅ 训练完成!"
echo ""
echo "输出文件:"

# 查找生成的 PLY 和 OBJ 文件（因为文件名包含参数，使用通配符）
PLY_FILE=$(ls "$REFINED_PLY_DIR"/*.ply 2>/dev/null | head -n 1)
OBJ_FILE=$(ls "$REFINED_MESH_DIR"/*.obj 2>/dev/null | head -n 1)

if [ ! -z "$PLY_FILE" ]; then
    echo "  - PLY 文件 (3DGS viewer): $PLY_FILE"
fi
if [ ! -z "$OBJ_FILE" ]; then
    echo "  - OBJ 文件 (传统网格): $OBJ_FILE"
fi

# ================= 完成 =================
echo ""
echo "==================== ✨ Pipeline 完成! ===================="
echo ""
echo "下一步操作:"
echo ""
echo "1. 使用 SuGaR 查看器:"
if [ ! -z "$PLY_FILE" ]; then
    echo "   python run_viewer.py -p \"$PLY_FILE\""
fi
echo ""
echo "2. 使用其他 3DGS 查看器:"
echo "   - SuperSplat (在线): https://playcanvas.com/supersplat/editor"
echo "   - SuperSplat (本地): 下载 https://github.com/playcanvas/supersplat"
echo ""
echo "3. 在 Blender 中编辑网格:"
echo "   - 安装 Blender add-on: https://github.com/Anttwo/sugar_frosting_blender_addon"
echo "   - 导入: $OUTPUT_DIR/refined_mesh/$SCENE_NAME.obj"
echo ""
echo "4. 渲染 Blender 场景:"
echo "   python render_blender_scene.py -p <rendering_package_path>"
echo ""
