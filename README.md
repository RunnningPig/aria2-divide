# aria2-divide

这是一个 Aria2 BT 下载的脚本，针对于**小硬盘** VPS。

## 解决的问题

对于经常在 VPS 上使用 Aria2 做 BT 离线下载的同学，通常会将下载的文件通过 [Rclone](https://rclone.org/) 上传到 OneDrive、Google Drive等云盘上以节省 VPS 硬盘容量。但是可能会遇到这样的问题，我们下载的 **BT 文件很大**，但是里面的**单个文件却小于 VPS 可用的硬盘容量**。比如一部电视剧，动辄就是几十集的节奏。

对于这个问题，我们通常的解决方法是手动选择部分文件，等到下载并上传完这部分文件，我们再接着手动选择剩余的部分文件，直到文件全部下载完成。但是这样手动处理对于我们来讲是比较耗时耗力的。还有一种做法就是使用脚本来自动帮助我们处理这些固定的流程，也就是使用我们这个脚本。

## 脚本原理

![脚本流程](https://github.com/RunnningPig/aria2-divide/raw/master/%E6%B5%81%E7%A8%8B.png)

脚本利用了 Aria2 的 `on-download-start` 和 `on-download-complete` 这两个事件处理参数。当我们添加下载任务时，脚本会尽量多地选择可下载的文件。每下载完成一次，脚本就会自动调用一次用户自定义的 `user_action` 可执行文件，并依次传入 GID、文件数量和下载路径参数。我们可以将要处理的动作（例如将下载的文件上传到云盘上）写到这个自定义的执行文件中。在执行完 `user_action` 之后，脚本会接着下载剩余文件，重复上述动作，直到文件全部下载完成。

> 注意：执行完 `user_action` 之后，脚本都会将前面下载的文件删除。

## 安装

脚本依赖于 `jq` JSON 工具，CentOS 执行下面命令安装，其它系统请自行解决

```bash
yum update
yum -y install jq
```

下载脚本

```bash
cd /path/to/    # 选择一个目录
git clone https://github.com/RunnningPig/aria2-divide.git && cd aria2-divide
```

## 配置

首先，我们来检测下 Aria2 系统配置，默认会检查 `${HOME}/.aria2/aria2.conf` 或者 `${XDG_CONFIG_HOME}/aria2/aria2.conf`

```bash
bash test_configuration.sh
```

输出示例：

```
Aria2 相关信息：

	配置文件: /root/.aria2/aria2.conf
	下载路径: /root/Downloads
	RPC 地址: http://localhost:6800/jsonrpc

	RPC 密钥: xxxxxxxxxxxxxxxx


[信息]：测试配置成功！
```

若输出如上提示，表示读取配置成功，且脚本能够成功连接到 Aria2 的 RPC 上。

接着在 `aria2.conf`文件中添加下面两个选项，进行事件处理的绑定

```properties
on-download-start=/path/to/aria2-divide/aria2_download_start.sh
on-download-complete=/path/to/aria2-divide/aria2_download_complete.sh
```

最后重启 Aria2。

## 使用

项目给出了一个简单的 `user_action` 可执行文件，我们可以试着下载一个小文件（图片等），然后看下在项目目录下是否出现了 `user_action.log` 日志文件，以此判断是否成功调用了 `user_action`。

如果没有出现问题，再对 `user_action` 进行修改，脚本会将任务 **GID**、**下载的文件数量**和**下载路径**传给 `user_action`。

# FAQ

1. **RPC 使用了 SSL 加密。**
   
   在 `aria2.conf` 配置中，如果开启了 `rpc-secure`，那么你需要将本项目中的 `core/aria2.sh` 文件里的 `RPC_HOST` 变量改成的 **RPC 域名**。如果使用的是 Let's Encrypt 证书，那么无须修改 `RPC_HOST`，脚本会通过正则提取域名。














