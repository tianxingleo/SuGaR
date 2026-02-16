# SuGaR 视频到模型 Pipeline

## 简介

这个脚本提供了从视频到SuGaR 3D模型的一键式完整流程，包括：

1. **视频抽帧** - 自动从视频中提取关键帧
2. **COLMAP重建** - 自动进行位姿估计和稀疏重建
3. **SuGaR训练** - 自动训练SuGaR模型并提取网格
4. **结果验证** - 自动检查输出文件

## 快速开始

```bash
# 基本用法
./sugar_video_pipeline.sh <视频路径> <场景名称>

# 示例
./sugar_video_pipeline.sh ~/video.mp4 my_scene

# 自定义参数
./sugar_video_pipeline.sh ~/video.mp4 my_scene dn_consistency medium true
```

## 参数说明

| 参数 | 说明 | 可选值 | 默认值 |
|------|------|---------|---------|
| `<视频路径>` | 输入视频文件路径 | - | 必填 |
| `<场景名称>` | 输出场景名称（用于保存结果） | - | 必填 |
| `[正则化方法]` | 用于对齐Gaussian到表面的正则化方法 | `dn_consistency` (推荐), `density`, `sdf` | `dn_consistency` |
| `[精炼时间]` | 网格精炼阶段的时间 | `short` (2k迭代), `medium` (7k), `long` (15k) | `short` |
| `[高精度]` | 是否使用高精度网格 | `true` (1M顶点), `false` (200k顶点) | `true` |

## 正则化方法选择指南

### dn_consistency (推荐)
- **适用场景**: 大多数场景
- **特点**: 最新方法，质量最佳
- **优点**: 网格质量高，细节保留好
- **缺点**: 训练时间稍长

### density
- **适用场景**: 物体居中的简单场景
- **特点**: 最简单的正则化方法
- **优点**: 训练快，计算简单
- **缺点**: 背景区域质量较差

### sdf
- **适用场景**: 复杂背景或大场景
- **特点**: 使用SDF（符号距离函数）约束
- **优点**: 背景重建效果好
- **缺点**: 物体细节可能不如dn_consistency

## 使用示例

### 1. 快速测试 (低精度 + 短时间)
```bash
./sugar_video_pipeline.sh ~/test.mp4 test_scene dn_consistency short false
```

### 2. 高质量重建 (推荐设置)
```bash
./sugar_video_pipeline.sh ~/high_quality.mp4 my_scene dn_consistency medium true
```

### 3. 复杂背景场景
```bash
./sugar_video_pipeline.sh ~/complex_scene.mp4 complex_scene sdf medium true
```

### 4. 物体居中的简单场景
```bash
./sugar_video_pipeline.sh ~/simple_object.mp4 simple_object density short false
```

## 输出文件

训练完成后，结果保存在 `output/<场景名称>/` 目录：

| 文件/目录 | 说明 | 用途 |
|------------|------|------|
| `refined_ply/<scene_name>.ply` | 精炼后的3D Gaussians | 3DGS查看器 |
| `refined_mesh/<scene_name>.obj` | 传统纹理网格 | Blender/Unity/Unreal |
| `coarse_mesh/` | 粗糙网格 | 快速预览 |
| `point_cloud/` | 点云 | 检查重建质量 |

## 查看结果

### 1. 使用SuGaR内置查看器
```bash
python run_viewer.py -p output/refined_ply/<scene_name>/
```

### 2. 使用在线查看器 (SuperSplat)
1. 访问 https://playcanvas.com/supersplat/editor
2. 点击 "Import PLY"
3. 选择 `output/refined_ply/<scene_name>/<scene_name>.ply`

### 3. 使用本地SuperSplat查看器
```bash
# 下载SuperSplat
git clone https://github.com/playcanvas/supersplat.git
cd supersplat

# 启动
npm install
npm start
```

### 4. 在Blender中编辑
1. 安装SuGaR Blender Add-on:
   ```bash
   git clone https://github.com/Anttwo/sugar_frosting_blender_addon.git
   ```
2. 在Blender中启用插件
3. 导入 `output/refined_mesh/<scene_name>.obj`

## 拍摄建议

为了获得最佳重建效果，请遵循以下建议：

### 视频拍摄技巧
1. **多角度覆盖**: 围绕物体移动，确保从各个角度拍摄
2. **均匀移动**: 缓慢平稳地移动，避免运动模糊
3. **保持一致**: 
   - 禁用自动对焦 (保持焦距固定)
   - 使用固定曝光
4. **距离适中**: 保持适当的拍摄距离 (0.5-2米)

### 抽帧参数调整
脚本默认设置为 `fps=1` (每秒1帧)，适合大多数场景。根据视频长度调整：

| 视频长度 | 建议fps | 预期帧数 |
|-----------|----------|-----------|
| 10秒 | 1-2 | 10-20帧 |
| 30秒 | 1 | 30帧 |
| 1分钟 | 1 | 60帧 |
| 2分钟 | 0.5 | 60帧 |

在脚本中修改抽帧参数：
```bash
ffmpeg -i "$VIDEO_PATH" -vf "fps=0.5,..." ...
```

## 常见问题

### 1. COLMAP重建失败
**症状**: 点云太小或没有生成位姿文件

**解决方案**:
- 使用更长的视频
- 降低抽帧率 (fps < 1)
- 确保视频中有多角度拍摄

### 2. 训练不收敛
**症状**: Loss不下降，输出质量差

**解决方案**:
- 增加训练帧数 (使用更长的视频)
- 检查COLMAP重建质量
- 尝试不同的正则化方法

### 3. 网格有洞
**症状**: 提取的网格有缺失区域

**解决方案**:
编辑 `sugar_extractors/coarse_mesh.py`:
```python
vertices_density_quantile = 0.0  # 降低阈值
```

### 4. 网格表面有 bumps
**症状**: 网格表面有奇怪的凸起

**解决方案**:
编辑 `sugar_extractors/coarse_mesh.py`:
```python
poisson_depth = 7  # 降低深度
```

## 训练时间参考

基于 RTX 5070 的估计时间：

| 场景复杂度 | 帧数 | dn_consistency (medium) | density (short) |
|------------|--------|------------------------|-----------------|
| 简单物体 | 50 | ~15分钟 | ~10分钟 |
| 中等场景 | 100 | ~30分钟 | ~20分钟 |
| 复杂场景 | 200 | ~60分钟 | ~40分钟 |

## 技术细节

### 环境要求
- Python 3.10
- PyTorch 2.10.0+ (CUDA 12.8)
- CUDA 12.8
- COLMAP (建议支持glomap/global_mapper)
- FFmpeg (用于视频抽帧)

### Conda环境
脚本自动激活 `gs_linux_backup` 环境，确保以下包已安装：
- diff-gaussian-rasterization ✅
- simple-knn ✅
- open3d ✅
- PyMCubes ✅
- pytorch3d ✅

### 硬件要求
- GPU: NVIDIA RTX 5070 或更高
- VRAM: 推荐 8GB+ (12GB最佳)
- RAM: 推荐 32GB+

## 故障排除

### COLMAP找不到
```bash
# 检查COLMAP安装
colmap help

# 如果找不到，使用完整路径
sudo ln -s /usr/local/bin/colmap /usr/bin/colmap
```

### CUDA内存不足
```bash
# 降低图片分辨率
# 在脚本中修改 scale 参数:
ffmpeg -i "$VIDEO_PATH" -vf "fps=1,scale='1280:720'..." ...
```

### Python导入错误
```bash
# 重新安装依赖
conda activate gs_linux_backup
pip install diff-gaussian-rasterization simple-knn
```

## 参考资源

- [SuGaR官方仓库](https://github.com/Anttwo/SuGaR)
- [SuGaR论文](https://arxiv.org/abs/2311.12775)
- [项目主页](https://anttwo.github.io/sugar/)
- [SuGaR Blender Add-on](https://github.com/Anttwo/sugar_frosting_blender_addon)
- [3D Gaussian Splatting](https://github.com/graphdeco-inria/gaussian-splatting)
- [SuperSplat查看器](https://github.com/playcanvas/supersplat)

## 许可证

本脚本遵循SuGaR的许可证 (见LICENSE.md)
