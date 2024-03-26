;@Ahk2Exe-Let APP_NAME = ptcg-third-server-loader
;@Ahk2Exe-Let APP_VERSION = 3.0.0.0
;@Ahk2Exe-ExeName dist/%U_APP_NAME%_%U_APP_VERSION%.exe
;@Ahk2Exe-SetCopyright Hill-98@GitHub
;@Ahk2Exe-SetDescription %U_APP_NAME%
;@Ahk2Exe-SetLanguage 0x0804
;@Ahk2Exe-SetName %U_APP_NAME%
;@Ahk2Exe-SetOrigFilename %A_ScriptName%
;@Ahk2Exe-SetVersion %U_APP_VERSION%

#SingleInstance Force
#NoTrayIcon
#Include %A_ScriptDir%

CONFIG_DIR := A_AppData . "\ptcg-third-server-loader"
CONFIG_FILE := CONFIG_DIR . "\config.ini"
DISCLAIMER_VERSION := String(2024032601)
PTCGLIVE_EXE := "Pokemon TCG Live.exe"
WINDOW_TITLE := "PTCG Live 小天冠山启动器"

GetServerList() {
    FileEncoding('UTF-8')
    results := []
    http := ComObject("WinHttp.WinHttpRequest.5.1")
    http.Open("GET", "http://ptcg.mivm.cn:8080/servers", false)
    http.SetTimeouts(2000, 3000, 5000, 5000)
    http.Send()
    if (http.Status != 200) {
        throw Error(http.StatusText)
    }
    text := http.ResponseText
    loop parse text, "`n" {
        strs := StrSplit(A_LoopField, "|")
        results.Push(Map("name", strs[1], "endpoint", strs[2], "player_count", strs[3]))
    }
    return results
}

GetPTCGLiveInstallDirectory() {
    SetRegView(64)
    PTCGLiveInstallDirectory := NormalizationPath(RegRead("HKEY_CURRENT_USER\Software\The Pokémon Company International\Pokémon Trading Card Game Live", "Path", EnvGet('USERPROFILE') . "\The Pokémon Company International"))

    if (FileExist(A_Desktop . "\Pokémon TCG Live.lnk")) {
        FileGetShortcut(A_Desktop . "\Pokémon TCG Live.lnk", &target)
        SplitPath(target, , &PTCGLiveInstallDirectory)
    }
    if (!FileExist(PTCGLiveInstallDirectory . "\" . PTCGLIVE_EXE)) {
        PTCGLiveInstallDirectory := PTCGLiveInstallDirectory . "\Pokémon Trading Card Game Live"
    }

    if (!FileExist(PTCGLiveInstallDirectory . "\Pokemon TCG Live.exe")) {
        MsgBox("未找到 Pokémon TCG Live 安装目录，请手动选择安装目录。", WINDOW_TITLE, 0x30)
        result := FileSelect(1, A_Desktop, "选择 Pokémon TCG Live", "Pokemon TCG Live.exe (Pokemon TCG Live.exe; *.lnk)")
        if (result == "") {
            return false
        }
        if (SubStr(result, -4) == ".lnk") {
            FileGetShortcut(result, &target)
            SplitPath(target, , &PTCGLiveInstallDirectory)
        } else {
            SplitPath(result, , &PTCGLiveInstallDirectory)
        }
    }

    return NormalizationPath(PTCGLiveInstallDirectory)
}

NormalizationPath(path) {
    if (SubStr(path, -1) == "\") {
        path := SubStr(path, 1, -1)
    }
    return path
}


RefreshServerList() {
    global ServerList, ServerListBox

    ServerList := GetServerList()

    values := []

    for server in ServerList {
        values.Push(Format("{1} (在线玩家：{2})", server["name"], server["player_count"]))
    }

    ServerListBox.Delete()
    ServerListBox.Add(values)

    index := Number(IniRead(CONFIG_FILE, "main", "ServerIndex", "1"))

    ServerListBox.Choose(index <= ServerList.Length ? index : 1)

    return true
}

StartButton_Click(button, info) {
    global MainWindow, PTCGLiveInstallDirectory, ModDirectory, ServerList, ServerListBox

    MainWindow.Submit(false)

    config := PTCGLiveInstallDirectory . "\config-noc.json"
    index := ServerListBox.Value
    server := ServerList[index]
    json := Format('{"OmukadeEndpoint":"{1}","EnableAllCosmetics":{2},"ForceAllLegalityChecksToSucceed":true,"AskServerForImplementedCards": true}', server["endpoint"], (EnableAllCosmeticsCheckbox.Value ? "true" : "false"))

    if (Number(server["player_count"]) >= 150) {
        MsgBox(server["name"] . " 服务器在线玩家已达到 150 人，请选择其他服务器。", WINDOW_TITLE, 0x30)
        return
    }
    IniWrite(index, CONFIG_FILE, "main", "ServerIndex")

    if (ProcessExist(PTCGLIVE_EXE)) {
        MsgBox("检测到 Pokémon TCG Live 正在运行，请先退出游戏。", WINDOW_TITLE, 0x30)
        return
    }

    if (!FileExist(PTCGLiveInstallDirectory . "\winhttp.dll") || !FileExist(PTCGLiveInstallDirectory . "\BepInEx\core\BepInEx.dll")) {
        FileInstall("dist\BepInEx_5.4.22.0.zip", PTCGLiveInstallDirectory . "\BepInEx.zip", 1)
        command := Format("cmd.exe /c {1}\System32\WindowsPowerShell\v1.0\powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy AllSigned -Command Expand-Archive -LiteralPath BepInEx.zip -DestinationPath . -Force -ErrorAction Stop >powershell.log 2>&1", EnvGet("SystemRoot"))
        code := RunWait(command, PTCGLiveInstallDirectory)
        FileDelete(PTCGLiveInstallDirectory . "\BepInEx.zip")
        if (code != 0) {
            MsgBox("释放 BepInEx 到 Pokémon TCG Live 安装目录失败，请尝试以管理员权限运行或关闭杀毒软件后重试。`n`n" . FileRead(PTCGLiveInstallDirectory . "\powershell.log"), WINDOW_TITLE, 0x10)
            return
        }
        FileDelete(PTCGLiveInstallDirectory . "\powershell.log")
    }

    DirCreate(ModDirectory)
    FileInstall("dist\AssemblyNamePatcher.dll", ModDirectory . "\AssemblyNamePatcher.dll", 1)
    FileInstall("dist\PTCGLiveProfileSwitcher.dll", ModDirectory . "\PTCGLiveProfileSwitcher.dll", 1)
    FileInstall("dist\Rainier.NativeOmukadeConnector.dll", ModDirectory . "\Rainier.NativeOmukadeConnector.dll", 1)

    if (FileExist(config)) {
        FileDelete(config)
    }
    FileAppend(json, config, "UTF-8")

    Run("`"Pokemon TCG Live.exe`" --enable-omukade", PTCGLiveInstallDirectory)

    ExitApp()
}

if (IniRead(CONFIG_FILE, "main", "DisclaimerVersion", "x") != DISCLAIMER_VERSION) {
    DISCLAIMER := Format("{1}\{2}", NormalizationPath(A_Temp), A_ScriptName . A_ScriptHwnd . ".DISCLAIMER.txt")
    FileInstall("DISCLAIMER.txt", DISCLAIMER, 1)

    if (MsgBox(FileRead(DISCLAIMER, "UTF-8") . "`n点击【是】代表同意上述免责声明`n点击【否】代表不同意上述免责声明", WINDOW_TITLE, 0x4 + 0x40) == "Yes") {
        if (!DirExist(CONFIG_DIR)) {
            DirCreate(CONFIG_DIR)
        }
        IniWrite(DISCLAIMER_VERSION, CONFIG_FILE, "main", "DisclaimerVersion")
    } else {
        ExitApp()
    }
}

PTCGLiveInstallDirectory := IniRead(CONFIG_FILE, "ptcg", "InstallDirectory", "x")
ServerList := []

if (!FileExist(PTCGLiveInstallDirectory . "\Pokemon TCG Live.exe")) {
    PTCGLiveInstallDirectory := GetPTCGLiveInstallDirectory()
}

ModDirectory := PTCGLiveInstallDirectory . "\BepInEx\plugins"

if (PTCGLiveInstallDirectory == false) {
    MsgBox("未选择 Pokémon TCG Live 安装目录。", WINDOW_TITLE, 0x30)
    ExitApp()
}

if (!FileExist(PTCGLiveInstallDirectory . "\Pokemon TCG Live.exe")) {
    MsgBox("您选择的不是 Pokémon TCG Live 安装目录。", WINDOW_TITLE, 0x30)
    ExitApp()
}

IniWrite(PTCGLiveInstallDirectory, CONFIG_FILE, "ptcg", "InstallDirectory")

MainWindow := Gui("", WINDOW_TITLE)
MainWindow.SetFont(, "Microsoft YaHei")
MainWindow.SetFont("s12")

StartButton := MainWindow.AddButton("w220 h50 x70 y226 Center", "开始游戏")
StartButton.OnEvent("Click", StartButton_Click)
ServerListBox := MainWindow.AddListBox("r7 w280 x40 y28")

MainWindow.SetFont("s10")
EnableAllCosmeticsCheckbox := MainWindow.AddCheckbox("x110 y194", "强制解锁所有卡组装扮")
MainWindow.AddLink("x294 y300", "<a href=`"https://url.mivm.cn/ptcg-private-server-group`">交流QQ群</a>")
MainWindow.SetFont("cred")
MainWindow.AddText("x0 y4 w360 Center", "请不要在指定规则服务器使用不符合规则的卡组")
MainWindow.AddText("x4 y280", "所有服务器将在每天早上6点进行例行维护重启")
MainWindow.AddText("x4 y300", "每个服务器在线玩家不建议超过150人")

try {
    RefreshServerList()
} catch (Error as e) {
    StartButton.Enabled := false
    MsgBox("获取服务器信息失败！`n`n" . e.Message, WINDOW_TITLE, 0x10)
}

MainWindow.Show("w360 h320 yCenter xCenter")
