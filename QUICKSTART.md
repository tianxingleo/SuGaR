# SuGaR Pipeline 使用说明

## 📋 概述

`./sugar_video_pipeline.sh` 是一个从视频到SuGaR 3D模型的完整自动化流程脚本。

**环境检查状态**: ✅ 所有检查通过!

---

## 🚀 快速开始

### 1. 基本用法
```bash
cd /home/ltx/projects/SuGaR

# 激活环境
conda activate gs_linux_backup

# 运行pipeline
./sugar_video_pipeline.sh <视频路径> <场景名称>
```

**示例**:
```bash
./sugar_video_pipeline.sh ~/video.mp4 my_scene
```

### 2. 自定义参数
```bash
./sugar_video_pipeline.sh <视频路径> <场景名称> <正则化方法> <精炼时间> <高精度>
```

**完整示例**:
```bash
# 高质量重建 (推荐)
./sugar_video_pipeline.sh ~/video.mp4 my_scene dn_consistency medium true

# 快速测试
./sugar_video_pipeline.sh ~/video.mp4 test dn_consistency short false

# 复杂背景场景
./sugar_video_pipeline.sh ~/video.mp4 complex sdf medium true
```

---

## 📝 参数详解

| 参数 | 类型 | 说明 | 默认值 | 可选值 |
|------|------|------|--------|---------|
| `<视频路径>` | 必填 | 输入视频文件 | - | - |
| `<场景名称>` | 必填 | 输出目录名称 | - | - |
| `<正则化方法>` | 可选 | Gaussian对齐策略 | `dn_consistency` | `dn_consistency`, `density`, `sdf` |
| `<精炼时间>` | 可选 | 网格精炼迭代数 | `short` | `short`(2k), `medium`(7k), `long`(15k) |
| `<高精度>` | 可选 | 网格顶点数 | `true` | `true`(1M), `false`(200k) |

---

## 🎯 正则化方法选择

### dn_consistency (推荐 ⭐)
- **最适合**: 通用场景
- **效果**: 最高质量
- **时间**: 中等
- **说明**: 深度-法线一致性约束，最新方法

```bash
./sugar_video_pipeline.sh video.mp4 scene dn_consistency medium true
```

### density
- **最适合**: 物体居中的简单场景
- **效果**: 良好
- **时间**: 最快
- **说明**: 密度正则化，简单快速

```bash
./sugar_video_pipeline.sh video.mp4 scene density short false
```

### sdf
- **最适合**: 复杂背景或大场景
- **效果**: 背景效果好
- **时间**: 较长
- **说明**: 符号距离函数约束

```bash
./sugar_video_pipeline.sh video.mp4 scene sdf medium true
```

---

## 📁 输出文件结构

```
SuGaR/
├── data/
│   └── <场景名称>/
│       ├── input/           # 原始帧
│       ├── images/          # 去畸变后的图像
│       └── sparse/0/       # COLMAP位姿文件
└── output/
    └── <场景名称>/
        ├── refined_ply/     # 3D Gaussian PLY文件
        │   └── <场景名称>.ply
        ├── refined_mesh/    # 传统网格文件
        │   └── <场景名称>.obj
        ├── coarse_mesh/     # 粗糙网格
        └── point_cloud/    # 点云
```

---

## 👁️ 查看结果

### 方法 1: SuGaR内置查看器 (推荐)
```bash
python run_viewer.py -p output/refined_ply/<场景名称>/
```

### 方法 2: SuperSplat 在线查看器
1. 访问: https://playcanvas.com/supersplat/editor
2. 点击 "Import PLY"
3. 选择: `output/refined_ply/<场景名称>/<场景名称>.ply`

### 方法 3: Blender 编辑
1. 安装 Blender Add-on: https://github.com/Anttwo/sugar_frosting_blender_addon
2. 导入: `output/refined_mesh/<场景名称>.obj`
3. 在Blender中编辑、动画、渲染

### 方法 4: 渲染Blender场景
```bash
# 使用Blender导出的渲染包
python render_blender_scene.py -p <rendering_package_path>
```

---

## 📊 性能参考 (RTX 5070)

| 场景类型 | 帧数 | dn_consistency (medium) | density (short) |
|---------|--------|------------------------|-----------------|
| 简单物体 | 50 | ~15分钟 | ~10分钟 |
| 中等场景 | 100 | ~30分钟 | ~20分钟 |
| 复杂场景 | 200 | ~60分钟 | ~40分钟 |

---

## 🎬 视频拍摄建议

### ✅ 好的视频
- 多角度覆盖 (360度环绕拍摄)
- 缓慢平稳移动
- 禁用自动对焦
- 固定曝光
- 适当距离 (0.5-2米)

### ❌ 不好的视频
- 单角度拍摄
- 快速移动 (运动模糊)
- 焦距变化
- 曝光剧烈变化
- 距离太远或太近

### 抽帧参数调整
默认: `fps=1` (每秒1帧)

根据视频长度调整:

| 视频长度 | 建议fps | 预期帧数 |
|-----------|----------|-----------|
| 10秒 | 2 | ~20帧 |
| 30秒 | 1 | ~30帧 |
| 1分钟 | 1 | ~60帧 |
| 2分钟 | 0.5 | ~60帧 |

**如何修改**:
编辑 `sugar_video_pipeline.sh` 中的 `ffmpeg` 命令:
```bash
ffmpeg -i "$VIDEO_PATH" -vf "fps=0.5,..." ...
```

---

## 🔧 故障排除

### COLMAP重建失败
**症状**: `点云太稀疏` 错误

**解决方案**:
1. 使用更长的视频
2. 降低抽帧率 (fps < 1)
3. 确保多角度拍摄

### 训练不收敛
**症状**: Loss不下降

**解决方案**:
1. 增加训练帧数
2. 检查COLMAP重建质量
3. 尝试不同正则化方法

### 网格有洞
**症状**: 网格缺失区域

**解决方案**:
编辑 `sugar_extractors/coarse_mesh.py`:
```python
vertices_density_quantile = 0.0  # 第43行，降低阈值
```

### 网格表面有 bumps
**症状**: 网格表面凸起

**解决方案**:
编辑 `sugar_extractors/coarse_mesh.py`:
```python
poisson_depth = 7  # 第42行，降低深度
```

---

## 📚 相关资源

- **SuGaR论文**: https://arxiv.org/abs/2311.12775
- **项目主页**: https://anttwo.github.io/sugar/
- **GitHub仓库**: https://github.com/Anttwo/SuGaR
- **Blender Add-on**: https://github.com/Anttwo/sugar_frosting_blender_addon
- **SuperSplat查看器**: https://github.com/playcanvas/supersplat

---

## 🎉 当前环境信息

```
✅ Python: 3.10.19
✅ PyTorch: 2.10.0.dev20251204+cu128
✅ CUDA: 12.8
✅ GPU: NVIDIA GeForce RTX 5070 (11.9 GB)
✅ diff-gaussian-rasterization
✅ simple-knn
✅ Open3D
✅ PyMCubes
✅ PyTorch3D
✅ FFmpeg
✅ COLMAP (支持glomap)
```

---

## 🚦 开始使用

```bash
# 1. 进入项目目录
cd /home/ltx/projects/SuGaR

# 2. 激活环境
conda activate gs_linux_backup

# 3. 运行环境检查 (可选)
python check_environment.py

# 4. 运行pipeline
./sugar_video_pipeline.sh <你的视频路径> <场景名称>
```

**示例**:
```bash
./sugar_video_pipeline.sh ~/my_video.mp4 my_first_scene
```

---

祝你使用愉快! 🎉
