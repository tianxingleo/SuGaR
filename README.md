<div align="center">

# SuGaR: Surface-Aligned Gaussian Splatting for Efficient 3D Mesh Reconstruction and High-Quality Mesh Rendering

<font size="4">
CVPR 2024
</font>
<br>

<font size="4">
<a href="https://anttwo.github.io/" style="font-size:100%;">Antoine Guédon</a>&emsp;
<a href="https://vincentlepetit.github.io/" style="font-size:100%;">Vincent Lepetit</a>&emsp;
</font>
<br>

<font size="4">
LIGM, Ecole des Ponts, Univ Gustave Eiffel, CNRS
</font>

| <a href="https://anttwo.github.io/sugar/">Webpage</a> | <a href="https://arxiv.org/abs/2311.12775">arXiv</a> | <a href="https://github.com/Anttwo/sugar_frosting_blender_addon/">Blender add-on</a> | <a href="https://www.youtube.com/watch?v=MAkFyWfiBQo">Presentation video</a> | <a href="https://www.youtube.com/watch?v=YbjE0wnw67I">Viewer video</a> |

<img src="./media/examples/walk.gif" alt="walk.gif" width="350"/><img src="./media/examples/attack.gif" alt="attack.gif" width="350"/> <br>
<b>Our method extracts meshes from 3D Gaussian Splatting reconstructions and builds hybrid representations <br>that enable easy composition and animation in Gaussian Splatting scenes by manipulating the mesh.</b>
</div>

## 🚀 What's New in This Fork

### Video-to-Model Pipeline
- **一键式流程**: 从视频直接到3D模型，无需手动处理COLMAP重建
- **自动化脚本**:
  - `sugar_video_pipeline.sh` - 完整pipeline（含mesh生成）
  - `sugar_fast_pipeline.sh` - 快速pipeline（跳过mesh，节省30-50%时间）
- **支持视频输入**: 使用FFmpeg自动抽帧，自适应分辨率

### Fast Training Mode
- **时间节省**: 快速模式跳过mesh extraction和refinement，节省30-50%训练时间
- **适用场景**: 只需要3DGS查看器，不需要mesh编辑
- **时间对比**:
  - 完整pipeline: ~30-60分钟
  - 快速pipeline: ~15-30分钟

### CUDA 12.8 Compatibility
- **修复编译问题**: 修复了CUDA 12.8的编译错误
- **添加头文件**: 在`diff-gaussian-rasterization/cuda_rasterizer/rasterizer_impl.h`中添加`#include <cstdint>`
- **支持新GPU**: 兼容RTX 50系列和Blackwell架构

### Enhanced Documentation
- **环境检查**: `check_environment.py` - 自动验证所有依赖
- **快速入门**: `QUICKSTART.md` - 简洁的使用指南
- **详细文档**: `PIPELINE_README.md` - 完整的参数说明和故障排除
- **Pipeline对比**: `PIPELINE_COMPARISON.md` - 快速vs完整pipeline对比

### Regularization Method Updates
- **dn_consistency**: 深度-法线一致性正则化（推荐，最佳质量）
- **density**: 密度正则化（简单快速）
- **sdf**: 符号距离函数正则化（复杂背景场景）

## Abstract

_We propose a method to allow precise and extremely fast mesh extraction from <a href="https://repo-sam.inria.fr/fungraph/3d-gaussian-splatting/">3D Gaussian Splatting (SIGGRAPH 2023)</a>.
Gaussian Splatting has recently become very popular as it yields realistic rendering while being significantly faster to train than NeRFs. It is however challenging to extract a mesh from millions of tiny 3D Gaussians as these Gaussians tend to be unorganized after optimization and no method has been proposed so far.
Our first key contribution is a regularization term that encourages the 3D Gaussians to align well with the surface of the scene.
We then introduce a method that exploits this alignment to sample points on the real surface of the scene and extract a mesh from the Gaussians using Poisson reconstruction, which is fast, scalable, and preserves details, in contrast to the Marching Cubes algorithm usually applied to extract meshes from Neural SDFs.
Finally, we introduce an optional refinement strategy that binds Gaussians to the surface of the mesh, and jointly optimizes these Gaussians and the mesh through Gaussian splatting rendering. This enables easy editing, sculpting, rigging, animating, or relighting of the Gaussians using traditional softwares (Blender, Unity, Unreal Engine, etc.) by manipulating the mesh instead of the Gaussians themselves.
Retrieving such an editable mesh for realistic rendering is done within minutes with our method, compared to hours with the state-of-the-art method on neural SDFs, while providing a better rendering quality in terms of PSNR, SSIM and LPIPS._

<div align="center">
<b>Hybrid representation (Mesh + Gaussians on the surface)</b><br>
<img src="./media/overview/garden_hybrid.gif" alt="garden_hybrid.gif" width="250"/>
<img src="./media/overview/kitchen_hybrid.gif" alt="kitchen_hybrid.gif" width="250"/>
<img src="./media/overview/counter_hybrid.gif" alt="counter_hybrid.gif" width="250"/><br>
<img src="./media/overview/playroom_hybrid.gif" alt="playroom_hybrid.gif" width="323"/>
<img src="./media/overview/qant03_hybrid.gif" alt="qant03_hybrid.gif" width="323"/>
<img src="./media/overview/dukemon_hybrid.gif" alt="dukemon_hybrid.gif" width="102"/><br>
<b>Underlying mesh without texture</b><br>
<img src="./media/overview/garden_notex.gif" alt="garden_notex.gif" width="250"/>
<img src="./media/overview/kitchen_notex.gif" alt="kitchen_notex.gif" width="250"/>
<img src="./media/overview/counter_notex.gif" alt="counter_notex.gif" width="250"/><br>
<img src="./media/overview/playroom_notex.gif" alt="playroom_notex.gif" width="323"/>
<img src="./media/overview/qant03_notex.gif" alt="qant03_notex.gif" width="323"/>
<img src="./media/overview/dukemon_notex.gif" alt="dukemon_notex.gif" width="102"/><br>
</div>


## BibTeX

```
@article{guedon2023sugar,
  title={SuGaR: Surface-Aligned Gaussian Splatting for Efficient 3D Mesh Reconstruction and High-Quality Mesh Rendering},
  author={Guédon, Antoine and Lepetit, Vincent},
  journal={CVPR},
  year={2024}
}
```

## 🚀 Quick Start

### Option 1: Video to Model (Recommended)

Use our automated pipeline to convert a video to a 3D model:

```bash
# Fast mode (30-50% faster, no mesh)
./sugar_fast_pipeline.sh <video_path> <scene_name>

# Full mode (includes mesh extraction)
./sugar_video_pipeline.sh <video_path> <scene_name> <regularization_method>
```

**Examples:**
```bash
# Fast test
./sugar_fast_pipeline.sh ~/video.mp4 my_scene

# High quality with dn_consistency
./sugar_video_pipeline.sh ~/video.mp4 my_scene dn_consistency medium true

# Complex scene with sdf
./sugar_video_pipeline.sh ~/video.mp4 complex sdf medium true
```

**Time Comparison (RTX 5070):**
- Fast pipeline: ~15-30 minutes
- Full pipeline: ~30-60 minutes

See [QUICKSTART.md](QUICKSTART.md) for detailed usage instructions.

### Option 2: Traditional COLMAP Workflow

Use the original workflow with a COLMAP dataset:

```bash
# From scratch
python train_full_pipeline.py -s <path to COLMAP dataset> -r dn_consistency --high_poly True --export_obj True

# From existing vanilla 3DGS model
python train_full_pipeline.py -s <path to COLMAP dataset> -r dn_consistency --high_poly True --export_obj True --gs_output_dir <path to vanilla 3DGS output>
```

### Option 3: Fast Training Only

If you only need the 3D Gaussian Splatting model without mesh:

```bash
# Fast training (2k iterations)
python train_fast.py -s <path to COLMAP dataset> -r dn_consistency --fast_mode

# Regular fast training (15k iterations)
python train_fast.py -s <path to COLMAP dataset> -r dn_consistency
```

### Check Your Environment

Before starting, verify your setup:

```bash
python check_environment.py
```

This script checks:
- Python version
- PyTorch and CUDA installation
- GPU availability
- All required packages
- External tools (FFmpeg, COLMAP)

## Overview

As we explain in the paper, SuGaR optimization starts with first optimizing a 3D Gaussian Splatting model for 7k iterations with no additional regularization term. Consequently, the current implementation contains a version of the original <a href="https://github.com/graphdeco-inria/gaussian-splatting">3D Gaussian Splatting code</a>, and we built our model as a wrapper of a vanilla 3D Gaussian Splatting model.

The full SuGaR pipeline consists of 4 main steps, and an optional one:
1. **Short vanilla 3DGS optimization**: optimizing a vanilla 3D Gaussian Splatting model for 7k iterations, in order to let Gaussians position themselves in the scene.
2. **SuGaR optimization**: optimizing Gaussians alignment with the surface of the scene.
3. **Mesh extraction**: extracting a mesh from the optimized Gaussians.
4. **SuGaR refinement**: refining the Gaussians and the mesh together to build a hybrid Mesh+Gaussians representation.
5. **Textured mesh extraction (Optional)**: extracting a traditional textured mesh from the refined SuGaR model as a tool for visualization, composition and animation in Blender using our <a href="https://github.com/Anttwo/sugar_frosting_blender_addon/">Blender add-on</a>.

We provide dedicated scripts for each of these steps, as well as a script `train_full_pipeline.py` that runs the entire pipeline.

<div align="center">
<br>
<img src="./media/blender/blender_edit.png" alt="blender_edit.png" height="200"/>
<img src="./media/examples/attack.gif" alt="attack.gif" height="200"/>
<br>
<b>You can visualize, edit, combine or animate the reconstructed textured meshes in Blender <i>(left)</i> <br>and render the result with SuGaR <i>(right)</i> thanks to our <a href="https://github.com/Anttwo/sugar_frosting_blender_addon/">Blender add-on</a>.</b><br>
</div>

Please note that the final step, _Textured mesh extraction_, is optional but is enabled by default in the `train_full_pipeline.py` script. Indeed, it is very convenient to have a traditional textured mesh for visualization, composition and animation using traditional softwares such as <a href="https://github.com/Anttwo/sugar_frosting_blender_addon/">Blender</a>. If you installed Nvdiffrast as described below, this step should only take a few seconds anyway.

## 📋 Pipeline Comparison

| Feature | Fast Pipeline | Full Pipeline |
|----------|---------------|--------------|
| **Training Time** | ~15-30 min | ~30-60 min |
| **Mesh Output** | ❌ No | ✅ Yes (PLY + OBJ) |
| **Textures** | ❌ No | ✅ Yes |
| **Use Case** | Quick preview | Production ready |
| **Blender Editing** | ❌ No | ✅ Yes |
| **3DGS Quality** | ✅ Good | ✅ Better |
| **VRAM Usage** | ⬇️ Lower | ⬆️ Higher |

**Recommendation:** Use fast pipeline for testing and iteration, then use full pipeline for the final production version.

See [PIPELINE_COMPARISON.md](PIPELINE_COMPARISON.md) for detailed comparison.

## Installation

### Requirements

The software requirements are the following:
- **Conda** (recommended for easy setup)
- **C++ Compiler** for PyTorch extensions
- **CUDA Toolkit 11.8** or **12.8** (both supported)
- C++ Compiler and CUDA SDK must be compatible

**Note:** This fork is tested and optimized for CUDA 12.8 with RTX 50-series GPUs.

### Clone the Repository

```bash
# HTTPS
git clone https://github.com/tianxingleo/SuGaR.git --recursive

# Or use the original repository
git clone https://github.com/Anttwo/SuGaR.git --recursive
```

### Creating the Conda Environment

**Option A: Using Existing Environment (Recommended for CUDA 12.8)**

If you have an existing conda environment (e.g., `gs_linux_backup`) with PyTorch 2.10.0+ and CUDA 12.8:

```bash
conda activate gs_linux_backup
cd gaussian_splatting/submodules/diff-gaussian-rasterization/
pip install --no-build-isolation -e .
cd ../simple-knn/
pip install --no-build-isolation -e .
```

**Option B: Create New Environment**

```bash
python install.py
conda activate sugar
```

This script will automatically create a Conda environment named `sugar` and install all required packages. It will also automatically install the <a href="https://github.com/graphdeco-inria/gaussian-splatting">3D Gaussian Splatting</a> rasterizer as well as the <a href="https://nvlabs.github.io/nvdiffrast/">Nvdiffrast</a> library for faster mesh rasterization.

### Install Additional Packages

For the video pipeline, you'll also need:

```bash
pip install open3d pymcubes
```

### Verify Installation

```bash
python check_environment.py
```

All checks should pass for CUDA 12.8 environment.

## Training Parameters

### Regularization Methods

| Method | Description | Best For | Speed |
|---------|-------------|-----------|--------|
| `dn_consistency` | Depth-Normal consistency (recommended) | General purpose | Medium |
| `density` | Density regularization | Object-centered scenes | Fast |
| `sdf` | Signed Distance Function | Complex backgrounds | Slow |

### Mesh Quality

| Option | Vertices | Gaussians per Triangle | Use Case |
|---------|-----------|---------------------|----------|
| `--low_poly` | 200,000 | 6 | Quick preview |
| `--high_poly` | 1,000,000 | 1 | Production quality |

### Refinement Time

| Option | Iterations | Time (RTX 5070) | Use Case |
|---------|------------|-------------------|----------|
| `--refinement_time short` | 2,000 | ~2-5 min | Quick preview |
| `--refinement_time medium` | 7,000 | ~10-15 min | Balanced |
| `--refinement_time long` | 15,000 | ~20-30 min | Best quality |

## Visualizing Results

### 1. SuGaR Built-in Viewer

```bash
python run_viewer.py -p output/refined_ply/<scene_name>/
```

### 2. Online Viewer (SuperSplat)

1. Visit: https://playcanvas.com/supersplat/editor
2. Click "Import PLY"
3. Select: `output/refined_ply/<scene_name>/<scene_name>.ply`

### 3. Blender Editing

1. Install the Blender add-on: https://github.com/Anttwo/sugar_frosting_blender_addon
2. Import: `output/refined_mesh/<scene_name>.obj`
3. Edit, animate, or compose in Blender
4. Export rendering package
5. Render with SuGaR:

```bash
python render_blender_scene.py -p <rendering_package_path>
```

## Documentation

- **[QUICKSTART.md](QUICKSTART.md)** - 快速入门指南
- **[PIPELINE_README.md](PIPELINE_README.md)** - 详细文档和使用说明
- **[PIPELINE_COMPARISON.md](PIPELINE_COMPARISON.md)** - Pipeline对比

## Troubleshooting

### CUDA 12.8 Compilation Issues

If you encounter compilation errors with CUDA 12.8:

**Error:** `error: namespace "std" has no member "uintptr_t"`

**Solution:** The fix is already applied in this fork. The file `rasterizer_impl.h` now includes `#include <cstdint>`. If you see this error, make sure you're using the latest version from this fork.

### COLMAP Reconstruction Fails

**Symptoms:** Point cloud is too sparse (<10 KB)

**Solutions:**
1. Use a longer video
2. Lower frame extraction rate (fps < 1)
3. Ensure multi-angle shooting

### Mesh Has Holes

**Symptoms:** Extracted mesh has missing regions

**Solution:** Edit `sugar_extractors/coarse_mesh.py`:
```python
vertices_density_quantile = 0.0  # Line 43, lower threshold
```

### Mesh Surface Has Bumps

**Symptoms:** Mesh surface has strange protrusions

**Solution:** Edit `sugar_extractors/coarse_mesh.py`:
```python
poisson_depth = 7  # Line 42, reduce depth
```

## Performance Benchmarks (RTX 5070)

| Scene Type | Frames | Fast Pipeline | Full Pipeline |
|-------------|--------|---------------|---------------|
| Simple Object | 50 | ~15 min | ~30 min |
| Medium Scene | 100 | ~22 min | ~45 min |
| Complex Scene | 200 | ~30 min | ~60 min |

## Updates and To-do list

<details>
<summary><span style="font-weight: bold;">Updates in This Fork</span></summary>
<ul>
  <li><b>[2024-02-16]</b> Added video-to-model pipeline with fast and full modes</li>
  <li><b>[2024-02-16]</b> Fixed CUDA 12.8 compilation issues</li>
  <li><b>[2024-02-16]</b> Added environment checking script</li>
  <li><b>[2024-02-16]</b> Added comprehensive documentation</li>
  <li><b>[09/18/2024]</b> Improved quality of extracted meshes with the new `dn_consistency` regularization method</li>
  <li><b>[01/09/2024]</b> Added a dedicated, real-time viewer to let users visualize and navigate in reconstructed scenes</li>
  <li><b>[12/20/2023]</b> Added a short notebook showing how to render images with the hybrid representation</li>
  <li><b>[12/18/2023]</b> Code release.</li>
</ul>
</details>
<br>

<details>
<summary><span style="font-weight: bold;">Original To-do list</span></summary>
<ul>
  <li><b>Viewer:</b> Add option to load the postprocessed mesh.</li>
  <li><b>Mesh extraction:</b> Add the possibility to edit the extent of the background bounding box.</li>
  <li><b>Tips&Tricks:</b> Add to the README.md file (and webpage) some tips and tricks for using SuGaR on your own data and obtain better reconstructions (see the tips provided by user kitmallet).</li>
  <li><b>Improvement:</b> Add an <code>if</code> block to <code>sugar_extractors/coarse_mesh.py</code> to skip foreground mesh reconstruction and avoid triggering an error if no surface point is detected inside the foreground bounding box. This can be useful for users that want to reconstruct <i>background scenes</i>.</li>
  <li><b>Using precomputed masks with SuGaR:</b> Add a mask functionality to the SuGaR optimization, to allow the user to mask out some pixels in the training images (like white backgrounds in synthetic datasets).</li>
  <li><b>Using SuGaR with Windows:</b> Adapt the code to make it compatible with Windows. Due to path-writing conventions, the current code is not compatible with Windows.</li>
  <li><b>Synthetic datasets:</b> Add the possibility to use the NeRF synthetic dataset (which has a different format than COLMAP scenes).</li>
  <li><b>Composition and animation:</b> Finish to clean the code for composition and animation, and add it to the <code>sugar_scene/sugar_compositor.py</code> script.</li>
  <li><b>Composition and animation:</b> Make a tutorial on how to use the scripts in the <code>blender</code> directory and the <code>sugar_scene/sugar_compositor.py</code> class to import composition and animation data into PyTorch and apply it to the SuGaR hybrid representation.</li>
</ul>
</details>

## Citation

If you use this code or the original SuGaR implementation, please cite our paper:

```bibtex
@article{guedon2023sugar,
  title={SuGaR: Surface-Aligned Gaussian Splatting for Efficient 3D Mesh Reconstruction and High-Quality Mesh Rendering},
  author={Guédon, Antoine and Lepetit, Vincent},
  journal={CVPR},
  year={2024}
}
```

## Acknowledgments

- Original SuGaR implementation: <a href="https://github.com/Anttwo/SuGaR">Anttwo/SuGaR</a>
- 3D Gaussian Splatting: <a href="https://github.com/graphdeco-inria/gaussian-splatting">graphdeco-inria/gaussian-splatting</a>
- PyTorch3D: <a href="https://github.com/facebookresearch/pytorch3d">facebookresearch/pytorch3d</a>
- Nvdiffrast: <a href="https://nvlabs.github.io/nvdiffrast/">NVlabs/nvdiffrast</a>

## License

This project is licensed under the same terms as the original SuGaR repository. Please see the [LICENSE.md](LICENSE.md) file for details.

---

**Fork by:** <a href="https://github.com/tianxingleo">tianxingleo</a>

**Original by:** <a href="https://github.com/Anttwo">Anttwo</a>

**Updates in this fork:**
- ✅ Video-to-model automated pipeline
- ✅ Fast training mode (30-50% faster)
- ✅ CUDA 12.8 compatibility
- ✅ Enhanced documentation
- ✅ Environment validation scripts
