#!/usr/bin/env python3
"""
SuGaR Pipeline 环境检查脚本
验证所有依赖是否正确安装
"""

import sys
import subprocess
import os

def check_python_version():
    """检查Python版本"""
    print("=" * 60)
    print("1. Python 环境")
    print("=" * 60)
    version = sys.version_info
    print(f"Python 版本: {version.major}.{version.minor}.{version.micro}")

    if version.major == 3 and version.minor == 10:
        print("✅ Python 3.10 - 完美!")
    elif version.major == 3:
        print(f"⚠️ Python 3.{version.minor} - 可用，但建议使用3.10")
    else:
        print(f"❌ Python {version.major}.{version.minor} - 不支持")
        return False

    return True

def check_conda_env():
    """检查Conda环境"""
    print("\n" + "=" * 60)
    print("2. Conda 环境")
    print("=" * 60)
    env = os.environ.get('CONDA_DEFAULT_ENV')
    if env:
        print(f"当前环境: {env}")
        if env == "gs_linux_backup":
            print("✅ 正在使用 gs_linux_backup 环境")
        else:
            print(f"⚠️ 正在使用 {env} 环境，建议使用 gs_linux_backup")
    else:
        print("❌ 未激活Conda环境")
        return False

    return True

def check_torch():
    """检查PyTorch和CUDA"""
    print("\n" + "=" * 60)
    print("3. PyTorch 和 CUDA")
    print("=" * 60)
    try:
        import torch
        print(f"PyTorch 版本: {torch.__version__}")
        print(f"CUDA 可用: {torch.cuda.is_available()}")

        if torch.cuda.is_available():
            cuda_version = torch.version.cuda
            device_count = torch.cuda.device_count()
            print(f"CUDA 版本: {cuda_version}")
            print(f"CUDA 设备数: {device_count}")

            for i in range(device_count):
                device_name = torch.cuda.get_device_name(i)
                device_cap = torch.cuda.get_device_properties(i)
                print(f"  GPU {i}: {device_name}")
                print(f"    显存: {device_cap.total_memory / 1024**3:.1f} GB")
                print(f"    计算能力: {device_cap.major}.{device_cap.minor}")

            # 检查CUDA 12
            if cuda_version and cuda_version.startswith("12"):
                print("✅ CUDA 12 - 完美!")
            else:
                print(f"⚠️ CUDA {cuda_version} - 建议升级到CUDA 12")

            return True
        else:
            print("❌ CUDA 不可用")
            return False
    except ImportError as e:
        print(f"❌ PyTorch 未安装: {e}")
        return False

def check_dependencies():
    """检查SuGaR依赖"""
    print("\n" + "=" * 60)
    print("4. SuGaR 依赖")
    print("=" * 60)

    deps = [
        ("diff-gaussian-rasterization", "diff_gaussian_rasterization"),
        ("simple-knn", "simple_knn"),
        ("Open3D", "open3d"),
        ("PyMCubes", "mcubes"),  # PyMCubes的导入名是mcubes
        ("PyTorch3D", "pytorch3d"),
        ("NumPy", "numpy"),
        ("OpenCV", "cv2"),
        ("Torch", "torch"),
        ("Matplotlib", "matplotlib"),
        ("PIL", "PIL"),
    ]

    all_ok = True
    for name, module in deps:
        try:
            __import__(module)
            print(f"✅ {name}")
        except ImportError:
            print(f"❌ {name} - 未安装")
            all_ok = False

    return all_ok

def check_external_tools():
    """检查外部工具"""
    print("\n" + "=" * 60)
    print("5. 外部工具")
    print("=" * 60)

    tools = [
        ("FFmpeg", "ffmpeg", "-version"),
        ("COLMAP", "colmap", "help"),
        ("Git", "git", "--version"),
    ]

    all_ok = True
    for name, cmd, arg in tools:
        try:
            result = subprocess.run(
                [cmd, arg],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=2
            )
            if result.returncode == 0:
                print(f"✅ {name}")
            else:
                print(f"⚠️ {name} - 可能有问题")
        except (subprocess.TimeoutExpired, FileNotFoundError):
            print(f"❌ {name} - 未找到")
            all_ok = False

    return all_ok

def check_gpu():
    """检查GPU信息"""
    print("\n" + "=" * 60)
    print("6. GPU 信息")
    print("=" * 60)

    try:
        import torch
        if torch.cuda.is_available():
            device = torch.cuda.current_device()
            props = torch.cuda.get_device_properties(device)

            print(f"GPU 名称: {props.name}")
            print(f"总显存: {props.total_memory / 1024**3:.1f} GB")
            print(f"计算能力: {props.major}.{props.minor}")
            print(f"多处理器数: {props.multi_processor_count}")

            # 检查是否为RTX 50系列
            if "50" in props.name:
                print("✅ RTX 50系列 - 最新架构，支持CUDA 12.8!")
            else:
                print(f"⚠️ 非50系列GPU - 可能有兼容性问题")

            return True
        else:
            print("❌ 无可用GPU")
            return False
    except Exception as e:
        print(f"❌ 获取GPU信息失败: {e}")
        return False

def check_suagr_files():
    """检查SuGaR关键文件"""
    print("\n" + "=" * 60)
    print("7. SuGaR 文件")
    print("=" * 60)

    files = [
        ("train_full_pipeline.py", "主训练脚本"),
        ("run_viewer.py", "查看器"),
        ("render_blender_scene.py", "Blender渲染"),
        ("metrics.py", "评估脚本"),
    ]

    all_ok = True
    for file, desc in files:
        if os.path.exists(file):
            print(f"✅ {file} ({desc})")
        else:
            print(f"❌ {file} - 未找到")
            all_ok = False

    return all_ok

def main():
    """主函数"""
    print("\n" + "🚀" * 20)
    print("SuGaR Pipeline 环境检查")
    print("🚀" * 20 + "\n")

    checks = [
        check_python_version(),
        check_conda_env(),
        check_torch(),
        check_dependencies(),
        check_external_tools(),
        check_gpu(),
        check_suagr_files(),
    ]

    print("\n" + "=" * 60)
    print("总结")
    print("=" * 60)

    if all(checks):
        print("✅ 所有检查通过! 环境配置完美!")
        print("\n可以开始使用 SuGaR Pipeline:")
        print("  ./sugar_video_pipeline.sh <视频路径> <场景名称>")
    else:
        print("❌ 部分检查失败，请根据上述提示修复问题")
        print("\n常见解决方案:")
        print("  1. 激活Conda环境: conda activate gs_linux_backup")
        print("  2. 安装依赖: pip install -r requirements.txt")
        print("  3. 编译CUDA扩展: pip install -e gaussian_splatting/submodules/...")

    print("=" * 60)

if __name__ == "__main__":
    main()
