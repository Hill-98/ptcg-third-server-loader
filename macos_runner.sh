#!/bin/bash

set -euf -o pipefail

APPLICATION_DIR="/Applications/Pokemon TCG Live BepInEx"
DOWNLOAD_FILENAME=macos_1.12.0_202403271.files.zip
DISCLAIMER_VERSION=2024032601
POKEMON_TCG_LIVE_DIR="/Applications/Pokemon TCG Live.app"

os_type=$(uname -s)

# Start
case $os_type in
    Darwin*)
        ;;
    *)
        echo "This script only supports macOS operating system" >&2
        exit 1
        ;;
esac

if [[ $(cat "$APPLICATION_DIR/DISCLAIMER_VERSION" || echo 0) != 2024032601 ]]; then
    cat <<EOF
使用条款

本程序是钟路帆 (Hill-98) 开发的 Pokémon TCG Live 第三方服务器加载器，旨在为 Pokémon TCG Live 提供连接到第三方服务器匹配对战的能力。

本程序完全免费，如果您是在其他渠道付费获得的本程序，请联系出售方进行退款。

注意：使用第三方服务器可能会导致游戏出现意外行为或崩溃。

使用本程序前，请仔细阅读以下条款：

* 第三方服务器不属于游戏官方，也不受游戏官方支持。
* 使用第三方服务器可能会导致游戏出现意外行为或崩溃。
* 开发者不对因使用第三方服务器而造成的任何损失或损害负责。
* 第三方服务器可以查看您的某些游戏数据，可能包括您的互联网地址、游戏名称、游戏对局中使用的卡牌等信息，但不包含您的账号名称和账号密码等个人敏感信息。
* 不得将本程序用作任何商业用途。
* 不得将本程序出售给他人。
* 不得对本程序进行修改、逆向、反向编译等操作。

如果您同意以上使用条款，请继续使用本程序。如果您不同意，请不要使用本程序。
EOF
    echo
    echo -n "输入【Y】代表同意上述免责声明，输入【N】代表不同意上述免责声明: "
    read -r disclaimer

    if [[ $disclaimer != 'Y' ]]; then
        exit 1
    fi
fi

if [[ ! -d "$POKEMON_TCG_LIVE_DIR" ]]; then
    echo "请先安装 Pokémon TCG Live 游戏" >&2
    exit 1
fi

echo -e "#!/bin/bash\nbash <(curl https://cdn.mivm.cn/x/ptcg-live/macos_runner.sh)" > ~/Desktop/小天冠山服务器启动器
chmod +x ~/Desktop/小天冠山服务器启动器

[[ ! -d "$APPLICATION_DIR" ]] && mkdir "$APPLICATION_DIR"

rsync --archive --recursive --perms "$POKEMON_TCG_LIVE_DIR" "$APPLICATION_DIR"

echo "$DISCLAIMER_VERSION" > "$APPLICATION_DIR/DISCLAIMER_VERSION"

cd "$APPLICATION_DIR"

if [[ ! -f $DOWNLOAD_FILENAME ]]; then
    curl --connect-timeout 3 --fail --location --output $DOWNLOAD_FILENAME https://cdn.mivm.cn/x/ptcg-live/$DOWNLOAD_FILENAME
fi
rm -f -r BepInEx
unzip -o -q $DOWNLOAD_FILENAME
# End

lines=()
names=()
player_counts=()
servers=()

while IFS='' read -r line; do lines+=("$line"); done < <(curl --connect-timeout 3 --fail --location http://ptcg.mivm.cn:8080/servers)

clear

echo "---------- 小天冠山服务器启动器 (MacOS 版本) ----------"
echo
echo "* 请不要在指定规则服务器使用不符合规则的卡组"
echo "* 所有服务器将在每天早上6点进行例行维护重启"
echo "* 每个服务器在线玩家不建议超过150人"
echo

for ((i = 0; i < ${#lines[@]}; i++));
do
    line=${lines[$i]}
    names[$i]=$(cut -d '|' -f 1 <<< "$line")
    servers[$i]=$(cut -d '|' -f 2 <<< "$line")
    player_counts[$i]=$(cut -d '|' -f 3 <<< "$line")
    echo "$(($i + 1)). ${names[$i]} (在线玩家: ${player_counts[$i]})"
done

echo

echo -n "请输入序号选择服务器: "
read -r num

if [[ $num -le ${#lines[@]} && $num -gt 0 ]]; then
    server=${servers[$(($num - 1))]}
    echo '{"OmukadeEndpoint":"%server%","ForceAllLegalityChecksToSucceed":true,"AskServerForImplementedCards": true}' > "$APPLICATION_DIR/config-noc.json"
    sed -i -e "s|%server%|$server|"  "$APPLICATION_DIR/config-noc.json"
    exec "/Applications/Pokemon TCG Live BepInEx/Pokemon TCG Live.app/Contents/MacOS/Pokemon TCG Live" --enable-omukade
else
    echo "亲输入正确范围内的数字" >&2
    exit 1
fi
