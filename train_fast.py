#!/usr/bin/env python3
"""
SuGaR 快速训练脚本（不生成mesh）
只进行coarse training，跳过mesh extraction和refinement
可以节省30-50%的训练时间
"""

import os
import sys
import argparse
from sugar_utils.general_utils import str2bool
from sugar_trainers.coarse_density import coarse_training_with_density_regularization
from sugar_trainers.coarse_sdf import coarse_training_with_sdf_regularization

def parse_args():
    parser = argparse.ArgumentParser(
        description='SuGaR快速训练（无mesh生成）- 只进行coarse training'
    )

    # 数据参数
    parser.add_argument('-s', '--scene_path',
                        type=str, required=True,
                        help='场景数据路径（COLMAP格式）')
    parser.add_argument('-o', '--output_dir',
                        type=str, default=None,
                        help='输出目录（默认：output/<scene_name>）')
    parser.add_argument('-c', '--checkpoint_path',
                        type=str, default=None,
                        help='加载vanilla 3DGS checkpoint的路径（可选）')

    # 正则化方法
    parser.add_argument('-r', '--regularization',
                        type=str, default='dn_consistency',
                        choices=['dn_consistency', 'density', 'sdf'],
                        help='正则化方法: dn_consistency(推荐), density, sdf')

    # 训练参数
    parser.add_argument('-i', '--iterations',
                        type=int, default=15000,
                        help='训练迭代次数（默认：15000）')
    parser.add_argument('--eval',
                        type=str2bool, default=True,
                        help='使用eval split')
    parser.add_argument('--white_background',
                        type=str2bool, default=False,
                        help='使用白色背景而非黑色')

    # 损失权重
    parser.add_argument('-e', '--estimation_factor',
                        type=float, default=0.2,
                        help='estimation loss权重')
    parser.add_argument('-n', '--normal_factor',
                        type=float, default=0.2,
                        help='normal loss权重')

    # GPU
    parser.add_argument('--gpu',
                        type=int, default=0,
                        help='GPU设备索引')

    # 快速训练选项
    parser.add_argument('--fast_mode',
                        action='store_true',
                        help='快速模式：减少迭代次数和densification')

    return parser.parse_args()

def main():
    args = parse_args()

    # 设置输出目录
    if args.output_dir is None:
        scene_name = os.path.basename(os.path.normpath(args.scene_path))
        args.output_dir = os.path.join('output', scene_name)

    # 快速模式调整
    if args.fast_mode:
        print("🚀 快速模式已启用！")
        print("  - 减少迭代次数到 7000")
        print("  - 禁用评估split以加速")
        args.iterations = 7000
        args.eval = False

    print("=" * 70)
    print("SuGaR 快速训练（无mesh生成）")
    print("=" * 70)
    print(f"场景路径: {args.scene_path}")
    print(f"输出目录: {args.output_dir}")
    print(f"正则化方法: {args.regularization}")
    print(f"训练迭代: {args.iterations}")
    print(f"快速模式: {'是' if args.fast_mode else '否'}")
    print("=" * 70)
    print()

    # ==================== 关键修复：自动训练 Vanilla 3DGS ====================
    gs_checkpoint_dir = args.checkpoint_path

    # 如果没有提供 checkpoint，先训练 vanilla 3DGS
    if gs_checkpoint_dir is None:
        scene_name = os.path.basename(os.path.normpath(args.scene_path))
        gs_checkpoint_dir = os.path.join("output", "vanilla_gs", scene_name)

        # 检查是否已经存在训练好的 checkpoint
        cameras_json_path = os.path.join(gs_checkpoint_dir, "cameras.json")
        if os.path.exists(cameras_json_path):
            print(f"✅ 找到已有的 Vanilla 3DGS checkpoint: {gs_checkpoint_dir}")
        else:
            print(f"📦 未找到 Vanilla 3DGS checkpoint，开始训练...")
            print(f"   输出目录: {gs_checkpoint_dir}")
            print(f"   迭代次数: {args.iterations}")

            # 创建输出目录
            os.makedirs(gs_checkpoint_dir, exist_ok=True)

            # 构建 vanilla 3DGS 训练命令
            # 使用 shlex.quote 来正确处理路径中的特殊字符
            import shlex
            white_background_flag = '-w' if args.white_background else ''
            train_cmd_parts = [
                f"CUDA_VISIBLE_DEVICES={args.gpu}",
                "python",
                "./gaussian_splatting/train.py",
                "-s", args.scene_path,
                "-m", gs_checkpoint_dir,
            ]
            if white_background_flag:
                train_cmd_parts.append(white_background_flag)
            train_cmd_parts.extend(["--iterations", str(args.iterations)])

            train_cmd = " ".join(shlex.quote(part) if part and not part.startswith("CUDA") else part
                                   for part in train_cmd_parts)

            print(f"\n执行命令:\n{train_cmd}\n")
            exit_code = os.system(train_cmd)

            if exit_code != 0:
                print("\n❌ Vanilla 3DGS 训练失败！")
                print("请检查错误信息并重试。")
                sys.exit(1)

            print(f"\n✅ Vanilla 3DGS 训练完成！")

    # 确保 checkpoint 路径以正确的格式结尾
    if gs_checkpoint_dir[-1] != os.path.sep:
        gs_checkpoint_dir += os.path.sep

    print(f"\n使用 Vanilla 3DGS checkpoint: {gs_checkpoint_dir}")
    print()

    # ==================== SuGaR 训练 ====================
    # 根据正则化方法选择训练函数
    if args.regularization == 'dn_consistency' or args.regularization == 'density':
        print("使用 density 正则化训练...")
        # 创建临时参数对象
        import types
        args_obj = types.SimpleNamespace()

        args_obj.checkpoint_path = gs_checkpoint_dir  # 使用自动训练的 checkpoint
        args_obj.scene_path = args.scene_path
        args_obj.output_dir = args.output_dir
        args_obj.iteration_to_load = args.iterations
        args_obj.num_iterations = args.iterations  # 传递总迭代次数
        args_obj.eval = args.eval
        args_obj.white_background = args.white_background
        args_obj.estimation_factor = args.estimation_factor
        args_obj.normal_factor = args.normal_factor
        args_obj.gpu = args.gpu

        coarse_training_with_density_regularization(args_obj)

    elif args.regularization == 'sdf':
        print("使用 SDF 正则化训练...")
        # 创建临时参数对象
        import types
        args_obj = types.SimpleNamespace()

        args_obj.checkpoint_path = gs_checkpoint_dir  # 使用自动训练的 checkpoint
        args_obj.scene_path = args.scene_path
        args_obj.output_dir = args.output_dir
        args_obj.iteration_to_load = args.iterations
        args_obj.num_iterations = args.iterations  # 传递总迭代次数
        args_obj.eval = args.eval
        args_obj.white_background = args.white_background
        args_obj.gpu = args.gpu

        coarse_training_with_sdf_regularization(args_obj)

    print()
    print("=" * 70)
    print("✅ 训练完成！")
    print("=" * 70)
    print()
    print("输出文件:")
    print(f"  - Checkpoints: {args.output_dir}/")
    print(f"  - Point Cloud: {args.output_dir}/point_cloud/")
    print()
    print("下一步:")
    print("  1. 使用SuGaR查看器:")
    print(f"     python run_viewer.py -p {args.output_dir}/")
    print()
    print("  2. 或使用完整pipeline生成mesh:")
    print(f"     python train_full_pipeline.py -s {args.scene_path} -r {args.regularization} --gs_output_dir {args.output_dir}")
    print()

if __name__ == "__main__":
    main()
