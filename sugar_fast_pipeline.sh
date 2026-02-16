#!/bin/bash

# SuGaR 快速视频到模型Pipeline（无mesh生成）
# 用法: ./sugar_fast_pipeline.sh <视频路径> <场景名称> [正则化方法] [快速模式]

set -e

# ================= 配置 =================
VIDEO_PATH=$1
SCENE_NAME=$2
REGULARIZATION=${3:-"dn_consistency"}
FAST_MODE=${4:-"true"}  # 默认启用快速模式

if [ -z "$VIDEO_PATH" ] || [ -z "$SCENE_NAME" ]; then
    echo "用法: ./sugar_fast_pipeline.sh <视频路径> <场景名称> [正则化方法] [快速模式]"
    echo ""
    echo "参数说明:"
    echo "  <视频路径>      输入视频文件路径"
    echo "  <场景名称>      输出场景名称"
    echo "  [正则化方法]    dn_consistency(推荐), density, sdf"
    echo "  [快速模式]      true(默认) 或 false"
    echo ""
    echo "示例:"
    echo "  ./sugar_fast_pipeline.sh ~/video.mp4 my_scene"
    echo "  ./sugar_fast_pipeline.sh ~/video.mp4 my_scene dn_consistency true"
    echo "  ./sugar_fast_pipeline.sh ~/video.mp4 my_scene sdf true"
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

if ! $COLMAP_EXE help | grep -q "global_mapper"; then
    USE_INCREMENTAL=true
else
    USE_INCREMENTAL=false
fi

echo "==================== SuGaR 快速Pipeline（无mesh） ===================="
echo "视频: $VIDEO_PATH"
echo "场景名称: $SCENE_NAME"
echo "正则化方法: $REGULARIZATION"
echo "快速模式: $FAST_MODE"
echo "输出目录: $OUTPUT_DIR"
echo ""
echo "⚡ 快速模式优势:"
echo "  - 跳过mesh extraction（节省15-20%时间）"
echo "  - 跳过refinement阶段（节省15-30%时间）"
echo "  - 总计节省约30-50%的训练时间"
echo ""

# ================= 步骤 1: 视频抽帧 =================
echo "==== [1/4] 视频抽帧 ===="
rm -rf "$DATA_DIR"
mkdir -p "$DATA_DIR/input"

ffmpeg -i "$VIDEO_PATH" \
    -vf "fps=2,scale='if(gt(iw,ih),1920,1080)':'if(gt(iw,ih),1080,1920)':force_original_aspect_ratio=decrease" \
    "$DATA_DIR/input/%04d.jpg" \
    -y -loglevel error

FRAME_COUNT=$(ls -1 "$DATA_DIR/input"/*.jpg | wc -l)
echo "✅ 抽帧完成: $FRAME_COUNT 帧"

# ================= 步骤 2: COLMAP 位姿估计 =================
echo "==== [2/4] COLMAP 位姿估计 ===="
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
    echo "    使用增量式重建..."
    $COLMAP_EXE mapper \
        --database_path "$DATA_DIR/distorted/database.db" \
        --image_path "$DATA_DIR/input" \
        --output_path "$DATA_DIR/distorted/sparse" \
        --Mapper.ba_global_function_tolerance=0.000001
else
    echo "    使用全局重建..."
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

# 2.5 整理文件
mkdir -p "$DATA_DIR/sparse/0"
mv "$DATA_DIR/sparse"/*.bin "$DATA_DIR/sparse/0/" 2>/dev/null || true

# ================= 步骤 3: 验证 COLMAP 结果 =================
echo "==== [3/4] 验证 COLMAP 重建 ===="
SPARSE_DIR="$DATA_DIR/sparse/0"

if [ ! -f "$SPARSE_DIR/cameras.bin" ] || [ ! -f "$SPARSE_DIR/points3D.bin" ]; then
    echo "❌ 错误: COLMAP未能生成位姿文件"
    exit 1
fi

POINTS_SIZE=$(stat -c%s "$SPARSE_DIR/points3D.bin" 2>/dev/null || echo "0")
POINTS_SIZE_KB=$((POINTS_SIZE / 1024))

if [ "$POINTS_SIZE_KB" -lt 10 ]; then
    echo "❌ 错误: 点云太稀疏 ($POINTS_SIZE_KB KB)"
    exit 1
fi

IMAGE_COUNT=$(python3 -c "
import struct
with open('$SPARSE_DIR/images.bin', 'rb') as f:
    f.read(8)
    num_images = struct.unpack('Q', f.read(8))[0]
    print(num_images)
" 2>/dev/null || echo "0")

echo "✅ COLMAP 重建成功!"
echo "  - 点云: $POINTS_SIZE_KB KB"
echo "  - 图片: $IMAGE_COUNT"

# ================= 步骤 4: SuGaR 快速训练 =================
echo "==== [4/4] SuGaR 快速训练（无mesh）====="

# 清理端口
PORT_PID=$(netstat -nlp 2>/dev/null | grep :6009 | awk '{print $7}' | cut -d'/' -f1)
if [ ! -z "$PORT_PID" ]; then
    echo "  清理端口 6009..."
    kill -9 $PORT_PID 2>/dev/null || true
    sleep 1
fi

# 构建训练命令
TRAIN_CMD="python train_fast.py -s \"$DATA_DIR\" -r $REGULARIZATION"

if [ "$FAST_MODE" = "true" ]; then
    TRAIN_CMD="$TRAIN_CMD --fast_mode"
fi

echo "  训练命令: $TRAIN_CMD"
echo ""
echo "  开始训练..."

python train_fast.py -s "$DATA_DIR" -r $REGULARIZATION ${FAST_MODE:+--fast_mode}

# ================= 完成 =================
echo ""
echo "==================== ✨ 快速Pipeline完成! ===================="
echo ""
echo "✅ 训练完成（跳过了mesh生成和refinement）"
echo ""

# 查找输出目录。SuGaR 默认保存在 output/vanilla_gs/$SCENE_NAME
FINAL_OUTPUT_DIR="output/vanilla_gs/$SCENE_NAME"

echo "输出文件:"
echo "  - Checkpoints & Results: $FINAL_OUTPUT_DIR/"
echo "  - Point Cloud: $FINAL_OUTPUT_DIR/point_cloud/"
echo ""
echo "下一步操作:"
echo ""
echo "1. 使用SuGaR查看器:"
echo "   python run_viewer.py -p $FINAL_OUTPUT_DIR/"
echo ""
echo "2. 如果需要生成mesh，运行完整pipeline:"
echo "   python train_full_pipeline.py -s \"$DATA_DIR\" -r $REGULARIZATION \\"
echo "     --gs_output_dir $FINAL_OUTPUT_DIR --refinement_time short"
echo ""
echo "时间对比（RTX 5070）:"
echo "  - 完整pipeline: ~30-60分钟"
echo "  - 快速pipeline: ~15-30分钟（节省50%）"
echo ""
