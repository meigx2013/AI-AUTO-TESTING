#!/usr/bin/env python3
"""
路径验证工具 - 验证 asdm-admin 子模块中的文件路径正确性
"""

import os
import sys
import json
import argparse
from pathlib import Path
from typing import List, Dict, Any, Optional


class PathValidator:
    """路径验证器类"""
    
    def __init__(self, base_path: str = "/home/azureuser/source/asdm-product-management"):
        self.base_path = Path(base_path)
        self.asdm_admin_path = self.base_path / "asdm-admin"
        
    def validate_file(self, file_path: str) -> Dict[str, Any]:
        """验证单个文件路径"""
        full_path = self._resolve_path(file_path)
        exists = full_path.exists()
        
        result = {
            "file_path": str(full_path),
            "exists": exists,
            "filename": full_path.name,
            "relative_path": self._get_relative_path(full_path)
        }
        
        if exists:
            result["relative_link"] = self._generate_relative_link(full_path)
            result["markdown_row"] = self._generate_markdown_row(full_path)
        
        return result
    
    def validate_files(self, file_paths: List[str]) -> List[Dict[str, Any]]:
        """批量验证文件路径"""
        results = []
        for file_path in file_paths:
            results.append(self.validate_file(file_path))
        return results
    
    def generate_cli_commands(self, file_path: str) -> Dict[str, str]:
        """生成 CLI 验证命令"""
        full_path = self._resolve_path(file_path)
        filename = full_path.name
        
        # 生成 find 命令
        find_cmd = f'find {self.asdm_admin_path} -name "{filename}" -type f'
        
        # 生成 ls 命令
        ls_cmd = f'ls -la {full_path}'
        
        return {
            "find": find_cmd,
            "ls": ls_cmd
        }
    
    def _resolve_path(self, file_path: str) -> Path:
        """解析文件路径"""
        if file_path.startswith(str(self.base_path)):
            return Path(file_path)
        elif file_path.startswith("asdm-admin/"):
            return self.base_path / file_path
        else:
            # 假设是相对 asdm-admin 的路径
            return self.asdm_admin_path / file_path
    
    def _get_relative_path(self, full_path: Path) -> str:
        """获取相对于 asdm-admin 的路径"""
        try:
            return str(full_path.relative_to(self.asdm_admin_path))
        except ValueError:
            return str(full_path.relative_to(self.base_path))
    
    def _generate_relative_link(self, full_path: Path) -> str:
        """生成相对路径链接（用于 Markdown）"""
        relative_path = self._get_relative_path(full_path)
        # 计算相对路径层级：从 docs/planning/Feat/FT-XXX/进展报告.md 到 asdm-admin
        return f"../../../../asdm-admin/{relative_path}"
    
    def _generate_markdown_row(self, full_path: Path) -> str:
        """生成 Markdown 表格行"""
        filename = full_path.name
        link = self._generate_relative_link(full_path)
        return f"| `{filename}` | [查看代码]({link}) |"


def main():
    """主函数"""
    parser = argparse.ArgumentParser(description="路径验证工具")
    parser.add_argument("--validate", help="验证单个文件路径")
    parser.add_argument("--validate-and-link", help="验证文件路径并生成链接")
    parser.add_argument("--batch", help="从配置文件批量验证")
    parser.add_argument("--file-list", help="从文件列表批量验证")
    parser.add_argument("--generate-find", help="生成 find 命令")
    parser.add_argument("--generate-ls", help="生成 ls 命令")
    parser.add_argument("--base-path", default="/home/azureuser/source/asdm-product-management", 
                       help="基础路径")
    parser.add_argument("--verbose", action="store_true", help="详细输出")
    
    args = parser.parse_args()
    
    validator = PathValidator(args.base_path)
    
    if args.validate:
        result = validator.validate_file(args.validate)
        print(json.dumps(result, indent=2, ensure_ascii=False))
    
    elif args.validate_and_link:
        result = validator.validate_file(args.validate_and_link)
        if result["exists"]:
            print(result["markdown_row"])
        else:
            print(f"文件不存在: {result['file_path']}")
    
    elif args.batch:
        with open(args.batch, 'r', encoding='utf-8') as f:
            config = json.load(f)
        
        files = config.get("files", [])
        results = validator.validate_files(files)
        
        # 按 DoD 分类输出
        for result in results:
            if result["exists"]:
                print(result["markdown_row"])
            else:
                print(f"# 文件不存在: {result['filename']}")
    
    elif args.file_list:
        with open(args.file_list, 'r', encoding='utf-8') as f:
            files = [line.strip() for line in f if line.strip()]
        
        results = validator.validate_files(files)
        for result in results:
            print(json.dumps(result, ensure_ascii=False))
    
    elif args.generate_find:
        commands = validator.generate_cli_commands(args.generate_find)
        print(commands["find"])
    
    elif args.generate_ls:
        commands = validator.generate_cli_commands(args.generate_ls)
        print(commands["ls"])
    
    else:
        # 显示帮助信息
        print("路径验证工具 - 使用方法:")
        print("python main.py --validate <文件路径>")
        print("python main.py --validate-and-link <文件路径>")
        print("python main.py --batch config.json")
        print("python main.py --generate-find <文件名>")
        print("python main.py --generate-ls <文件路径>")


if __name__ == "__main__":
    main()