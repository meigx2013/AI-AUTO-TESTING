#!/usr/bin/env python3
"""
路径验证工具测试用例
"""

import unittest
import tempfile
import os
from pathlib import Path
from unittest.mock import patch, MagicMock

# 添加父目录到路径以便导入
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from main import PathValidator


class TestPathValidator(unittest.TestCase):
    """路径验证器测试类"""
    
    def setUp(self):
        """测试设置"""
        self.temp_dir = tempfile.mkdtemp()
        self.validator = PathValidator(self.temp_dir)
        
        # 创建测试文件结构
        self.asdm_admin_dir = Path(self.temp_dir) / "asdm-admin"
        self.asdm_admin_dir.mkdir()
        
        # 创建测试文件
        test_file = self.asdm_admin_dir / "test_file.java"
        test_file.write_text("// test file")
        
    def tearDown(self):
        """测试清理"""
        import shutil
        shutil.rmtree(self.temp_dir)
    
    def test_validate_existing_file(self):
        """测试验证存在的文件"""
        file_path = str(self.asdm_admin_dir / "test_file.java")
        result = self.validator.validate_file(file_path)
        
        self.assertTrue(result["exists"])
        self.assertEqual(result["filename"], "test_file.java")
        self.assertIn("relative_link", result)
        self.assertIn("markdown_row", result)
    
    def test_validate_nonexistent_file(self):
        """测试验证不存在的文件"""
        file_path = str(self.asdm_admin_dir / "nonexistent_file.java")
        result = self.validator.validate_file(file_path)
        
        self.assertFalse(result["exists"])
        self.assertEqual(result["filename"], "nonexistent_file.java")
        self.assertNotIn("relative_link", result)
        self.assertNotIn("markdown_row", result)
    
    def test_generate_cli_commands(self):
        """测试生成 CLI 命令"""
        file_path = str(self.asdm_admin_dir / "test_file.java")
        commands = self.validator.generate_cli_commands(file_path)
        
        self.assertIn("find", commands)
        self.assertIn("ls", commands)
        self.assertIn("test_file.java", commands["find"])
        self.assertIn("test_file.java", commands["ls"])
    
    def test_resolve_absolute_path(self):
        """测试解析绝对路径"""
        absolute_path = str(self.asdm_admin_dir / "test_file.java")
        resolved = self.validator._resolve_path(absolute_path)
        
        self.assertEqual(resolved, Path(absolute_path))
    
    def test_resolve_relative_path(self):
        """测试解析相对路径"""
        relative_path = "asdm-admin/test_file.java"
        resolved = self.validator._resolve_path(relative_path)
        
        expected = self.asdm_admin_dir / "test_file.java"
        self.assertEqual(resolved, expected)
    
    def test_get_relative_path(self):
        """测试获取相对路径"""
        full_path = self.asdm_admin_dir / "test_file.java"
        relative = self.validator._get_relative_path(full_path)
        
        self.assertEqual(relative, "test_file.java")
    
    def test_generate_relative_link(self):
        """测试生成相对链接"""
        full_path = self.asdm_admin_dir / "test_file.java"
        link = self.validator._generate_relative_link(full_path)
        
        self.assertEqual(link, "../../../../asdm-admin/test_file.java")
    
    def test_generate_markdown_row(self):
        """测试生成 Markdown 行"""
        full_path = self.asdm_admin_dir / "test_file.java"
        row = self.validator._generate_markdown_row(full_path)
        
        expected = "| `test_file.java` | [查看代码](../../../../asdm-admin/test_file.java) |"
        self.assertEqual(row, expected)


if __name__ == "__main__":
    unittest.main()