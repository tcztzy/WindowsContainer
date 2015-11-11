我就不介绍Windows Container的概念了，本文的默认你对Docker等容器虚拟化技术有一定了解了

首先是官网https://msdn.microsoft.com/virtualization/windowscontainers/containers_welcome

启用Container需要一个宿主机，在官网介绍的三种方法种除了云端的Azure，还有两种方式可以创建Container Host，一个是运行一个PowerShell脚本新建一个Hyper-V的虚拟机作为Host，还有一个是把现有的Windows Server 2016 TP3变成Host。

但是前者的话，宿主机没有桌面，只有shell的GUI，这对熟悉桌面操作的大家比较挑战，个人不是很推荐。第二种方法安装的Windows Server 2016 TP3是可以有图形化的界面的，所以我们就从Windows Server 2016 TP3开始吧。

下载地址：
Window Server 2016 Technical Preview 3
http://care.dlservice.microsoft.com/dl/download/7/3/C/73C250BE-67C4-440B-A69B-D0E8EE77F01C/10514.0.150808-1529.TH2_RELEASE_SERVER_OEMRET_X64FRE_EN-US.ISO
Window Server 2016 TP3 Core - with Windows Server Containers
http://care.dlservice.microsoft.com/dl/download/evalx/WinServer2016TP3_WinServer2016TP3-Container.zip
或者访问下载中心：
http://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-technical-preview

推荐下载第二个with Containers的zip文件，这样的话Container的镜像也有了。

下载完镜像后就是安装，我是用的Windows自带的Hpyer-V Manager安装的，VMware也试过，都是可用的。安装过程没什么好说的，就是记得要选择一下有桌面的那个选项。

登录你的Windows Server 2016，然后打开IE浏览器，首先改一下默认的Internet选项，把自定义安全等级的下载文件启用了。Edge不知道为啥不好用，我也懒得设置，IE/Edge的存在价值就是下载Chrome/Firefox。

以Administrator身份打开powershell，运行如下命令
wget -uri https://aka.ms/setupcontainers -OutFile C:\ContainerSetup.ps1
这个命令的作用是下载一个PowerShell脚本文件Install-ContainerHost.ps1并保存为C:\ContainerSetup.ps1

先别急着运行这个ps1文件，我们不妨打开来看看这个文件都干点啥。

Install-Feature这个函数是用来安装Containers这个功能的，New-ContainerDhcpSwitch，New-ContainerNatSwitch这两个是用来创建VMSwitch给container上网的，New-ContainerNat是用来NAT映射的，Install-ContainerHost是主函数，Get-Nsmm是用来安装第三方软件NSSM的，Test-Admin是用来测试权限的。

我为什么要让大家注意下ps1文件呢，因为这个文件中有一个要命的
wget -Uri $WimPath -OutFile $localWimPath -UseBasicParsing
这个是下载Container镜像的，用wget下载1G多的镜像文件简直要命，我一开始总是挂在这里。

我们找一下$WimPath，发现
$WimPath = "https://aka.ms/ContainerOSImage"
用浏览器或者其他下载工具去把这个链接下了，或者前面下载Windows Server 2016 TP3的时候下载了zip文件的可以吧zip中的.wim文件拿出来了

复制ContainerSetup.ps1中的Install-Feature函数，粘贴到powershell里回车，然后执行

Install-Feature -FeatureName Containers

运行完可能需要重启一次，重启完运行以下命令

Install-ContainerOSImage -WimPath [your wim file path]

运行完就可以