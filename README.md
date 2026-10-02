# App monitor

轻量的 macOS 应用资源监视器，采用原生蓝色毛玻璃界面。

- 按应用汇总 CPU 和内存占用，每秒刷新。
- 支持搜索、排序、暂停刷新和切换到应用。
- 可包含菜单栏应用；强制退出前会确认，Finder 受到保护。
- 数据仅在本机处理，无需联网或管理员权限。

## 下载

从 [最新 Release](https://github.com/Jyikove/app-monitor/releases/latest) 下载 ZIP，解压后打开 **App monitor.app**。

支持 Apple Silicon Mac，要求 macOS 13 或更新版本；macOS 26 起使用原生 Liquid Glass。应用使用本地签名，未经过 Apple 公证。

## 构建

安装 Apple Command Line Tools 后运行：

```sh
git clone https://github.com/Jyikove/app-monitor.git
cd app-monitor
./Sources/build.command
```

生成的应用位于项目根目录。CPU 百分比以整台 Mac 的总算力为基准，内存显示应用及其辅助进程的物理内存占用。
