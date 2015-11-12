#Windows Containers

##0.前言

我就不介绍Windows Container的概念了，本文的默认读者对Docker等容器虚拟化技术有一定程度了解。如果有什么不懂得可以去[Containers官网](https://msdn.microsoft.com/virtualization/windowscontainers/containers_welcome)查看。

##1.准备工作

除非特殊说明，本文使用的shell工具都是PowerShell。

启用Container需要一个Host，在官网介绍的三种方法种除了云端的Azure，还有两种方式可以创建Container Host，一个是运行一个PowerShell脚本新建一个Hyper-V的虚拟机作为Host，还有一个是把现有的Windows Server 2016 TP3变成Host。

但是前者的话，宿主机没有桌面，只有shell的GUI，这对熟悉桌面操作的大家比较挑战，个人不是很推荐。第二种方法安装的Windows Server 2016 TP3是可以有图形化的界面的，所以我们就从Windows Server 2016 TP3开始吧。

下载地址：

* [Window Server 2016 Technical Preview 3]
(http://care.dlservice.microsoft.com/dl/download/7/3/C/73C250BE-67C4-440B-A69B-D0E8EE77F01C/10514.0.150808-1529.TH2_RELEASE_SERVER_OEMRET_X64FRE_EN-US.ISO)

* [Window Server 2016 TP3 Core - with Windows Server Containers]
(http://care.dlservice.microsoft.com/dl/download/evalx/WinServer2016TP3_WinServer2016TP3-Container.zip)

* 或者访问[下载中心]
(http://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-technical-preview)

推荐下载第二个with Containers的zip文件，这样的话Container的镜像也有了。

下载完镜像后就是安装，我是用的Windows自带的Hpyer-V Manager安装的，VMware也试过，都是可用的。安装过程没什么好说的，就是记得要选择一下有桌面的那个选项。

登录你的Windows Server 2016，然后打开IE浏览器，首先改一下默认的Internet选项，把下载文件启用了。Edge不知道为啥不好用，我也懒得设置，毕竟IE/Edge的存在价值就是下载Chrome/Firefox。

运行如下命令

`wget -uri https://aka.ms/setupcontainers -OutFile C:\ContainerSetup.ps1`

这个命令的作用是下载一个PowerShell脚本文件。不过先别急着运行这个ps1文件，因为这个文件中有一个要命的wget下载Container镜像的命令，用wget下载3G的镜像，不用我说你们也能猜到会发生什么吧。

我们找一下镜像地址发现`$WimPath = "https://aka.ms/ContainerOSImage"`。用浏览器或者其他下载工具去把这个链接的wim镜像下了。

或者前面下载Windows Server 2016 TP3的时候下载了zip文件的可以吧zip中的
CBaseOs_th2_release_10514.0.150808-1529_amd64fre_ServerDatacenterCore_en-us.wim
文件拿出来了

输入命令

`Install-WindowsFeature Container`

运行完可能需要重启一次，重启完运行以下命令

`Install-ContainerOSImage -WimPath [your wim file path]`

运行完就可以跑一下一开始下载的那个C:\ContainerSetup.ps1了，运行完不报错就成功完成Host的制备工作了。

##2.系统配置

因为我希望使用container的RDP，但是众所周知，Windows每个版本的RDP协议版本都不一样，Ubuntu预装的Remmina就可以很好支持RPD10.0。

而开源的Guacamole软件不能简单易用的支持Windows10 or Windows Server 2016，所以我们需要设置下本地的RDP

运行如下命令

`Get-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' | Set-ItemProperty -Name SecurityLayer -Value 1`

